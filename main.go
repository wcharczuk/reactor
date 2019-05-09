package main

import (
	"errors"
	"fmt"
	"math"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/blend/go-sdk/async"
	"github.com/blend/go-sdk/logger"

	ui "github.com/gizak/termui"
	"github.com/wcharczuk/reactor/pkg/reactor"
)

func main() {
	err := ui.Init()
	if err != nil {
		logger.FatalExit(err)
	}
	defer func() {
		ui.Close()
		if err != nil {
			fmt.Fprintf(os.Stderr, "%v\n", err)
		}
	}()

	s := reactor.NewSimulation()

	err = async.RunToError(
		HandleInputs(s),
		RenderLoop(s),
		Simulation(s),
	)
}

// TickInterval
const (
	TickInterval               = 500 * time.Millisecond
	ErrQuiting   reactor.Error = "quitting"
)

// Simulation runs the actual simulation.
func Simulation(s *reactor.Simulation) func() error {
	return func() (err error) {
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("%v", r)
				return
			}
		}()
		s.Message("reactor idle")

		for {
			s.Simulate(TickInterval)
			time.Sleep(TickInterval)
		}
	}
}

// HandleInputs handles inputs.
func HandleInputs(s *reactor.Simulation) func() error {
	return func() error {
		uiEvents := ui.PollEvents()
		var e ui.Event
		var err error
		for {
			select {
			case e = <-uiEvents:
				if err = HandleInput(s, e); err != nil {
					return err
				}
			}

		}
	}
}

// HandleInput handles a ui event and catches panics.
func HandleInput(s *reactor.Simulation, e ui.Event) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("%v", r)
		}
	}()

	var processErr error
	switch e.ID {
	case "<C-c>":
		return ErrQuiting
	case "<Enter>":
		if processErr = ProcessCommand(s); processErr != nil {
			if processErr == ErrQuiting {
				err = processErr
				return
			}
			s.Message(processErr.Error())
		}
		s.Command = ""
	case "<C-l>":
		s.Command = ""
	case "C-8>": // handle backspace
		s.Command = strings.TrimRightFunc(s.Command, FirstRune())
	default:
		s.Command = s.Command + EscapeInput(e.ID)
	}
	return
}

// RenderLoop renders controls and advances the simulation.
func RenderLoop(s *reactor.Simulation) func() error {
	totalWidth := 160
	return func() (err error) {
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("%v", r)
				return
			}
		}()

		var controls []ui.Bufferer

		header := ui.NewParagraph("Reactor")
		header.Width = 9
		header.Height = 3
		header.X = 0
		header.Y = 0
		controls = append(controls, header)

		messageList := ui.NewParagraph("")
		messageList.BorderLabel = "Messages"
		messageList.Width = 52
		messageList.Height = 19
		messageList.X = totalWidth - (messageList.Width + 1)
		messageList.Y = 0
		controls = append(controls, messageList)

		command := ui.NewParagraph("> " + s.Command)
		command.Width = totalWidth - (messageList.Width + header.Width + 1)
		command.Height = 3
		command.X = 9
		command.Y = 0
		controls = append(controls, command)

		var controlRods []*ui.Gauge
		guageTop := header.Height
		for index := range s.Reactor.ControlRods {
			gauge := ui.NewGauge()
			gauge.Width = 50
			gauge.Height = 3
			gauge.X = 0
			gauge.Y = guageTop
			gauge.BorderLabel = fmt.Sprintf("Control Rod %d", index)
			controls = append(controls, gauge)
			controlRods = append(controlRods, gauge)
			guageTop = guageTop + gauge.Height
		}

		alarm := ui.NewParagraph("")
		alarm.BorderLabel = "Alarm"
		alarm.Width = 8
		alarm.Height = 3
		alarm.X = 50
		alarm.Y = header.Height
		controls = append(controls, alarm)

		output := ui.NewParagraph("")
		output.Width = 12
		output.Height = 3
		output.X = 50 + alarm.Width
		output.Y = header.Height
		output.BorderLabel = "Output"
		controls = append(controls, output)

		coreTemp := ui.NewParagraph("")
		coreTemp.Width = 12
		coreTemp.Height = 3
		coreTemp.X = 50
		coreTemp.Y = header.Height + alarm.Height
		coreTemp.BorderLabel = "Core Temp"
		controls = append(controls, coreTemp)

		outerTemp := ui.NewParagraph("")
		outerTemp.Width = 13
		outerTemp.Height = 3
		outerTemp.X = 50 + coreTemp.Width
		outerTemp.Y = header.Height + alarm.Height
		outerTemp.BorderLabel = "Outer Temp"
		controls = append(controls, outerTemp)

		turbineSpeed := ui.NewParagraph("")
		turbineSpeed.Width = 15
		turbineSpeed.Height = 3
		turbineSpeed.X = 50 + coreTemp.Width + outerTemp.Width
		turbineSpeed.Y = header.Height + alarm.Height
		turbineSpeed.BorderLabel = "Turbine RPM"
		controls = append(controls, turbineSpeed)

		primaryPump := ui.NewGauge()
		primaryPump.BorderLabel = "Primary Pump"
		primaryPump.Width = 50
		primaryPump.Height = 3
		primaryPump.X = 0
		primaryPump.Y = guageTop
		guageTop = guageTop + primaryPump.Height
		controls = append(controls, primaryPump)

		secondaryPump := ui.NewGauge()
		secondaryPump.BorderLabel = "Secondary Pump"
		secondaryPump.Width = 50
		secondaryPump.Height = 3
		secondaryPump.X = 0
		secondaryPump.Y = guageTop
		controls = append(controls, secondaryPump)

		for {
			if s.Reactor.Alarm {
				alarm.TextBgColor = ui.ColorRed
			}
			output.Text = fmt.Sprintf("%2.fkw/hr", s.Reactor.Turbine.Output())
			coreTemp.Text = fmt.Sprintf("%2.fk", s.Reactor.CoreTemperatureKelvin)
			outerTemp.Text = fmt.Sprintf("%2.fk", s.Reactor.ContainmentTemperatureKelvin)
			turbineSpeed.Text = fmt.Sprintf("%2.frpm", s.Reactor.Turbine.SpeedRPM)

			command.Text = "> " + s.Command
			if messageCount := len(s.Messages); messageCount > 0 {
				var m reactor.Message
				for x := 0; x < messageCount; x++ {
					m = <-s.Messages
					messageList.Text = m.String() + "\n" + messageList.Text
				}
			}

			for index, controlRod := range s.Reactor.ControlRods {
				controlRods[index].Percent = int(controlRod.Position.Percent())
			}

			primaryPump.Percent = int(s.Reactor.Primary.Throttle.Percent())
			secondaryPump.Percent = int(s.Reactor.Secondary.Throttle.Percent())

			ui.Render(controls...)

			time.Sleep(50 * time.Millisecond)
		}
	}
}

