package reactor

import (
	"time"
)

// Component is the base component type.
type Component struct {
	Config

	Failed             bool
	FailureProbability float64
}

// Simulate runs the simulation.
func (c *Component) Simulate(quantum time.Duration) error {
	// given the quantum
	// and given the failure probability
	// compute if the component has failed.
	return nil
}
