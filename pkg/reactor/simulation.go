package reactor

import "time"

// NewSimulation returns a new simulation.
func NewSimulation() *Simulation {
	return &Simulation{
		Errors:  make(chan error, 1024),
		Reactor: NewReactor(),
	}
}

// Simulation is the entire state of a simulation.
type Simulation struct {
	Current time.Duration
	Events  chan Event
	Errors  chan error
	Command string
	Reactor *Reactor
}

// Simulate implements simulatable.
func (s *Simulation) Simulate(quantum time.Duration) error {
	if err := s.Reactor.Simulate(quantum); err != nil {
		return err
	}

	events := len(s.Events)
	var err error
	var event Event
	for x := 0; x < events; x++ {
		event = <-s.Events
		if err = event.Simulate(quantum); err != nil {
			return err
		}
		if !event.Done() {
			s.Events <- event
		}
	}

	s.Current = s.Current + quantum
	return nil
}
