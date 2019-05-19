package reactor

import "time"

var (
	_ Simulatable = (*Observable)(nil)
)

// NewObservable returns a new observable.
func NewObservable(valueProvider func() Severity) *Observable {
	return &Observable{
		ValueProvider: valueProvider,
	}
}

// Observable is a supervisor for a string value provider.
type Observable struct {
	previous Severity
	new      bool

	ValueProvider func() Severity
}

// New returns if the observable is new or not.
func (o *Observable) New() bool {
	return o.new
}

// Seen marks an observable as seen.
func (o *Observable) Seen() {
	o.new = false
}

// Simulate applies a simulation tick.
func (o *Observable) Simulate(quantum time.Duration) error {
	newValue := o.ValueProvider()
	if newValue != o.previous {
		o.new = true
	}
	o.previous = newValue
	return nil
}
