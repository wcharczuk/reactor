package reactor

import (
	"time"
)

// Interface Assertions
var (
	_ Simulatable = (*Reactor)(nil)
	_ Alarmable   = (*Reactor)(nil)
)

// NewReactor returns a new reactor.
func NewReactor(cfg Config) *Reactor {
	r := &Reactor{
		Config:          cfg,
		CoreTemp:        cfg.BaseTempOrDefault(),
		ContainmentTemp: cfg.BaseTempOrDefault(),
		ControlRods: []*ControlRod{
			NewControlRod(cfg, 0),
			NewControlRod(cfg, 1),
			NewControlRod(cfg, 2),
			NewControlRod(cfg, 3),
			NewControlRod(cfg, 4),
		},
		Primary:   NewPump(cfg, "Primary"),
		Secondary: NewPump(cfg, "Secondary"),
		Turbine:   NewTurbine(cfg),
	}
	r.ContainmentTempAlarm = NewThresholdAlarm("Containment", TempThresholdMessageFormat, &r.ContainmentTemp, ContainmentTempFatal, ContainmentTempCritical, ContainmentTempWarning)
	r.CoreTempAlarm = NewThresholdAlarm("Core", TempThresholdMessageFormat, &r.CoreTemp, CoreTempFatal, CoreTempCritical, CoreTempWarning)
	return r
}

// Reactor is the main simulated object.
type Reactor struct {
	Config

	ContainmentTemp      float64
	ContainmentTempAlarm *ThresholdAlarm
	CoreTemp             float64
	CoreTempAlarm        *ThresholdAlarm

	ControlRods []*ControlRod
	Primary     *Pump
	Secondary   *Pump
	Turbine     *Turbine
}

// Alarms fetches the current alarms.
func (r *Reactor) Alarms() []Alarm {
	alarms := []Alarm{
		r.ContainmentTempAlarm,
		r.CoreTempAlarm,
	}

	for _, cr := range r.ControlRods {
		alarms = append(alarms, cr.Alarms()...)
	}
	alarms = append(alarms, r.Primary.Alarms()...)
	alarms = append(alarms, r.Secondary.Alarms()...)
	alarms = append(alarms, r.Turbine.Alarms()...)
	return alarms
}

// Simulate advances the simulation by the quantum.
func (r *Reactor) Simulate(quantum time.Duration) error {
	// create core heat
	for _, cr := range r.ControlRods {
		if err := cr.Simulate(quantum); err != nil {
			return err
		}
		Transfer(&cr.Temp, &r.CoreTemp, quantum, r.ConductionRateMinuteOrDefault()/float64(len(r.ControlRods)))
	}

	// transfer core heat to primary inlet
	Transfer(&r.CoreTemp, &r.Primary.InletTemp, quantum, r.ConductionRateMinuteOrDefault())

	// transfer some of the core heat to the containment vessel
	Transfer(&r.CoreTemp, &r.ContainmentTemp, quantum, r.RadiantRateMinuteOrDefault())

	// transfer some containment temperature to the outside.
	containmentBase := float64(r.BaseTempOrDefault())
	Transfer(&r.ContainmentTemp, &containmentBase, quantum, r.RadiantRateMinuteOrDefault()/2.0)

	// transfer primary inlet to outlet based on speed
	if err := r.Primary.Simulate(quantum); err != nil {
		return err
	}

	// transfer primary outlet to secondary inlet
	Transfer(&r.Primary.OutletTemp, &r.Secondary.InletTemp, quantum, r.ConductionRateMinuteOrDefault())

	// transfer secondary inlet to outlet based on speed
	if err := r.Secondary.Simulate(quantum); err != nil {
		return err
	}

	// transfer secondary outlet to turbine inlet
	Transfer(&r.Secondary.OutletTemp, &r.Turbine.InletTemp, quantum, r.ConductionRateMinuteOrDefault())

	base := r.BaseTempOrDefault()
	Transfer(&r.Turbine.InletTemp, &base, quantum, r.ConductionRateMinuteOrDefault())

	if err := r.Turbine.Simulate(quantum); err != nil {
		return err
	}

	return nil
}
