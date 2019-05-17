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
	p.collectInletAlarms(collector)
	p.collectOutletAlarms(collector)

	if p.Throttle.IsZero() {
		collector <- Alarm{
			Severity:  AlarmWarning,
			Component: fmt.Sprintf("%s Pump Throttle", p.Name),
			Message:   "No Flow",
			DoneProvider: func() bool {
				return !p.Throttle.IsZero()
			},
		}
	}
}

func (p *Pump) collectInletAlarms(collector chan Alarm) {
	if MaybeCreateAlarm(collector, AlarmFatal, fmt.Sprintf("%s Pump Inlet", p.Name), fmt.Sprintf("Above %.2fc", PumpInletFatal), &p.InletTemperature, PumpInletFatal) {
		return
	} else if MaybeCreateAlarm(collector, AlarmCritical, fmt.Sprintf("%s Pump Inlet", p.Name), fmt.Sprintf("Above %.2fc", PumpInletCritical), &p.InletTemperature, PumpInletCritical) {
		return
	}
	MaybeCreateAlarm(collector, AlarmCritical, fmt.Sprintf("%s Pump Inlet", p.Name), fmt.Sprintf("Above %.2fc", PumpInletCritical), &p.InletTemperature, PumpInletCritical)
}

func (p *Pump) collectOutletAlarms(collector chan Alarm) {
	if MaybeCreateAlarm(collector, AlarmFatal, fmt.Sprintf("%s Pump Outlet", p.Name), fmt.Sprintf("Above %.2fc", PumpOutletFatal), &p.OutletTemperature, PumpOutletFatal) {
		return
	} else if MaybeCreateAlarm(collector, AlarmCritical, fmt.Sprintf("%s Pump Outlet", p.Name), fmt.Sprintf("Above %.2fc", PumpOutletCritical), &p.OutletTemperature, PumpOutletCritical) {
		return
	}
	MaybeCreateAlarm(collector, AlarmCritical, fmt.Sprintf("%s Pump Outlet", p.Name), fmt.Sprintf("Above %.2fc", PumpOutletWarning), &p.OutletTemperature, PumpOutletWarning)
}

// Simulate processes a simulation tick.
func (p *Pump) Simulate(quantum time.Duration) error {
	Transfer(&p.InletTemperature, &p.OutletTemperature, quantum, float64(p.Throttle)*PumpTransferRateMinute)
	return nil
}
