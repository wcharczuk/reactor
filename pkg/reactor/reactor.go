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
	if r.ContainmentTemperature > ContainmentTempFatal {
		collector <- Alarm{Severity: AlarmFatal, Component: "Containment", Message: fmt.Sprintf("Above %0.2fc", ContainmentTempFatal)}
	} else if r.ContainmentTemperature > ContainmentTempCritical {
		collector <- Alarm{Severity: AlarmCritical, Component: "Containment", Message: fmt.Sprintf("Above %0.2fc", ContainmentTempCritical)}
	} else if r.ContainmentTemperature > ContainmentTempWarning {
		collector <- Alarm{Severity: AlarmWarning, Component: "Containment", Message: fmt.Sprintf("Above %0.2fc", ContainmentTempWarning)}
	}

	if r.ContainmentTemperature > CoreTempFatal {
		collector <- Alarm{Severity: AlarmFatal, Component: "Core", Message: fmt.Sprintf("Above %0.2fc", CoreTempFatal)}
	} else if r.ContainmentTemperature > CoreTempCritical {
		collector <- Alarm{Severity: AlarmCritical, Component: "Core", Message: fmt.Sprintf("Above %0.2fc", CoreTempCritical)}
	} else if r.ContainmentTemperature > CoreTempWarning {
		collector <- Alarm{Severity: AlarmWarning, Component: "Core", Message: fmt.Sprintf("Above %0.2fc", CoreTempWarning)}
	}

	for _, cr := range r.ControlRods {
		cr.CollectAlarms(collector)
	}
	r.Primary.CollectAlarms(collector)
	r.Secondary.CollectAlarms(collector)
	r.Turbine.CollectAlarms(collector)
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
