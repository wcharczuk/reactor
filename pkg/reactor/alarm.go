package reactor

import "fmt"

// AlarmLevels
const (
	AlarmWarning  = "WARN"
	AlarmCritical = "CRIT"
	AlarmFatal    = "FATAL"
)

// Alarm is a condition that requires attention.
type Alarm struct {
	Severity     string
	Component    string
	Message      string
	DoneProvider func() bool
}

// Done indicates the alarm is no longer relevant.
func (a Alarm) Done() bool {
	if a.DoneProvider != nil {
		return a.DoneProvider()
	}
	return false
}

// String implements fmt.Stringer.
func (a Alarm) String() string {
	return fmt.Sprintf("%s %s: %s", a.Severity, a.Component, a.Message)
}
