package reactor

import "time"

// NewPump returns a new pump.
func NewPump() *Pump {
	return &Pump{
		Throttle:          PositionMin,
		InletTemperature:  BaseTemperature,
		OutletTemperature: BaseTemperature,
	}
}

// Pump moves coolant around.
type Pump struct {
	Throttle          Position
	InletTemperature  float64
	OutletTemperature float64
}

// Simulate processes a simulation tick.
func (p *Pump) Simulate(quantum time.Duration) error {
	Transfer(&p.InletTemperature, &p.OutletTemperature, quantum, float64(p.Throttle)*PumpTransferRateMinute)
	return nil
}
