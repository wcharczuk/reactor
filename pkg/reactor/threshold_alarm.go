package reactor

import "fmt"

var (
	_ Alarm = (*ThresholdAlarm)(nil)
)

// NewThresholdAlarm returns a new threshold alarm.
func NewThresholdAlarm(name string, valueProvider func() float64, severityProvider func(float64) Severity) *ThresholdAlarm {
	ta := &ThresholdAlarm{
		Name:             name,
		ValueProvider:    valueProvider,
		SeverityProvider: severityProvider,
	}
	ta.SeverityObserver = NewSeverityObserver(ta.Severity)
	return ta
}

// ThresholdAlarm is an alarm provider.
type ThresholdAlarm struct {
	*SeverityObserver

	Name             string
	MessageFormat    string
	ValueProvider    func() float64
	SeverityProvider func(float64) Severity
}

// Severity returns the alarm severity.
func (ta *ThresholdAlarm) Severity() Severity {
	return ta.SeverityProvider(ta.ValueProvider())
}

// String implements fmt.Stringer.
func (ta *ThresholdAlarm) String() string {
	return fmt.Sprintf("%s alarm is %s", ta.Name, ta.Severity())
}
