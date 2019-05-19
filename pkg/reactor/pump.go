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
func NewPump(cfg Config, name string) *Pump {
	p := &Pump{
		Component: Component{
			Config: cfg,
		},
		Name:       name,
		Throttle:   PositionMin,
		InletTemp:  cfg.BaseTempOrDefault(),
		OutletTemp: cfg.BaseTempOrDefault(),
	}
	p.InletTempAlarm = NewThresholdAlarm(fmt.Sprintf("%s Pump", name), TempThresholdMessageFormat, &p.InletTemp, PumpInletFatal, PumpInletCritical, PumpInletWarning)
	p.OutletTempAlarm = NewThresholdAlarm(fmt.Sprintf("%s Pump", name), TempThresholdMessageFormat, &p.OutletTemp, PumpInletFatal, PumpInletCritical, PumpInletWarning)
	return p
}

// Pump moves coolant around.
type Pump struct {
	Component

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

	p.Component.FailureProbability = (FailureProbability(p.InletTempAlarm.Severity()) + FailureProbability(p.OutletTempAlarm.Severity()))
	if err := p.Component.Simulate(quantum); err != nil {
		return err
	}
	return nil
}
