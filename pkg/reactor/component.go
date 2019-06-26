package reactor

import "time"

// NewComponent returns a new component.
func NewComponent(cfg Config) *Component {
	return &Component{
		Config: cfg,
	}
}

// Component is the base component type.
type Component struct {
	Config             Config
	failureProbability func() float64
	failed             bool
}

// Failed returns if the component failed.
func (c Component) Failed() bool {
	return c.failed
}

// Simulate processes a simulation tick.
func (c *Component) Simulate(quantum time.Duration) error {
	if RollFailure(c.failureProbability(), quantum) {
		c.failed = true
	}
	return nil
}
