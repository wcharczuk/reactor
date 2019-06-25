package reactor

import (
	"time"
)

// Interface Assertions
var (
	_ Simulatable = (*Pump)(nil)
)

// NewPump returns a new pump.
func NewPump(cfg Config) *Pump {
	return &Pump{
		Component: NewComponent(cfg),
		Throttle:  PositionMin,
	}
}

// Pump moves coolant around.
type Pump struct {
	*Component
	Throttle Position

	Inlet  *Coolant
	Outlet *Coolant
}

// Alarms implements alarm provider.
func (p *Pump) Alarms() []Alarm {
	return nil
}

// Simulate processes a simulation tick.
func (p *Pump) Simulate(quantum time.Duration) error {
	rate := float64(p.Throttle) * p.Config.PumpTransferRateMinuteOrDefault()
	effectiveRate := QuantumFraction(rate, quantum)
	p.Outlet.Push(p.Inlet.Pull(int(effectiveRate))...)
	return nil
}
