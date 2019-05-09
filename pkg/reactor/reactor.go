package reactor

import "time"

// NewReactor returns a new reactor.
func NewReactor() Reactor {
	return Reactor{
		CoreTemperatureKelvin:        BaseTemperatureKelvin,
		ContainmentTemperatureKelvin: BaseTemperatureKelvin,
		ControlRods: []ControlRod{
			ControlRod{Position: PositionMax},
			ControlRod{Position: PositionMax},
			ControlRod{Position: PositionMax},
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
	Alarm bool

	ContainmentTemperatureKelvin float64
	CoreTemperatureKelvin        float64

	ControlRods []ControlRod
	Primary     Pump
	Secondary   Pump
	Turbine     Turbine
}

// Simulate advances the simulation by the quantum.
func (r Reactor) Simulate(quantum time.Duration) error {
	// do the output calculation
	return nil
}
