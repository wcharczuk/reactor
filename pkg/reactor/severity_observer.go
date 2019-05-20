package reactor

import "time"

var (
	_ Simulatable = (*SeverityObserver)(nil)
)

// NewSeverityObserver returns a new Observer.
func NewSeverityObserver(valueProvider func() Severity) *SeverityObserver {
	return &SeverityObserver{
		valueProvider: valueProvider,
	}
}

// SeverityObserver is a supervisor for a string value provider.
type SeverityObserver struct {
	previous      Severity
	new           bool
	valueProvider func() Severity
}

// Value returns the value from the value provider.
func (so *SeverityObserver) Value() Severity {
	return so.valueProvider()
}

// New returns if the Observer is new or not.
func (so *SeverityObserver) New() bool {
	return so.new
}

// Seen marks an Observer as seen.
func (so *SeverityObserver) Seen() {
	so.new = false
}

// Simulate applies a simulation tick.
func (so *SeverityObserver) Simulate(quantum time.Duration) error {
	newValue := so.valueProvider()
	if newValue != so.previous {
		so.new = true
	}
	so.previous = newValue
	return nil
}
