package reactor

import (
	"time"
)

// Interface Assertions
var (
	_ Simulatable = (*Reactor)(nil)
)

// NewReactor returns a new reactor.
func NewReactor(cfg Config) *Reactor {
	r := &Reactor{
		Component:       NewComponent(cfg),
		CoreTemp:        cfg.BaseTempOrDefault(),
		ContainmentTemp: cfg.BaseTempOrDefault(),
		ControlRods: []*ControlRod{
			NewControlRod(cfg, 0),
			NewControlRod(cfg, 1),
			NewControlRod(cfg, 2),
			NewControlRod(cfg, 3),
			NewControlRod(cfg, 4),
			NewControlRod(cfg, 5),
		},
		FuelRods: []*FuelRod{
			NewFuelRod(cfg, 0),
			NewFuelRod(cfg, 1),
			NewFuelRod(cfg, 2),
			NewFuelRod(cfg, 3),
			NewFuelRod(cfg, 4),
			NewFuelRod(cfg, 5),
			NewFuelRod(cfg, 6),
			NewFuelRod(cfg, 7),
			NewFuelRod(cfg, 8),
			NewFuelRod(cfg, 9),
			NewFuelRod(cfg, 10),
			NewFuelRod(cfg, 11),
		},
		Coolant:   NewCoolant(),
		Primary:   NewPump("primary", cfg),
		Secondary: NewPump("secondary", cfg),
		Turbine:   NewTurbine(cfg),
	}

	r.Primary.Inlet = r.Coolant
	r.Primary.Outlet = r.Turbine.Coolant
	r.Secondary.Inlet = r.Turbine.Coolant
	r.Secondary.Outlet = r.Coolant

	r.ContainmentTempAlarm = NewThresholdAlarm(
		"Containment Temp",
		func() float64 { return r.ContainmentTemp },
		Thresholds(ContainmentTempFatal, ContainmentTempCritical, ContainmentTempWarning),
	)
	r.CoreTempAlarm = NewThresholdAlarm(
		"Core Temp",
		func() float64 { return r.CoreTemp },
		Thresholds(CoreTempFatal, CoreTempCritical, CoreTempWarning),
	)
	return r
}

// Reactor is the main simulated object.
type Reactor struct {
	*Component

	Reactivity float64 // measured in watts

	CoreTemp             float64 // temp in celsius
	CoreTempAlarm        *ThresholdAlarm
	ContainmentTemp      float64 // temp in celsius
	ContainmentTempAlarm *ThresholdAlarm
	Coolant              *Coolant

	FuelRods    []*FuelRod
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
	for _, fr := range r.FuelRods {
		alarms = append(alarms, fr.Alarms()...)
	}
	for _, cr := range r.ControlRods {
		alarms = append(alarms, cr.Alarms()...)
	}
	alarms = append(alarms, r.Primary.Alarms()...)
	alarms = append(alarms, r.Turbine.Alarms()...)
	alarms = append(alarms, r.Secondary.Alarms()...)
	return alarms
}

// Simulate advances the simulation by the quantum.
func (r *Reactor) Simulate(quantum time.Duration) error {
	for _, fr := range r.FuelRods {
		if err := fr.Simulate(quantum); err != nil {
			return err
		}
		CoolantHeatTransfer(r.Coolant.Water, &fr.Temp, r.Config.ConductionRateMinuteOrDefault(), quantum)
	}

	for _, cr := range r.ControlRods {
		if err := cr.Simulate(quantum); err != nil {
			return err
		}
		CoolantHeatTransfer(r.Coolant.Water, &cr.Temp, r.Config.ConductionRateMinuteOrDefault(), quantum)
	}

	// create or remove steam based on heat
	if err := r.Primary.Simulate(quantum); err != nil {
		return err
	}
	if err := r.Turbine.Simulate(quantum); err != nil {
		return err
	}
	if err := r.Secondary.Simulate(quantum); err != nil {
		return err
	}
	for _, alarm := range r.Alarms() {
		if err := alarm.Simulate(quantum); err != nil {
			return err
		}
	}

	return nil
}
