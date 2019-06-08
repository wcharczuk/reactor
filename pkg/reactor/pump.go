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

	Inlet  chan *Water
	Outlet chan *Water
}

// Alarms implements alarm provider.
func (p *Pump) Alarms() []Alarm {
	return nil
}

// Simulate processes a simulation tick.
func (p *Pump) Simulate(quantum time.Duration) error {
	rate := float64(p.Throttle) * p.Config.PumpTransferRateMinuteOrDefault()
	effectiveRate := QuantumFraction(rate, quantum)
	for x := 0; x < int(effectiveRate); x++ {
		p.Outlet <- <-p.Inlet
	}
	return nil
}
