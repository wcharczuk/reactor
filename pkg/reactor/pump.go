package reactor

import (
	"fmt"
	"time"
)

// Interface Assertions
var (
	_ Simulatable = (*Pump)(nil)
	_ Alarmable   = (*Pump)(nil)
)

// NewPump returns a new pump.
func NewPump(name string) *Pump {
	return &Pump{
		Name:              name,
		Throttle:          PositionMin,
		InletTemperature:  BaseTemperature,
		OutletTemperature: BaseTemperature,
	}
}

// Pump moves coolant around.
type Pump struct {
	Name              string
	Throttle          Position
	InletTemperature  float64
	OutletTemperature float64
}

// CollectAlarms implements alarm provider.
func (p *Pump) CollectAlarms(collector chan Alarm) {
	if MaybeCreateAlarm(collector, AlarmFatal, fmt.Sprintf("%s Pump Inlet", p.Name), fmt.Sprintf("Above %.2fc", PumpInletFatal), &p.InletTemperature, PumpInletFatal) {}
	else if MaybeCreateAlarm(collector, AlarmCritical, fmt.Sprintf("%s Pump Inlet", p.Name), fmt.Sprintf("Above %.2fc", PumpInletCritical), &p.InletTemperature, PumpInletCritical) {}
	else MaybeCreateAlarm(collector, AlarmCritical, fmt.Sprintf("%s Pump Inlet", p.Name), fmt.Sprintf("Above %.2fc", PumpInletCritical), &p.InletTemperature, PumpInletCritical) {}

	if p.InletTemperature > PumpInletFatal {
		collector <- Alarm{Severity: AlarmFatal, Component: fmt.Sprintf("%s Pump Inlet", p.Name), Message: fmt.Sprintf("Above %.2fc", PumpInletFatal)}
	} else if p.InletTemperature > PumpInletCritical {
		collector <- Alarm{Severity: AlarmCritical, Component: fmt.Sprintf("%s Pump Inlet", p.Name), Message: fmt.Sprintf("Above %.2fc", PumpInletCritical)}
	} else if p.InletTemperature > PumpInletWarning {
		collector <- Alarm{Severity: AlarmWarning, Component: fmt.Sprintf("%s Pump Inlet", p.Name), Message: fmt.Sprintf("Above %.2fc", PumpInletWarning)}
	}

	if p.OutletTemperature > PumpOutletFatal {
		collector <- Alarm{Severity: AlarmFatal, Component: fmt.Sprintf("%s Pump Inlet", p.Name), Message: fmt.Sprintf("Above %.2fc", PumpInletFatal)}
	} else if p.OutletTemperature > PumpOutletCritical {
		collector <- Alarm{Severity: AlarmCritical, Component: fmt.Sprintf("%s Pump Inlet", p.Name), Message: fmt.Sprintf("Above %.2fc", PumpInletCritical)}
	} else if p.OutletTemperature > PumpOutletWarning {
		collector <- Alarm{Severity: AlarmWarning, Component: fmt.Sprintf("%s Pump Inlet", p.Name), Message: fmt.Sprintf("Above %.2fc", PumpInletWarning)}
	}

	if p.Throttle.IsZero() {
		collector <- Alarm{Severity: AlarmWarning, Component: fmt.Sprintf("%s Pump Throttle", p.Name), Message: "No Flow"}
	}
}

// Simulate processes a simulation tick.
func (p *Pump) Simulate(quantum time.Duration) error {
	Transfer(&p.InletTemperature, &p.OutletTemperature, quantum, float64(p.Throttle)*PumpTransferRateMinute)
	return nil
}
