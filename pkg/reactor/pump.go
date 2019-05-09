package reactor

import "time"

// Pump moves coolant around.
type Pump struct {
	Throttle          Position
	InletTemperature  float64
	OutletTemperature float64
}

// Simulate processes a simulation tick.
func (p Pump) Simulate(quantum time.Duration) error {
	return nil
}
