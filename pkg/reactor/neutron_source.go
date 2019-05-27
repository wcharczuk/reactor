package reactor

import "time"

// NewNeutronSource returns a new neutron source.
func NewNeutronSource(cfg Config) *NeutronSource {
	return &NeutronSource{
		Component: NewComponent(cfg),
		Fuel:      cfg.NeutronFuelOrDefault(),
	}
}

// NeutronSource is a source for neutrons; it's
// used to bootstrap the reaction.
type NeutronSource struct {
	*Component

	Fuel     float64
	Position Position
}

// Alarms returns the alarms for the component.
func (ns *NeutronSource) Alarms() []Alarm {
	return nil
}

// Simulate processes a simulation tick.
func (ns *NeutronSource) Simulate(quantum time.Duration) error {
	quantumRate := float64(quantum) / float64(time.Minute)
	ns.Fuel = ns.Fuel - (quantumRate * float64(ns.Position))
	return nil
}
