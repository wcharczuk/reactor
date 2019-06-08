package reactor

import "time"

// NewEvaporator returns a new evaporator.
func NewEvaporator(cfg Config) *Evaporator {
	return &Evaporator{
		Component: NewComponent(cfg),
	}
}

// Evaporator separates steam from water, cooling the steam.
type Evaporator struct {
	*Component
	Inlet  chan *Water
	Outlet chan *Water
}

// Simulate applies a simpulation tikc.
func (e *Evaporator) Simulate(quantum time.Duration) error {
	return nil
}