// ProcessCommand processes a command.
func ProcessCommand(s *reactor.Simulation) error {
	command, args := ParseCommand(s.Command)
	switch command {
	case "q", "quit":
		{
			return ErrQuiting
		}
	case "scram":
		s.Message("initiated SCRAM of reactor")
		s.Message("fully extending all control rods")
		for index, cr := range s.Reactor.ControlRods {
			s.Inputs <- reactor.NewPositionChange(fmt.Sprintf("control rod %d", index), &cr.Position, reactor.PositionMax, 5*time.Second)
		}
		s.Message("scramn; primary pump throttle to full")
		s.Inputs <- reactor.NewPositionChange("primary pump throttle", &s.Reactor.Primary.Throttle, reactor.PositionMax, 100*time.Millisecond)
		s.Message("scramn; secondary pump throttle to full")
		s.Inputs <- reactor.NewPositionChange("secondary pump throttle", &s.Reactor.Secondary.Throttle, reactor.PositionMax, 100*time.Millisecond)
	case "cr":
		{
			if len(args) < 2 {
				return errors.New("invalid `cr` args; must provide index and amount (0-255)")
			}
			parsedValues, err := ParseValues(ValidUint8, args...)
			if err != nil {
				return err
			}
			if len(parsedValues) < 2 {
				return errors.New("invalid `cr` args; must provide an index (0-n) and ammount (0-255)")
			}

			input := reactor.NewPositionChange(fmt.Sprintf("control rod %d", parsedValues[0]), &s.Reactor.ControlRods[parsedValues[0]].Position, reactor.Position(parsedValues[1]), 5*time.Second)
			s.Message(input)
			s.Inputs <- input
		}
	case "p":
		{
			if len(args) < 1 {
				return fmt.Errorf("invalid `p` args; must provide amount (0-255)")
			}
			parsed, err := ParseValue(ValidUint8, args...)
			if err != nil {
				return err
			}
			input := reactor.NewPositionChange("primary pump throttle", &s.Reactor.Primary.Throttle, reactor.Position(parsed), 100*time.Millisecond)
			s.Message(input)
			s.Inputs <- input
		}
	default:
		{
			s.Messagef("invalid command: %s", s.Command)
		}
	}

	return nil
}

//
// utility functions
//

// ParseValue parses string as an int, and applies a given validator.
func ParseValue(validator func(int) error, values ...string) (int, error) {
	if len(values) == 0 {
		return 0, errors.New("validation error: no values provided")
	}
	parsed, err := strconv.Atoi(values[0])
	if err != nil {
		return 0, err
	}

	if validator != nil {
		if err := validator(parsed); err != nil {
			return 0, err
		}
	}
	return parsed, nil
}

// ParseValues parses a list of strings as ints, and applies a given validator.
func ParseValues(validator func(int) error, values ...string) ([]int, error) {
	output := make([]int, len(values))
	for index, value := range values {
		parsed, err := strconv.Atoi(value)
		if err != nil {
			return nil, err
		}

		if validator != nil {
			if err := validator(parsed); err != nil {
				return nil, err
			}
		}
		output[index] = parsed
	}
	return output, nil
}

// ParseCommand splits a raw command into a command and arguments.
func ParseCommand(rawCommand string) (command string, args []string) {
	parts := strings.Split(rawCommand, " ")
	if len(parts) > 0 {
		command = parts[0]
	} else {
		command = rawCommand
	}

	if len(parts) > 1 {
		args = parts[1:]
	}
	return
}

// Between returns if a value is between the given min and max.
func Between(min, max int) func(int) error {
	return func(v int) error {
		if v < min || v > max {
			return fmt.Errorf("validation error: %d is not between %d and %d", v, min, max)
		}
		return nil
	}
}

// Below returns if a value is below a given maximum.
func Below(max int) func(int) error {
	return func(v int) error {
		if v >= max {
			return fmt.Errorf("validation error: %d is not below %d", v, max)
		}
		return nil
	}
}

// ValidUint8 returns a validator for uint8s.
func ValidUint8(v int) error {
	return Between(0, int(math.MaxUint8))(v)
}

// FirstRune returns the first rune should be trimmed, otherwise false.
func FirstRune() func(r rune) bool {
	var done bool
	return func(r rune) bool {
		if !done {
			done = true
			return true
		}
		return false
	}
}

// EscapeInput escapes the input.
func EscapeInput(value string) string {
	switch value {
	case "<Space>":
		return " "
	case "<Enter>", "<MouseLeft>", "<MouseRight>", "<MouseRelease>":
		return ""
	default:
		return value
	}
}
