package reactor

import (
	"errors"
	"fmt"
	"strings"
	"time"
)

// NewSimulation returns a new simulation.
func NewSimulation(cfg Config) *Simulation {
	return &Simulation{
		Config:  cfg,
		Inputs:  make(chan Input, 64),
		Log:     make(chan LogMessage, 1024),
		Reactor: NewReactor(cfg),
	}
}

// Simulation is the entire state of a simulation.
type Simulation struct {
	Config

	// Command is the current command input.
	Command string
	// Alert is a notice, that can be dismissed.
	Alert string

	TimeSinceStart time.Duration
	Reactor        *Reactor

	Inputs chan Input
	Log    chan LogMessage
}

// Simulate implements simulatable.
func (s *Simulation) Simulate(quantum time.Duration) error {
	if err := s.Reactor.Simulate(quantum); err != nil {
		return err
	}

	// process the current inputs.
	inputs := len(s.Inputs)
	var err error
	var i Input
	for x := 0; x < inputs; x++ {
		i = <-s.Inputs

		// check if we entered a 127 => 127 like change ...
		if i.Done() {
			continue
		}

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

// Command Parsing

// ProcessCommand processes a command.
func (s *Simulation) ProcessCommand(rawCommand string) error {
	command, args := ParseCommand(rawCommand)
	switch command {
	case "q", "quit":
		{
			return ErrQuiting
		}
	case "alert":
		{
			s.Alert = strings.Join(args, " ")
			return nil
		}
	case "help", "?":
		{
			s.Info("help: help | ? : this message")
			s.Info("help: cr ([0-9],*) [0-255] : set cr pos (* for all)")
			s.Info("help: pp [0-255] : primary pump throttle")
			s.Info("help: sp [0-255] : secondary pump throttle")
			s.Info("help: scripts : display a list of scripts")
			s.Info("help: <script name> : invoke a script")
		}
	case "scripts":
		for name, script := range s.Scripts {
			s.Infof("script: %s (%d commands)", name, len(script))
		}
		return nil
	case "cr":
		{
			if len(args) < 2 {
				return errors.New("invalid `cr` args; must provide index and amount (0-255)")
			}

			// handle if we're doing all rods
			if args[0] == "*" {
				parsedValue, err := ParseValue(ValidUint8, args[1])
				if err != nil {
					return err
				}
				for index, cr := range s.Reactor.ControlRods {
					label := fmt.Sprintf("control rod %d", index)
					desired := PositionFromControl(uint8(parsedValue))
					input := NewPositionChange(label, &cr.Position, desired, s.ControlRodAdjustmentOrDefault())
					s.Inputs <- input
					s.Message(input)
				}
				return nil
			}

			parsedValues, err := ParseValues(ValidUint8, args...)
			if err != nil {
				return err
			}
			if len(parsedValues) < 2 {
				return errors.New("invalid `cr` args; must provide an index (0-n) and ammount (0-255)")
			}

			label := fmt.Sprintf("control rod %d", parsedValues[0])
			current := &s.Reactor.ControlRods[parsedValues[0]].Position
			desired := PositionFromControl(uint8(parsedValues[1]))

			input := NewPositionChange(label, current, desired, s.ControlRodAdjustmentOrDefault())
			s.Message(input)
			s.Inputs <- input
		}
	case "pp":
		{
			if len(args) < 1 {
				return fmt.Errorf("invalid `p` args; must provide amount (0-255)")
			}
			parsed, err := ParseValue(ValidUint8, args[0])
			if err != nil {
				return err
			}
			label := "primary pump throttle"
			current := &s.Reactor.Primary.Throttle
			desired := PositionFromControl(uint8(parsed))
			input := NewPositionChange(label, current, desired, s.PumpThrottleAdjustmentOrDefault())

			s.Message(input)
			s.Inputs <- input
		}
	case "sp":
		{
			if len(args) < 1 {
				return fmt.Errorf("invalid `sp` args; must provide amount (0-255)")
			}
			parsed, err := ParseValue(ValidUint8, args[0])
			if err != nil {
				return err
			}
			label := "secondary pump throttle"
			current := &s.Reactor.Secondary.Throttle
			desired := PositionFromControl(uint8(parsed))

			input := NewPositionChange(label, current, desired, s.PumpThrottleAdjustmentOrDefault())
			s.Message(input)
			s.Inputs <- input
		}
	default:
		{
			// try the command as a script:
			if script, ok := s.Scripts[command]; ok {
				s.Messagef("executing script: %s", command)
				for _, line := range script {
					if err := s.ProcessCommand(line); err != nil {
						return err
					}
				}
				return nil
			}
			s.Messagef("invalid command: %s", s.Command)
		}
	}

	return nil
}

//
// Log message helpers
//

// Infof writes a message to the log without a timestamp based on a format.
func (s *Simulation) Infof(format string, args ...interface{}) {
	s.Info(fmt.Sprintf(format, args...))
}

// Info writes a message to the log without a timestamp.
func (s *Simulation) Info(args ...interface{}) {
	s.Log <- LogMessage{
		Text: fmt.Sprint(args...),
	}
}

// Messagef logs a message with a given format and arguments.
func (s *Simulation) Messagef(format string, args ...interface{}) {
	s.Message(fmt.Sprintf(format, args...))
}

// Message logs a message with a given text value.
func (s *Simulation) Message(args ...interface{}) {
	s.Log <- LogMessage{
		Timestamp: time.Now(),
		Text:      fmt.Sprint(args...),
	}
}
