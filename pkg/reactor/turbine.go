package reactor

import (
	"time"
)

// Interface Assertions
var (
	_ Simulatable = (*Turbine)(nil)
)

// NewTurbine returns a new turbine.
func NewTurbine(cfg Config) *Turbine {
	t := &Turbine{
		Component: NewComponent(cfg),
		Coolant:   NewCoolant(),
	}
	t.CoolantTempAlarm = NewThresholdAlarm(
		"Turbine Coolant Temp",
		func() float64 { return CoolantAverage(t.Coolant.Water) },
		SeverityThreshold(TurbineCoolantFatal, TurbineCoolantCritical, TurbineCoolantWarning),
	)
	t.SpeedRPMAlarm = NewThresholdAlarm(
		"Turbine Speed",
		func() float64 { return t.SpeedRPM },
		SeverityThreshold(TurbineRPMFatal, TurbineRPMCritical, TurbineRPMWarning),
	)
	return t
}

// Turbine generates power based on fan rpm.
type Turbine struct {
	*Component
	Output           float64
	SpeedRPM         float64
	SpeedRPMAlarm    *ThresholdAlarm
	Coolant          *Coolant
	CoolantTempAlarm *ThresholdAlarm
}

// Alarms implements alarmable.
func (t *Turbine) Alarms() []Alarm {
	return []Alarm{
		t.SpeedRPMAlarm,
		t.CoolantTempAlarm,
	}
}

// Simulate is the power output of the turbine.
func (t *Turbine) Simulate(quantum time.Duration) error {
	delta := CoolantAverage(t.Coolant.Water) - t.Config.BaseTempOrDefault()
	rate := (float64(quantum) / float64(time.Minute))
	accel := rate * t.Config.TurbineThermalRateMinuteOrDefault() * delta
	deccel := rate * t.Config.TurbineDragOrDefault() * t.SpeedRPM

	t.SpeedRPM = t.SpeedRPM + (accel / 2.0)
	t.SpeedRPM = t.SpeedRPM - deccel

	if t.SpeedRPM < 0 {
		t.SpeedRPM = 0
	}

	t.Output = t.SpeedRPM * t.Config.TurbineOutputRateMinuteOrDefault()
	return nil
}
