package reactor

var (
	_ Alarm = (*ThresholdAlarm)(nil)
)

// NewThresholdAlarm returns a new threshold alarm.
func NewThresholdAlarm(value *float64, severity func(float64) string) *ThresholdAlarm {
	return &ThresholdAlarm{
		Value:            value,
		SeverityProvider: serverity,
	}
}

// ThresholdAlarm is an alarm provider.
type ThresholdAlarm struct {
	Value            *float64
	SeverityProvider func(float64) string
}

// Severity returns the alarm severity.
func (ta *ThresholdAlarm) Severity() string {
	return ta.SeverityProvider(*ta.Value)
}
