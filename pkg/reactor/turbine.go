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
		InletTemp: cfg.BaseTempOrDefault(),
	}
	t.SpeedRPMAlarm = NewThresholdAlarm(
		"Turbine",
		&t.SpeedRPM,
		SeverityThreshold(TurbineRPMFatal, TurbineRPMCritical, TurbineRPMWarning),
	)
	t.InletTempAlarm = NewThresholdAlarm(
		"Turbine Inlet",
		&t.InletTemp,
		SeverityThreshold(PumpInletFatal, PumpInletCritical, PumpInletWarning),
	)
	return t
}

// Turbine generates power based on fan rpm.
type Turbine struct {
	*Component

	Output float64

	SpeedRPM      float64
	SpeedRPMAlarm *ThresholdAlarm

	InletTemp      float64
	InletTempAlarm *ThresholdAlarm
}

// Alarms implements alarmable.
func (t *Turbine) Alarms() []Alarm {
	return []Alarm{
		t.SpeedRPMAlarm,
		t.InletTempAlarm,
	}
}

// Simulate is the power output of the turbine.
func (t *Turbine) Simulate(quantum time.Duration) error {
	delta := t.InletTemp - t.BaseTempOrDefault()
	rate := (float64(quantum) / float64(time.Minute))
	accel := rate * t.TurbineThermalRateMinuteOrDefault() * delta
	deccel := rate * t.TurbineDragOrDefault() * t.SpeedRPM

	t.SpeedRPM = t.SpeedRPM + (accel / 2.0)
	t.SpeedRPM = t.SpeedRPM - deccel

	if t.SpeedRPM < 0 {
		t.SpeedRPM = 0
	}

	t.Output = t.SpeedRPM * t.TurbineOutputRateMinuteOrDefault()
	return nil
}
