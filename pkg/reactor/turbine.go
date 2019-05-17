package reactor

import (
	"fmt"
	"time"
)

// Interface Assertions
var (
	_ Simulatable = (*Turbine)(nil)
	_ Alarmable   = (*Turbine)(nil)
)

// NewTurbine returns a new turbine.
func NewTurbine() *Turbine {
	return &Turbine{
		InletTemperature: BaseTemperature,
	}
}

// Turbine generates power based on fan rpm.
type Turbine struct {
	SpeedRPM         float64
	Output           float64
	InletTemperature float64
}

// CollectAlarms implements alarmable.
func (t *Turbine) CollectAlarms(collector chan Alarm) {
	if MaybeCreateAlarm(collector, AlarmFatal, "Turbine", fmt.Sprintf("RPM Above %.2fc", TurbineRPMFatal), &t.SpeedRPM, TurbineRPMFatal) {
		return
	}
	if MaybeCreateAlarm(collector, AlarmCritical, "Turbine", fmt.Sprintf("RPM Above %.2fc", TurbineRPMCritical), &t.SpeedRPM, TurbineRPMCritical) {
		return
	}
	MaybeCreateAlarm(collector, AlarmWarning, "Turbine", fmt.Sprintf("RPM Above %.2fc", TurbineRPMWarning), &t.SpeedRPM, TurbineRPMWarning)
}

// Simulate is the power output of the turbine.
func (t *Turbine) Simulate(quantum time.Duration) error {
	delta := t.InletTemperature - BaseTemperature
	rate := (float64(quantum) / float64(time.Minute))
	accel := rate * TurbineOutputRateMinute * delta
	deccel := t.SpeedRPM * 0.15 * rate
	t.SpeedRPM = t.SpeedRPM + accel
	t.SpeedRPM = t.SpeedRPM - deccel
	t.Output = t.SpeedRPM * TurbineOutputRateMinute
	return nil
}
