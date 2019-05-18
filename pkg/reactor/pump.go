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
		Config:     cfg,
		Name:       name,
		Throttle:   PositionMin,
		InletTemp:  cfg.BaseTempOrDefault(),
		OutletTemp: cfg.BaseTempOrDefault(),
	}
	p.InletTempAlarm = NewThresholdAlarm(fmt.Sprintf("%s Pump", name), TempThresholdMessageFormat, &p.InletTemp, PumpInletFatal, PumpInletCritical, PumpInletWarning)
	p.OutletTempAlarm = NewThresholdAlarm(fmt.Sprintf("%s Pump", name), TempThresholdMessageFormat, &p.OutletTemp, PumpInletFatal, PumpInletCritical, PumpInletWarning)
	p.ThrottlePositionAlarm = NewPositionZeroAlarm(fmt.Sprintf("%s Pump", name), "No flow", &p.Throttle)
	return p
}

// Pump moves coolant around.
type Pump struct {
	Config

	Name                  string
	Throttle              Position
	ThrottlePositionAlarm PositionZeroAlarm
	InletTemp             float64
	InletTempAlarm        ThresholdAlarm
	OutletTemp            float64
	OutletTempAlarm       ThresholdAlarm
}

// Alarms implements alarm provider.
func (p *Pump) Alarms() []Alarm {
	return []Alarm{
		p.InletTempAlarm,
		p.OutletTempAlarm,
		p.ThrottlePositionAlarm,
	}
}

// Simulate processes a simulation tick.
func (p *Pump) Simulate(quantum time.Duration) error {
	Transfer(&p.InletTemp, &p.OutletTemp, quantum, float64(p.Throttle)*p.PrimaryTransferRateMinuteOrDefault())
	return nil
}
