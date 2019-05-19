package reactor

import (
	"fmt"
	"time"
)

var (
	_ Alarm = (*ThresholdAlarm)(nil)
)

// NewThresholdAlarm returns a new threshold alarm.
func NewThresholdAlarm(component, messageFormat string, value *float64, fatalThreshold, criticalThreshold, warningThreshold float64) *ThresholdAlarm {
	return &ThresholdAlarm{
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
	new bool

	Component     string
	MessageFormat string

	// Value is a reference to the value to check.
	Value *float64

	FatalThreshold    float64
	CriticalThreshold float64
	WarningThreshold  float64
}

// New returns if the alarm has recently fired.
func (ta *ThresholdAlarm) New() bool {
	return ta.new
}

// Seen marks an alarm as not new.
func (ta *ThresholdAlarm) Seen() {
	ta.new = false
}

// Simulate simulates the alarm triggering.
func (ta *ThresholdAlarm) Simulate(quantum time.Duration) error {
	if ta.Threshold() > 0 {
		ta.new = true
	}
	return nil
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

// Active returns if the alarm is active.
func (ta ThresholdAlarm) Active() bool {
	return ta.Threshold() > 0
}

// Message returns the message.
func (ta ThresholdAlarm) Message() string {
	return fmt.Sprintf(ta.MessageFormat, ta.Threshold())
}

// String implements fmt.Stringer.
func (ta ThresholdAlarm) String() string {
	return fmt.Sprintf("%s %s: %s", ta.Severity(), ta.Component, ta.Message())
}
