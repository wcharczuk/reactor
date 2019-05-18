package reactor

import (
	"fmt"
	"time"
)

// NewControlRod returns a new control rod.
func NewControlRod(cfg Config, index int) *ControlRod {
	cr := &ControlRod{
		Config:   cfg,
		Index:    index,
		Position: PositionMax,
		Temp:     cfg.BaseTempOrDefault(),
	}
	cr.TempAlarm = NewThresholdAlarm(fmt.Sprintf("Control Rod %d", index), TempThresholdMessageFormat, &cr.Temp, ControlRodTempFatal, ControlRodTempCritical, ControlRodTempWarning)
	return cr
}

// ControlRod controls the rate of the reaction.
// Each control rod simulates both the control and the fuel.
// If a control rod is fully retracted, i.e. its position 0,
// then the reaction is fully active.
type ControlRod struct {
	Config

	Index     int
	Position  Position
	Temp      float64
	TempAlarm ThresholdAlarm
}

// Alarms implements alarm provider.
func (cr *ControlRod) Alarms() []Alarm {
	return []Alarm{cr.TempAlarm}
}

// Simulate applies a simulation tick.
func (cr *ControlRod) Simulate(quantum time.Duration) error {
	rate := float64(PositionMax-cr.Position) * cr.FissionRateMinuteOrDefault() * (float64(quantum) / float64(time.Minute))
	cr.Temp = cr.Temp + rate
	return nil
}
