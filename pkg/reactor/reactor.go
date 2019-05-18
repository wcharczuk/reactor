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
func NewReactor() *Reactor {
	r := &Reactor{
		CoreTemp:        BaseTemperature,
		ContainmentTemp: BaseTemperature,
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
	r.ContainmentTempAlarm = NewThresholdAlarm("Containment", TempThresholdMessageFormat, &r.ContainmentTemp, ContainmentTempFatal, ContainmentTempCritical, ContainmentTempWarning)
	r.CoreTempAlarm = NewThresholdAlarm("Core", TempThresholdMessageFormat, &r.CoreTemp, CoreTempFatal, CoreTempCritical, CoreTempWarning)
	return r
}

// Reactor is the main simulated object.
type Reactor struct {
	ContainmentTemp      float64
	ContainmentTempAlarm ThresholdAlarm
	CoreTemp             float64
	CoreTempAlarm        ThresholdAlarm

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
		Transfer(&cr.Temp, &r.CoreTemp, quantum, SinkTransferRateMinute/float64(len(r.ControlRods)))
	}

	// transfer core heat to primary inlet
	Transfer(&r.CoreTemp, &r.Primary.InletTemp, quantum, SinkTransferRateMinute)

	// transfer some of the core heat to the containment vessel
	Transfer(&r.CoreTemp, &r.ContainmentTemp, quantum, ContainmentTransferRateMinute)

	// transfer some containment temperature to the outside.
	containmentBase := float64(BaseTemperature)
	Transfer(&r.ContainmentTemp, &containmentBase, quantum, ContainmentTransferRateMinute/2.0)

	// transfer primary inlet to outlet based on speed
	if err := r.Primary.Simulate(quantum); err != nil {
		return err
	}

	// transfer primary outlet to secondary inlet
	Transfer(&r.Primary.OutletTemp, &r.Secondary.InletTemp, quantum, SinkTransferRateMinute)

	// transfer secondary inlet to outlet based on speed
	if err := r.Secondary.Simulate(quantum); err != nil {
		return err
	}

	// transfer secondary outlet to turbine inlet
	Transfer(&r.Secondary.OutletTemp, &r.Turbine.InletTemp, quantum, SinkTransferRateMinute)

	base := BaseTemperature
	Transfer(&r.Turbine.InletTemp, &base, quantum, SinkTransferRateMinute)

	if err := r.Turbine.Simulate(quantum); err != nil {
		return err
	}

	return nil
}
