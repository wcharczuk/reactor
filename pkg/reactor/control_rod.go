package reactor

import (
	"fmt"
	"time"
)

// NewControlRod returns a new control rod.
func NewControlRod(cfg Config, index int) *ControlRod {
	cr := &ControlRod{
		Component: NewComponent(cfg),
		Index:     index,
		Position:  PositionMax,
		Temp:      cfg.BaseTempOrDefault(),
	}
	cr.TempAlarm = NewThresholdAlarm(
		fmt.Sprintf("Control Rod %d temp", index),
		func() float64 { return cr.Temp },
		Thresholds(ControlRodTempFatal, ControlRodTempCritical, ControlRodTempWarning),
	)
	return cr
}

// ControlRod controls the rate of the reaction.
type ControlRod struct {
	*Component
	Index     int
	Temp      float64
	TempAlarm *ThresholdAlarm
	Position  Position
}

// Alarms returns alarms.
func (cr *ControlRod) Alarms() []Alarm {
	return []Alarm{cr.TempAlarm}
}

// Simulate applies a simulation tick.
func (cr *ControlRod) Simulate(quantum time.Duration) error {
	return nil
}
