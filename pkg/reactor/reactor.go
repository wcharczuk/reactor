package reactor

import "time"

// NewReactor returns a new reactor.
func NewReactor() *Reactor {
	return &Reactor{
		CoreTemperatureKelvin:        BaseTemperatureKelvin,
		ContainmentTemperatureKelvon: BaseTemperatureKelvin,
		ControlRods: []ControlRod{
			ControlRod{Position: Max8},
			ControlRod{Position: Max8},
			ControlRod{Position: Max8},
		},
		Primary: Pump{
			InletTemperatureKelvin:  BaseTemperatureKelvin,
			OutletTemperatureKelvin: BaseTemperatureKelvin,
		},
		Secondary: Pump{
			InletTemperatureKelvin:  BaseTemperatureKelvin,
			OutletTemperatureKelvin: BaseTemperatureKelvin,
		},
	}
}

// Reactor is the main simulated object.
type Reactor struct {
	ContainmentTemperatureKelvon float64
	CoreTemperatureKelvin        float64

	ControlRods []ControlRod
	Primary     Pump
	Secondary   Pump
	Turbine     Turbine
}

// Simulate advances the simulation by the quantum.
func (r *Reactor) Simulate(quantum time.Duration) error {
	return nil
}
