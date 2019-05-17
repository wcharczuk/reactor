package main

import (
	"errors"
	"fmt"
	"image"
	"math"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/blend/go-sdk/async"
	"github.com/blend/go-sdk/logger"
	ui "github.com/gizak/termui"
	"github.com/gizak/termui/widgets"
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
	case "C-8>", "<Backspace>": // handle backspace
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

		var controls []ui.Drawable

		header := widgets.NewParagraph()
		header.Text = "Reactor"
		header.SetRect(r(0, 0, 9, 3))
		controls = append(controls, header)

		messageList := widgets.NewParagraph()
		messageList.Title = "Messages"
		messageList.SetRect(r(totalWidth-52, 0, 52, 19))
		controls = append(controls, messageList)

		command := widgets.NewParagraph()
		command.Text = "> " + s.Command
		command.SetRect(r(9, 0, totalWidth-(w(messageList)+w(header)), 3))
		controls = append(controls, command)

		var controlRods []*widgets.Gauge
		gaugeTop := h(header)
		for index := range s.Reactor.ControlRods {
			gauge := widgets.NewGauge()
			gauge.SetRect(r(0, gaugeTop, 50, 3))
			gauge.Title = fmt.Sprintf("Control Rod %d", index)
			controls = append(controls, gauge)
			controlRods = append(controlRods, gauge)
			gaugeTop = gaugeTop + h(gauge)
		}

		alarm := widgets.NewParagraph()
		alarm.Title = "Alarm"
		alarm.SetRect(r(50, h(header), 9, 3))
		controls = append(controls, alarm)

		output := widgets.NewParagraph()
		output.Title = "Output"
		output.SetRect(r(50+w(alarm), h(header), 12, 3))
		controls = append(controls, output)

		coreTemp := widgets.NewParagraph()
		coreTemp.Title = "Core Temp"
		coreTemp.SetRect(r(50, h(header)+h(alarm), 12, 3))
		controls = append(controls, coreTemp)

		outerTemp := widgets.NewParagraph()
		outerTemp.Title = "Outer Temp"
		outerTemp.SetRect(r(50+w(coreTemp), h(header)+h(alarm), 13, 3))
		controls = append(controls, outerTemp)

		turbineSpeed := widgets.NewParagraph()
		turbineSpeed.Title = "Turbine RPM"
		turbineSpeed.SetRect(r(50+w(coreTemp)+w(outerTemp), h(header)+h(alarm), 15, 3))
		controls = append(controls, turbineSpeed)

		primaryPump := widgets.NewGauge()
		primaryPump.Title = "Primary Pump"
		primaryPump.SetRect(r(0, gaugeTop, 50, 3))
		gaugeTop = gaugeTop + h(primaryPump)
		controls = append(controls, primaryPump)

		secondaryPump := widgets.NewGauge()
		secondaryPump.Title = "Secondary Pump"
		secondaryPump.SetRect(r(0, gaugeTop, 50, 3))
		controls = append(controls, secondaryPump)

		for {
			if s.Reactor.Alarm {
				alarm.TextStyle.Bg = ui.ColorRed
			}
			output.Text = fmt.Sprintf("%2.fkw/hr", s.Reactor.Turbine.Output())
			coreTemp.Text = fmt.Sprintf("%2.fc", s.Reactor.CoreTemperature)
			outerTemp.Text = fmt.Sprintf("%2.fc", s.Reactor.ContainmentTemperature)
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
		s.Message("scram; extending all control rods")
		for index, cr := range s.Reactor.ControlRods {
			s.Inputs <- reactor.NewPositionChange(fmt.Sprintf("control rod %d", index), &cr.Position, reactor.PositionMax, 5*time.Second)
		}
		s.Message("scram; primary pump throttle to full")
		s.Inputs <- reactor.NewPositionChange("primary pump throttle", &s.Reactor.Primary.Throttle, reactor.PositionMax, 100*time.Millisecond)
		s.Message("scram; secondary pump throttle to full")
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
	case "sp":
		{
			if len(args) < 1 {
				return fmt.Errorf("invalid `sp` args; must provide amount (0-255)")
			}
			parsed, err := ParseValue(ValidUint8, args...)
			if err != nil {
				return err
			}
			input := reactor.NewPositionChange("secondary pump throttle", &s.Reactor.Secondary.Throttle, reactor.Position(parsed), 100*time.Millisecond)
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
	case "<Enter>", "<MouseLeft>", "<MouseRight>", "<MouseRelease>", "<Resize>":
		return ""
	default:
		return value
	}
}

func r(x, y, width, height int) (x0, y0, x1, y1 int) {
	x0 = x
	y0 = y
	x1 = x + width
	y1 = y + height
	return
}

type rectProvider interface {
	GetRect() image.Rectangle
}

func w(c rectProvider) int {
	return c.GetRect().Dx()
}

func h(c rectProvider) int {
	return c.GetRect().Dy()
}
