package reactor

import "fmt"

var (
	_ Alarm = (*ThresholdAlarm)(nil)
)

// NewThresholdAlarm returns a new threshold alarm.
func NewThresholdAlarm(component, messageFormat string, value *float64, fatalThreshold, criticalThreshold, warningThreshold float64) ThresholdAlarm {
	return ThresholdAlarm{
		Component:         component,
		MessageFormat:     messageFormat,
		Value:             value,
		FatalThreshold:    fatalThreshold,
		CriticalThreshold: criticalThreshold,
		WarningThreshold:  warningThreshold,
	}
}

// ThresholdAlarm is a condition that requires attention.
type ThresholdAlarm struct {
	Component     string
	MessageFormat string
	Value         *float64

	FatalThreshold    float64
	CriticalThreshold float64
	WarningThreshold  float64
}

// Threshold returns the threshold the alarm is above.
func (ta ThresholdAlarm) Threshold() float64 {
	if *ta.Value > ta.FatalThreshold {
		return ta.FatalThreshold
	}
	if *ta.Value > ta.CriticalThreshold {
		return ta.CriticalThreshold
	}
	if *ta.Value > ta.WarningThreshold {
		return ta.WarningThreshold
	}
	return 0
}

// Severity returns the alarm severity.
func (ta ThresholdAlarm) Severity() string {
	if *ta.Value > ta.FatalThreshold {
		return SeverityFatal
	}
	if *ta.Value > ta.CriticalThreshold {
		return SeverityCritical
	}
	if *ta.Value > ta.WarningThreshold {
		return SeverityWarning
	}
	return ""
}

// Active indicates the alarm is active.
func (ta ThresholdAlarm) Active() bool {
	if *ta.Value > ta.FatalThreshold {
		return true
	}
	if *ta.Value > ta.CriticalThreshold {
		return true
	}
	if *ta.Value > ta.WarningThreshold {
		return true
	}
	return false
}

// Message returns the message.
func (ta ThresholdAlarm) Message() string {
	if ta.Active() {
		return fmt.Sprintf(ta.MessageFormat, ta.Threshold())
	}
	return ""
}

// String implements fmt.Stringer.
func (ta ThresholdAlarm) String() string {
	if ta.Active() {
		return fmt.Sprintf("%s %s: %s (active)", ta.Severity(), ta.Component, ta.Message())
	}
	return fmt.Sprintf("%s %s: %s (inactive)", ta.Severity(), ta.Component, ta.Message())
}
