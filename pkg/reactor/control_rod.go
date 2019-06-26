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
		SeverityThreshold(ControlRodTempFatal, ControlRodTempCritical, ControlRodTempWarning),
	)
	return cr
}

// ControlRod controls the rate of the reaction.
// Each control rod simulates both the control and the fuel.
// If a control rod is fully retracted, i.e. its position 0,
// then the reaction is fully active.
type ControlRod struct {
	*Component

	Reactivity float64
	Steam      float64
	Xenon      float64

	Index    int
	Position Position

	Temp      float64
	TempAlarm *ThresholdAlarm
}

// Alarms implements alarm provider.
func (cr *ControlRod) Alarms() []Alarm {
	return []Alarm{cr.TempAlarm}
}

// Simulate applies a simulation tick.
func (cr *ControlRod) Simulate(quantum time.Duration) error {
	cr.temperature(quantum)
	cr.xenon(quantum)
	cr.steam(quantum)
	cr.reactivity(quantum)
	return nil
}

func (cr *ControlRod) temperature(quantum time.Duration) {
	rate := QuantumFraction(float64(PositionMax-cr.Position)*cr.FissionRateMinuteOrDefault(), quantum)
	cr.Temp = cr.Temp + rate
}

func (cr *ControlRod) reactivity(quantum time.Duration) {
	rate := QuantumFraction(float64(PositionMax-cr.Position)*cr.FissionRateMinuteOrDefault(), quantum)
	cr.Reactivity = cr.Reactivity + rate
}

func (cr *ControlRod) xenon(quantum time.Duration) {
	cr.Xenon = cr.Xenon + (cr.Reactivity * QuantumFraction(XenonProductionRate, quantum))
	if cr.Temp < XenonThreshold {
		return
	}
	cr.Xenon = cr.Xenon - ((cr.Temp - XenonThreshold) * QuantumFraction(XenonBurnRateMinute, quantum))
	return
}

func (cr *ControlRod) steam(quantum time.Duration) {
	if cr.Temp < SteamThreshold {
		return
	}
	return
}
