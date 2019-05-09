package reactor

import "time"

// NewReactor returns a new reactor.
func NewReactor() Reactor {
	return Reactor{
		CoreTemperature:        BaseTemperature,
		ContainmentTemperature: BaseTemperature,
		ControlRods: []ControlRod{
			ControlRod{Position: PositionMax},
			ControlRod{Position: PositionMax},
			ControlRod{Position: PositionMax},
		},
		Primary: Pump{
			InletTemperature:  BaseTemperature,
			OutletTemperature: BaseTemperature,
		},
		Secondary: Pump{
			InletTemperature:  BaseTemperature,
			OutletTemperature: BaseTemperature,
		},
	}
}

// Reactor is the main simulated object.
type Reactor struct {
	Alarm bool

	ContainmentTemperature float64
	CoreTemperature        float64

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
