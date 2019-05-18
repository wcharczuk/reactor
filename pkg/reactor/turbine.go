package reactor

import (
	"time"
)

// Interface Assertions
var (
	_ Simulatable = (*Turbine)(nil)
	_ Alarmable   = (*Turbine)(nil)
)

// NewTurbine returns a new turbine.
func NewTurbine(cfg Config) *Turbine {
	t := &Turbine{
		Config:    cfg,
		InletTemp: cfg.BaseTempOrDefault(),
	}
	t.SpeedRPMAlarm = NewThresholdAlarm("Turbine", RPMThresholdMessageFormat, &t.SpeedRPM, TurbineRPMFatal, TurbineRPMCritical, TurbineRPMWarning)
	return t
}

// Turbine generates power based on fan rpm.
type Turbine struct {
	Config

	SpeedRPM      float64
	SpeedRPMAlarm ThresholdAlarm
	Output        float64
	InletTemp     float64
}

// Alarms implements alarmable.
func (t *Turbine) Alarms() []Alarm {
	return []Alarm{
		t.SpeedRPMAlarm,
	}
}

// Simulate is the power output of the turbine.
func (t *Turbine) Simulate(quantum time.Duration) error {
	delta := t.InletTemp - t.BaseTempOrDefault()
	rate := (float64(quantum) / float64(time.Minute))
	accel := rate * t.TurbineThermalRateMinuteOrDefault() * delta
	deccel := rate * t.TurbineDragOrDefault() * t.SpeedRPM

	t.SpeedRPM = t.SpeedRPM + accel
	t.SpeedRPM = t.SpeedRPM - deccel

	if t.SpeedRPM < 0 {
		t.SpeedRPM = 0
	}

	t.Output = t.SpeedRPM * t.TurbineOutputRateMinuteOrDefault()
	return nil
}
