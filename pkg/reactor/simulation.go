package reactor

import (
	"fmt"
	"time"
)

// NewSimulation returns a new simulation.
func NewSimulation() *Simulation {
	return &Simulation{
		Inputs:   make(chan Input, 64),
		Messages: make(chan Message, 64),
		Reactor:  NewReactor(),
	}
}

// Simulation is the entire state of a simulation.
type Simulation struct {
	TimeSinceStart time.Duration
	Inputs         chan Input
	Messages       chan Message
	Command        string
	Reactor        *Reactor
}

// Messagef logs a message with a given format and arguments.
func (s *Simulation) Messagef(format string, args ...interface{}) {
	s.Message(fmt.Sprintf(format, args...))
}

// Message logs a message with a given text value.
func (s *Simulation) Message(args ...interface{}) {
	s.Messages <- Message{
		Timestamp: time.Now(),
		Text:      fmt.Sprint(args...),
	}
}

// Simulate implements simulatable.
func (s *Simulation) Simulate(quantum time.Duration) error {
	if err := s.Reactor.Simulate(quantum); err != nil {
		return err
	}

	inputs := len(s.Inputs)
	var err error
	var i Input
	for x := 0; x < inputs; x++ {
		i = <-s.Inputs
		if err = i.Simulate(quantum); err != nil {
			return err
		}
		if !i.Done() {
			s.Inputs <- i
		}
	}

	s.TimeSinceStart = s.TimeSinceStart + quantum
	return nil
}
