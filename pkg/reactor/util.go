package reactor

import (
	"fmt"
	"math"
)

// Percent returns the percent of the maximum of a given value.
func Percent(value uint8) int {
	return int((float64(value) / float64(math.MaxUint8)) * 100)
}

// FormatOutput formats the output.
func FormatOutput(output float64) string {
	if output > 1000*1000 {
		return fmt.Sprintf("%.2fgw/hr", output/(1000*1000))
	}
	if output > 1000 {
		return fmt.Sprintf("%.2fmw/hr", output/1000)
	}
	return fmt.Sprintf("%.2fkw/hr", output)
}

// MaybeCreateAlarm creates an alarm if a value is strictly greater than the threshold.
func MaybeCreateAlarm(collector chan Alarm, severity, component, message string, value *float64, threshold float64) bool {
	if *value > threshold {
		collector <- Alarm{
			Severity:  severity,
			Component: component,
			Message:   message,
			DoneProvider: func() bool {
				return *value <= threshold
			},
		}
		return true
	}
	return false
}
