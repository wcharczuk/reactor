package ex

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
)

var (
	_ error          = (*Ex)(nil)
	_ fmt.Formatter  = (*Ex)(nil)
	_ json.Marshaler = (*Ex)(nil)
)

// New returns a new exception with a call stack.
// Pragma: this violates the rule that you should take interfaces and return
// concrete types intentionally; it is important for the semantics of typed pointers and nil
// for this to return an interface because (*Ex)(nil) != nil, but (error)(nil) == nil.
func New(class interface{}, options ...Option) Exception {
	return NewWithStackDepth(class, defaultNewStartDepth, options...)
}

// Exception is a meta interface for exceptions.
type Exception interface {
	error
	WithMessage(...interface{}) Exception
	WithMessagef(string, ...interface{}) Exception
	WithInner(error) Exception
}

// NewWithStackDepth creates a new exception with a given start point of the stack.
func NewWithStackDepth(class interface{}, startDepth int, options ...Option) Exception {
	if class == nil {
		return nil
	}

	var ex *Ex
	if typed, isTyped := class.(*Ex); isTyped {
		ex = typed
	} else if err, ok := class.(error); ok {
		ex = &Ex{
			Class: err,
			Stack: callers(startDepth),
		}
	} else if str, ok := class.(string); ok {
		ex = &Ex{
			Class: Class(str),
			Stack: callers(startDepth),
		}
	} else {
		ex = &Ex{
			Class: Class(fmt.Sprint(class)),
			Stack: callers(startDepth),
		}
	}

	for _, option := range options {
		option(ex)
	}
	return ex
}

// Option is an exception option.
type Option func(*Ex)

// OptMessage sets the exception message from a given list of arguments with fmt.Sprint(args...).
func OptMessage(args ...interface{}) Option {
	return func(ex *Ex) {
		ex.Message = fmt.Sprint(args...)
	}
}

// OptMessagef sets the exception message from a given list of arguments with fmt.Sprintf(format, args...).
func OptMessagef(format string, args ...interface{}) Option {
	return func(ex *Ex) {
		ex.Message = fmt.Sprintf(format, args...)
	}
}

// OptStack sets the exception stack.
func OptStack(stack StackTrace) Option {
	return func(ex *Ex) {
		ex.Stack = stack
	}
}

// OptInner sets an inner or wrapped ex.
func OptInner(inner error) Option {
	return func(ex *Ex) {
		ex.Inner = NewWithStackDepth(inner, defaultNewStartDepth)
	}
}

// Ex is an error with a stack trace.
// It also can have an optional cause, it implements `Exception`
type Ex struct {
	// Class disambiguates between errors, it can be used to identify the type of the error.
	Class error
	// Message adds further detail to the error, and shouldn't be used for disambiguation.
	Message string
	// Inner holds the original error in cases where we're wrapping an error with a stack trace.
	Inner error
	// Stack is the call stack frames used to create the stack output.
	Stack StackTrace
}

// WithMessage sets the exception message.
// Deprecation notice: This method is included as a migraition path from v2, and will be removed after v3.
func (e *Ex) WithMessage(args ...interface{}) Exception {
	e.Message = fmt.Sprint(args...)
	return e
}

// WithMessagef sets the exception message based on a format and arguments.
// Deprecation notice: This method is included as a migraition path from v2, and will be removed after v3.
func (e *Ex) WithMessagef(format string, args ...interface{}) Exception {
	e.Message = fmt.Sprintf(format, args...)
	return e
}

// WithInner sets the inner ex.
// Deprecation notice: This method is included as a migraition path from v2, and will be removed after v3.
func (e *Ex) WithInner(err error) Exception {
	e.Inner = NewWithStackDepth(err, defaultNewStartDepth)
	return e
}

// Format allows for conditional expansion in printf statements
// based on the token and flags used.
// 	%+v : class + message + stack
// 	%v, %c : class
// 	%m : message
// 	%t : stack
func (e *Ex) Format(s fmt.State, verb rune) {
	switch verb {
	case 'v':
		if s.Flag('+') {
			if e.Class != nil && len(e.Class.Error()) > 0 {
				fmt.Fprintf(s, "%s", e.Class)
				if len(e.Message) > 0 {
					fmt.Fprintf(s, "\n%s", e.Message)
				}
			} else if len(e.Message) > 0 {
				io.WriteString(s, e.Message)
			}
			e.Stack.Format(s, verb)
		} else if s.Flag('-') {
			e.Stack.Format(s, verb)
		} else {
			io.WriteString(s, e.Class.Error())
			if len(e.Message) > 0 {
				fmt.Fprintf(s, "\n%s", e.Message)
			}
		}
		if e.Inner != nil {
			if typed, ok := e.Inner.(fmt.Formatter); ok {
				fmt.Fprint(s, "\n")
				typed.Format(s, verb)
			} else {
				fmt.Fprintf(s, "\n%v", e.Inner)
			}
		}
		return
	case 'c':
		io.WriteString(s, e.Class.Error())
	case 'i':
		if e.Inner != nil {
			io.WriteString(s, e.Inner.Error())
		}
	case 'm':
		io.WriteString(s, e.Message)
	case 'q':
		fmt.Fprintf(s, "%q", e.Message)
	}
}

// Error implements the `error` interface.
// It returns the exception class, without any of the other supporting context like the stack trace.
// To fetch the stack trace, use .String().
func (e *Ex) Error() string {
	return e.Class.Error()
}

// Decompose breaks the exception down to be marshalled into an intermediate format.
func (e *Ex) Decompose() map[string]interface{} {
	values := map[string]interface{}{}
	values["Class"] = e.Class.Error()
	values["Message"] = e.Message
	if e.Stack != nil {
		values["Stack"] = e.Stack.Strings()
	}
	if e.Inner != nil {
		if typed, isTyped := e.Inner.(*Ex); isTyped {
			values["Inner"] = typed.Decompose()
		} else {
			values["Inner"] = e.Inner.Error()
		}
	}
	return values
}

// MarshalJSON is a custom json marshaler.
func (e *Ex) MarshalJSON() ([]byte, error) {
	return json.Marshal(e.Decompose())
}

// String returns a fully formed string representation of the ex.
// It's equivalent to calling sprintf("%+v", ex).
func (e *Ex) String() string {
	s := new(bytes.Buffer)
	if e.Class != nil && len(e.Class.Error()) > 0 {
		fmt.Fprintf(s, "%s", e.Class)
	}
	if len(e.Message) > 0 {
		io.WriteString(s, " "+e.Message)
	}
	if e.Stack != nil {
		io.WriteString(s, " "+e.Stack.String())
	}
	return s.String()
}
