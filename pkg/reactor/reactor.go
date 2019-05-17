package reactor

import (
	"fmt"
	"time"
)

// Interface Assertions
var (
	_ Simulatable = (*Reactor)(nil)
	_ Alarmable   = (*Reactor)(nil)
)

// NewReactor returns a new reactor.
func NewReactor() *Reactor {
	return &Reactor{
		CoreTemperature:        BaseTemperature,
		ContainmentTemperature: BaseTemperature,
		ControlRods: []*ControlRod{
			NewControlRod(0),
			NewControlRod(1),
			NewControlRod(2),
			NewControlRod(3),
			NewControlRod(4),
		},
		Primary:   NewPump("Primary"),
		Secondary: NewPump("Secondary"),
		Turbine:   NewTurbine(),
	}
}

// Reactor is the main simulated object.
type Reactor struct {
	ContainmentTemperature float64
	CoreTemperature        float64

	ControlRods []*ControlRod
	Primary     *Pump
	Secondary   *Pump
	Turbine     *Turbine
}

// CollectAlarms fetches the current alarms.
func (r *Reactor) CollectAlarms(collector chan Alarm) {
	r.collectContainmentAlarms(collector)
	r.collectCoreAlarms(collector)

	for _, cr := range r.ControlRods {
		cr.CollectAlarms(collector)
	}
	r.Primary.CollectAlarms(collector)
	r.Secondary.CollectAlarms(collector)
	r.Turbine.CollectAlarms(collector)
}

func (r *Reactor) collectContainmentAlarms(collector chan Alarm) {
	if MaybeCreateAlarm(collector, AlarmFatal, "Containment", fmt.Sprintf("Above %.2fc", ContainmentTempFatal), &r.ContainmentTemperature, ContainmentTempFatal) {
		return
	}
	if MaybeCreateAlarm(collector, AlarmCritical, "Containment", fmt.Sprintf("Above %.2fc", ContainmentTempCritical), &r.ContainmentTemperature, ContainmentTempCritical) {
		return
	}
	MaybeCreateAlarm(collector, AlarmWarning, "Containment", fmt.Sprintf("Above %.2fc", ContainmentTempWarning), &r.ContainmentTemperature, ContainmentTempWarning)
}

func (r *Reactor) collectCoreAlarms(collector chan Alarm) {
	if MaybeCreateAlarm(collector, AlarmFatal, "Core", fmt.Sprintf("Above %.2fc", ControlRodTempFatal), &r.CoreTemperature, CoreTempFatal) {
		return
	}
	if MaybeCreateAlarm(collector, AlarmCritical, "Core", fmt.Sprintf("Above %.2fc", CoreTempCritical), &r.CoreTemperature, ControlRodTempCritical) {
		return
	}
	MaybeCreateAlarm(collector, AlarmWarning, "Core", fmt.Sprintf("Above %.2fc", CoreTempWarning), &r.CoreTemperature, CoreTempWarning)
}

// Simulate advances the simulation by the quantum.
func (r *Reactor) Simulate(quantum time.Duration) error {
	// create core heat
	for _, cr := range r.ControlRods {
		if err := cr.Simulate(quantum); err != nil {
			return err
		}
		Transfer(&cr.Temperature, &r.CoreTemperature, quantum, SinkTransferRateMinute/float64(len(r.ControlRods)))
	}

	// transfer core heat to primary inlet
	Transfer(&r.CoreTemperature, &r.Primary.InletTemperature, quantum, SinkTransferRateMinute)

	// transfer some containment temperature to the outside.
	containmentBase := float64(BaseTemperature)
	Transfer(&r.ContainmentTemperature, &containmentBase, quantum, ContainmentTransferRateMinute/2.0)

	// transfer primary inlet to outlet based on speed
	if err := r.Primary.Simulate(quantum); err != nil {
		return err
	}

	// transfer primary outlet to secondary inlet
	Transfer(&r.Primary.OutletTemperature, &r.Secondary.InletTemperature, quantum, SinkTransferRateMinute)

	// transfer secondary inlet to outlet based on speed
	if err := r.Secondary.Simulate(quantum); err != nil {
		return err
	}

	// transfer secondary outlet to turbine inlet
	Transfer(&r.Secondary.OutletTemperature, &r.Turbine.InletTemperature, quantum, SinkTransferRateMinute)

	if err := r.Turbine.Simulate(quantum); err != nil {
		return err
	}
	return nil
}
