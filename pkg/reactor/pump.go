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
func NewPump(name string, cfg Config) *Pump {
	p := &Pump{
		Component: NewComponent(cfg),
		Throttle:  PositionMin,
	}

	p.InletTempAlarm = NewThresholdAlarm(
		fmt.Sprintf("%s Pump Inlet Temp", name),
		func() float64 { return CoolantAverage(p.Inlet.Water) },
		SeverityThreshold(PumpInletFatal, PumpInletCritical, PumpInletWarning),
	)
	p.OutletTempAlarm = NewThresholdAlarm(
		fmt.Sprintf("%s Pump Outlet Temp", name),
		func() float64 { return CoolantAverage(p.Outlet.Water) },
		SeverityThreshold(PumpOutletFatal, PumpOutletCritical, PumpOutletWarning),
	)

	return p
}

// Pump moves coolant around.
type Pump struct {
	*Component
	Throttle Position

	Inlet           *Coolant
	InletTempAlarm  *ThresholdAlarm
	Outlet          *Coolant
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
	rate := float64(p.Throttle) * p.Config.PumpTransferRateMinuteOrDefault()
	effectiveRate := QuantumFraction(rate, quantum)
	p.Outlet.Push(p.Inlet.Pull(int(effectiveRate))...)
	return nil
}
