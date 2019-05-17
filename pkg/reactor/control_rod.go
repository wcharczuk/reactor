package reactor

import "time"

// NewControlRod returns a new control rod.
func NewControlRod() *ControlRod {
	return &ControlRod{
		Position:    PositionMax,
		Temperature: BaseTemperature,
	}
}

// ControlRod controls the rate of the reaction.
// Each control rod simulates both the control and the fuel.
// If a control rod is fully retracted, i.e. its position 0,
// then the reaction is fully active.
type ControlRod struct {
	Position    Position
	Temperature float64
}

// Simulate applies a simulation tick.
func (cr *ControlRod) Simulate(quantum time.Duration) error {
	rate := float64(PositionMax-cr.Position) * FissionRateMinute * (float64(quantum) / float64(time.Minute))
	cr.Temperature = cr.Temperature + rate
	return nil
}
