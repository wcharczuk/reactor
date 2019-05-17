package reactor

import (
	"fmt"
	"time"
)

// NewControlRod returns a new control rod.
func NewControlRod(index int) *ControlRod {
	return &ControlRod{
		Index:       index,
		Position:    PositionMax,
		Temperature: BaseTemperature,
	}
}

// ControlRod controls the rate of the reaction.
// Each control rod simulates both the control and the fuel.
// If a control rod is fully retracted, i.e. its position 0,
// then the reaction is fully active.
type ControlRod struct {
	Index       int
	Position    Position
	Temperature float64
}

// CollectAlarms implements alarm provider.
func (cr *ControlRod) CollectAlarms(collector chan Alarm) {
	if MaybeCreateAlarm(collector, AlarmFatal, fmt.Sprintf("Control Rod %d Temp.", cr.Index), fmt.Sprintf("Above %.2fc", ControlRodTempFatal), &cr.Temperature, ControlRodTempFatal) {
		return
	}
	if MaybeCreateAlarm(collector, AlarmCritical, fmt.Sprintf("Control Rod %d Temp.", cr.Index), fmt.Sprintf("Above %.2fc", ControlRodTempWarning), &cr.Temperature, ControlRodTempCritical) {
		return
	}
	MaybeCreateAlarm(collector, AlarmWarning, fmt.Sprintf("Control Rod %d Temp.", cr.Index), fmt.Sprintf("Above %.2fc", ControlRodTempWarning), &cr.Temperature, ControlRodTempWarning)
}

// Simulate applies a simulation tick.
func (cr *ControlRod) Simulate(quantum time.Duration) error {
	rate := float64(PositionMax-cr.Position) * FissionRateMinute * (float64(quantum) / float64(time.Minute))
	cr.Temperature = cr.Temperature + rate
	return nil
}
