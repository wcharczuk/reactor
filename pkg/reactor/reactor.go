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
		NeutronSource:   NewNeutronSource(cfg),
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
		Primary:   NewPump(cfg, "Primary"),
		Secondary: NewPump(cfg, "Secondary"),
		Turbine:   NewTurbine(cfg),
	}

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

	ReactionRate  float64
	Steam         float64
	Xenon         float64
	CoreTemp      float64
	CoreTempAlarm *ThresholdAlarm

	ContainmentTemp      float64
	ContainmentTempAlarm *ThresholdAlarm

	NeutronSource *NeutronSource
	ControlRods   []*ControlRod
	Primary       *Pump
	Secondary     *Pump
	Turbine       *Turbine
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
		Transfer(&cr.Temp, &r.CoreTemp, quantum, r.ConductionRateMinuteOrDefault())
	}
	Transfer(&r.CoreTemp, &r.Primary.InletTemp, quantum, r.ConductionRateMinuteOrDefault())

	// create or remove xenon
	r.createXenon(quantum)
	r.burnXenon(quantum)

	// create or remove steam

	Transfer(&r.CoreTemp, &r.Turbine.InletTemp, quantum, r.RadiantRateMinuteOrDefault())
	Transfer(&r.CoreTemp, &r.Primary.InletTemp, quantum, r.RadiantRateMinuteOrDefault())
	Transfer(&r.CoreTemp, &r.Primary.OutletTemp, quantum, r.RadiantRateMinuteOrDefault())
	Transfer(&r.CoreTemp, &r.Secondary.InletTemp, quantum, r.RadiantRateMinuteOrDefault())
	Transfer(&r.CoreTemp, &r.Secondary.OutletTemp, quantum, r.RadiantRateMinuteOrDefault())

	if err := r.Primary.Simulate(quantum); err != nil {
		return err
	}
	Transfer(&r.Primary.OutletTemp, &r.Secondary.InletTemp, quantum, r.ConductionRateMinuteOrDefault())
	if err := r.Secondary.Simulate(quantum); err != nil {
		return err
	}
	Transfer(&r.Secondary.OutletTemp, &r.Turbine.InletTemp, quantum, r.ConductionRateMinuteOrDefault())
	Transfer(&r.Turbine.InletTemp, r.baseTemp(), quantum, r.ConductionRateMinuteOrDefault())
	if err := r.Turbine.Simulate(quantum); err != nil {
		return err
	}

	Transfer(&r.CoreTemp, &r.ContainmentTemp, quantum, r.ConvectionRateMinuteOrDefault())
	Transfer(&r.ContainmentTemp, r.baseTemp(), quantum, r.RadiantRateMinuteOrDefault())

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

	r.Xenon = r.Xenon - ((r.CoreTemp - XenonThreshold) * QuantumFraction(XenonBurnRate, quantum))
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
