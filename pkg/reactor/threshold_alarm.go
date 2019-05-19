package reactor

import "fmt"

var (
	_ Alarm = (*ThresholdAlarm)(nil)
)

// NewThresholdAlarm returns a new threshold alarm.
func NewThresholdAlarm(name string, value *float64, severityProvider func(float64) Severity) *ThresholdAlarm {
	ta := &ThresholdAlarm{
		Name:             name,
		Value:            value,
		SeverityProvider: severityProvider,
	}
	ta.Observable = NewObservable(ta.Severity)
	return ta
}

// ThresholdAlarm is an alarm provider.
type ThresholdAlarm struct {
	*Observable
	Name             string
	MessageFormat    string
	Value            *float64
	SeverityProvider func(float64) Severity
}

// Severity returns the alarm severity.
func (ta *ThresholdAlarm) Severity() Severity {
	return ta.SeverityProvider(*ta.Value)
}

// String implements fmt.Stringer.
func (ta *ThresholdAlarm) String() string {
	return fmt.Sprintf("%s alarm is %s", ta.Name, ta.Severity())
}
