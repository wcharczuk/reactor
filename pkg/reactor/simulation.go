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
		Notices: make(chan Notice, 32),
		Reactor: NewReactor(cfg),
	}
}

// Simulation is the entire state of a simulation.
type Simulation struct {
	Config

	TimeSinceStart time.Duration
	Reactor        *Reactor

	Notices chan Notice
	Inputs  chan Input
	Log     chan LogMessage
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

	alarms := s.Reactor.Alarms()
	for _, alarm := range alarms {
		if alarm.New() {
			s.Message(alarm.String())
			if alarm.Severity() > SeverityCritical {
				s.Notices <- NewNotice(alarm.Severity(), "Alarm", alarm.String())
			}
			alarm.Seen()
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
			s.Messagef("alarm: %s", strings.Join(args, " "))
			s.Notices <- NewNotice(SeverityFatal, "Alert", strings.Join(args, " "))
		}
	case "notice":
		{
			s.Messagef("notice: %s", strings.Join(args, " "))
			s.Notices <- NewNotice(SeverityInfo, "Notice", strings.Join(args, " "))
		}
	case "message":
		{
			s.Message(strings.Join(args, " "))
		}
	case "help", "?":
		{
			lines := []string{
				"command list:",
				"> help | ? : this message",
				"> cr ([0-9],*) [0-255] (duration?) : set control rod position (by index, or * for all)",
				"> p [0-255] (duration?) : primary pump throttle",
				"> notice <args>: display a notice",
				"> alert <args>: display an alert",
				"> message <args>: log a message",
				"> scripts : display a list of scripts",
				"> script <script name> : display the contents of a script",
				"> <script name> : invoke a script",
			}
			s.Notices <- NewNotice(SeverityInfo, "Help", lines...)
		}
	case "scripts":
		var lines []string
		for name, script := range s.Scripts {
			lines = append(lines, fmt.Sprintf("%s (%d commands)", name, len(script)))
		}
		s.Notices <- NewNotice(SeverityInfo, "Scripts", lines...)
	case "script":
		if len(args) < 1 {
			return errors.New("invalid `script` call; must provide a script name")
		}
		if script, ok := s.Config.Scripts[args[0]]; ok {
			s.Notices <- NewNotice(SeverityInfo, "script: "+args[0], script...)
			return nil
		}
		return fmt.Errorf("script not found; %s", args[0])
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
	case "p":
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
			s.Messagef("invalid command: %s", rawCommand)
		}
	}

	return nil
}

// ClearNotices clears the notice list.
func (s *Simulation) ClearNotices() {
	noticeCount := len(s.Notices)
	for x := 0; x < noticeCount; x++ {
		<-s.Notices
	}
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
