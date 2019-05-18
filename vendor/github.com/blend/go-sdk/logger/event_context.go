package logger

// EventContext is a wrapping context for events.
// It is used when a sub-context triggers or writes an event.
type EventContext struct {
	Event
	ContextPath []string
}
