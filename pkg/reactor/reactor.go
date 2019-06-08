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
		},
		Coolant: FillWater(CoolantLoopVolume * 2),
		Pump:    NewPump(cfg),
		Turbine: NewTurbine(cfg),
	}

	r.Pump.Inlet = r.Coolant
	r.Turbine.Inlet = r.Pump.Outlet
	r.Turbine.Outlet = r.Evaporator.Inlet
	r.Evaporator.Outlet = r.Coolant

	r.ContainmentTempAlarm = NewThresholdAlarm(
		"Containment Temp",
		&r.ContainmentTemp,
		SeverityThreshold(ContainmentTempFatal, ContainmentTempCritical, ContainmentTempWarning),
	)
	r.CoreTempAlarm = NewThresholdAlarm(
		"Core Temp",
		&r.CoreTemp,
		SeverityThreshold(CoreTempFatal, CoreTempCritical, CoreTempWarning),
	)
	return r
}

// Reactor is the main simulated object.
type Reactor struct {
	*Component

	ReactionRate float64

	Water float64
	Steam float64

	Xenon         float64
	CoreTemp      float64
	CoreTempAlarm *ThresholdAlarm

	ContainmentTemp      float64
	ContainmentTempAlarm *ThresholdAlarm

	Coolant chan *Water

	ControlRods []*ControlRod
	Pump        *Pump
	Turbine     *Turbine
	Evaporator  *Evaporator
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
	}

	// create or remove xenon
	r.createXenon(quantum)
	r.burnXenon(quantum)

	// simulate moving water through the core.
	if err := r.Primary.Simulate(quantum); err != nil {
		return err
	}
	if err := r.Turbine.Simulate(quantum); err != nil {
		return err
	}

	for _, alarm := range r.Alarms() {
		if err := alarm.Simulate(quantum); err != nil {
			return err
		}
	}

	return nil
}

func (r *Reactor) createXenon(quantum time.Duration) {
	r.Xenon = r.Xenon + (r.ReactionRate * QuantumFraction(XenonProductionRate, quantum))
	return
}

func (r *Reactor) burnXenon(quantum time.Duration) {
	if r.CoreTemp < XenonThreshold {
		return
	}
	r.Xenon = r.Xenon - ((r.CoreTemp - XenonThreshold) * QuantumFraction(XenonBurnRateMinute, quantum))
	return
}

func (r *Reactor) createSteam(quantum time.Duration) {
	if r.CoreTemp < SteamThreshold {
		return
	}

	return
}

//
// utility functions
//

func (r *Reactor) baseTemp() *float64 {
	base := r.BaseTempOrDefault()
	return &base
}
