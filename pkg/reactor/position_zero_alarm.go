package reactor

import "fmt"

// NewPositionZeroAlarm returns a new position zero alarm.
func NewPositionZeroAlarm(component, messageFormat string, position *Position) PositionZeroAlarm {
	return PositionZeroAlarm{
		Component:     component,
		MessageFormat: messageFormat,
		Position:      position,
	}
}

// PositionZeroAlarm is an alarm.
type PositionZeroAlarm struct {
	Component     string
	MessageFormat string
	Position      *Position
}

// Severity returns the alarm severity.
func (pza PositionZeroAlarm) Severity() string {
	if pza.Active() {
		return AlarmWarning
	}
	return ""
}

// Active returns if the alarm is active.
func (pza PositionZeroAlarm) Active() bool {
	return pza.Position.IsZero()
}

// String implements fmt.Stringer.
func (pza PositionZeroAlarm) String() string {
	if pza.Active() {
		return fmt.Sprintf(pza.MessageFormat, pza.Component)
	}
	return ""
}
