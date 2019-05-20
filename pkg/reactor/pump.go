package reactor

import (
	"fmt"
	"time"
)

// Interface Assertions
var (
	_ Simulatable = (*Pump)(nil)
)

// NewPump returns a new pump.
func NewPump(cfg Config, name string) *Pump {
	p := &Pump{
		Component:  NewComponent(cfg),
		Name:       name,
		Throttle:   PositionMin,
		InletTemp:  cfg.BaseTempOrDefault(),
		OutletTemp: cfg.BaseTempOrDefault(),
	}
	p.InletTempAlarm = NewThresholdAlarm(
		fmt.Sprintf("%s Pump Inlet Temp", name),
		&p.InletTemp,
		SeverityThreshold(PumpInletFatal, PumpInletCritical, PumpInletWarning),
	)
	p.OutletTempAlarm = NewThresholdAlarm(
		fmt.Sprintf("%s Pump Outlet Temp", name),
		&p.OutletTemp,
		SeverityThreshold(PumpOutletFatal, PumpOutletCritical, PumpOutletWarning),
	)
	return p
}

// Pump moves coolant around.
type Pump struct {
	*Component

	Name            string
	Throttle        Position
	InletTemp       float64
	InletTempAlarm  *ThresholdAlarm
	OutletTemp      float64
	OutletTempAlarm *ThresholdAlarm
}

// Alarms implements alarm provider.
func (p *Pump) Alarms() []Alarm {
	return []Alarm{
		p.InletTempAlarm,
		p.OutletTempAlarm,
	}
}

// Simulate processes a simulation tick.
func (p *Pump) Simulate(quantum time.Duration) error {
	Transfer(&p.InletTemp, &p.OutletTemp, quantum, float64(p.Throttle)*p.PrimaryTransferRateMinuteOrDefault())
	return nil
}
