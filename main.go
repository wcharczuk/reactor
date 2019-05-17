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
			s.Simulate(reactor.DefaultTickInterval)
			time.Sleep(reactor.DefaultTickInterval)
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
		return reactor.ErrQuiting
	case "<Enter>":
		if processErr = ProcessCommand(s); processErr != nil {
			if processErr == reactor.ErrQuiting {
				err = processErr
				return
			}
			s.Message(processErr.Error())
		}
		s.Command = ""
	case "<C-l>", "<Escape>":
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

		messageListWidth := 60
		messageList := widgets.NewParagraph()
		messageList.Title = "Log"
		messageList.SetRect(r(totalWidth-messageListWidth, 0, messageListWidth, 24))
		controls = append(controls, messageList)

		command := widgets.NewParagraph()
		command.Text = "> " + s.Command
		command.SetRect(r(9, 0, totalWidth-(w(messageList)+w(header)), 3))
		controls = append(controls, command)

		var controlRods []*widgets.Gauge
		var controlRodTemps []*widgets.Paragraph
		gaugeWidth := 50
		controlRodTempWidth := 17
		gaugeTop := h(header)
		for index := range s.Reactor.ControlRods {
			gauge := widgets.NewGauge()
			gauge.SetRect(r(0, gaugeTop, gaugeWidth, 3))
			gauge.Title = fmt.Sprintf("Control Rod %d", index)
			controls = append(controls, gauge)
			controlRods = append(controlRods, gauge)

			gaugeTemp := widgets.NewParagraph()
			gaugeTemp.Title = fmt.Sprintf("C. Rod %d Temp", index)
			gaugeTemp.SetRect(r(gaugeWidth, gaugeTop, controlRodTempWidth, 3))
			controls = append(controls, gaugeTemp)
			controlRodTemps = append(controlRodTemps, gaugeTemp)

			gaugeTop = gaugeTop + h(gauge)
		}

		alarm := widgets.NewParagraph()
		alarm.Title = "Alarm"
		alarm.SetRect(r(gaugeWidth+controlRodTempWidth, h(header), 9, 3))
		controls = append(controls, alarm)

		turbineSpeed := widgets.NewParagraph()
		turbineSpeed.Title = "Turbine RPM"
		turbineSpeed.SetRect(r(gaugeWidth+controlRodTempWidth, h(header)+h(alarm), 15, 3))
		controls = append(controls, turbineSpeed)

		output := widgets.NewParagraph()
		output.Title = "Output"
		output.SetRect(r(gaugeWidth+controlRodTempWidth+w(turbineSpeed), h(header)+h(alarm), 15, 3))
		controls = append(controls, output)

		coreTemp := widgets.NewParagraph()
		coreTemp.Title = "Core Temp"
		coreTemp.SetRect(r(gaugeWidth+controlRodTempWidth, h(header)+h(alarm)+h(output), 15, 3))
		controls = append(controls, coreTemp)

		containmentTemp := widgets.NewParagraph()
		containmentTemp.Title = "Cont. Temp"
		containmentTemp.SetRect(r(gaugeWidth+controlRodTempWidth+w(coreTemp), h(header)+h(alarm)+h(output), 15, 3))
		controls = append(controls, containmentTemp)

		primaryPump := widgets.NewGauge()
		primaryPump.Title = "Primary Pump"
		primaryPump.SetRect(r(0, gaugeTop, 50, 3))
		controls = append(controls, primaryPump)

		primaryInletTemp := widgets.NewParagraph()
		primaryInletTemp.Title = "Pr. In Temp"
		primaryInletTemp.SetRect(r(gaugeWidth, gaugeTop, 17, 3))
		controls = append(controls, primaryInletTemp)

		primaryOutletTemp := widgets.NewParagraph()
		primaryOutletTemp.Title = "Pr. Out Temp"
		primaryOutletTemp.SetRect(r(gaugeWidth+w(primaryInletTemp), gaugeTop, 17, 3))
		controls = append(controls, primaryOutletTemp)

		gaugeTop = gaugeTop + h(primaryPump)

		secondaryPump := widgets.NewGauge()
		secondaryPump.Title = "Secondary Pump"
		secondaryPump.SetRect(r(0, gaugeTop, 50, 3))
		controls = append(controls, secondaryPump)

		secondaryInletTemp := widgets.NewParagraph()
		secondaryInletTemp.Title = "Sec. In Temp"
		secondaryInletTemp.SetRect(r(50, gaugeTop, 17, 3))
		controls = append(controls, secondaryInletTemp)

		secondaryOutletTemp := widgets.NewParagraph()
		secondaryOutletTemp.Title = "Sec. Out Temp"
		secondaryOutletTemp.SetRect(r(50+w(secondaryInletTemp), gaugeTop, 17, 3))
		controls = append(controls, secondaryOutletTemp)

		for {
			if s.Reactor.Alarm {
				alarm.TextStyle.Bg = ui.ColorRed
			}
			output.Text = FormatOutput(s.Reactor.Turbine.Output())
			coreTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.CoreTemperature)
			containmentTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.ContainmentTemperature)
			turbineSpeed.Text = fmt.Sprintf("%.2frpm", s.Reactor.Turbine.SpeedRPM)
			primaryInletTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.Primary.InletTemperature)
			primaryOutletTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.Primary.OutletTemperature)
			secondaryInletTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.Secondary.InletTemperature)
			secondaryOutletTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.Secondary.OutletTemperature)

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
				controlRodTemps[index].Text = fmt.Sprintf("%.2fc", controlRod.Temperature)
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
			return reactor.ErrQuiting
		}
	case "scram":
		s.Message("initiated SCRAM of reactor")
		s.Message("scram; extending all control rods")
		for index, cr := range s.Reactor.ControlRods {
			s.Inputs <- reactor.NewPositionChange(fmt.Sprintf("control rod %d", index), &cr.Position, reactor.PositionMax, 10*time.Second)
		}
		s.Message("scram; primary pump throttle to full")
		s.Inputs <- reactor.NewPositionChange("primary pump throttle", &s.Reactor.Primary.Throttle, reactor.PositionMax, 5*time.Second)
		s.Message("scram; secondary pump throttle to full")
		s.Inputs <- reactor.NewPositionChange("secondary pump throttle", &s.Reactor.Secondary.Throttle, reactor.PositionMax, 5*time.Second)
	case "run":
		s.Message("setting baseline config")
		s.Message("baseline; retracting all control rods")
		for index, cr := range s.Reactor.ControlRods {
			s.Inputs <- reactor.NewPositionChange(fmt.Sprintf("control rod %d", index), &cr.Position, 0.25, 10*time.Second)
		}
		s.Message("baseline; primary pump throttle to full")
		s.Inputs <- reactor.NewPositionChange("primary pump throttle", &s.Reactor.Primary.Throttle, reactor.PositionMax, 5*time.Second)
		s.Message("baseline; secondary pump throttle to full")
		s.Inputs <- reactor.NewPositionChange("secondary pump throttle", &s.Reactor.Secondary.Throttle, reactor.PositionMax, 5*time.Second)
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

			label := fmt.Sprintf("control rod %d", parsedValues[0])
			current := &s.Reactor.ControlRods[parsedValues[0]].Position
			desired := reactor.PositionFromControl(uint8(parsedValues[1]))

			input := reactor.NewPositionChange(label, current, desired, 10*time.Second)
			s.Message(input)
			s.Inputs <- input
		}
	case "pp":
		{
			if len(args) < 1 {
				return fmt.Errorf("invalid `p` args; must provide amount (0-255)")
			}
			parsed, err := ParseValue(ValidUint8, args...)
			if err != nil {
				return err
			}
			label := "primary pump throttle"
			current := &s.Reactor.Primary.Throttle
			desired := reactor.PositionFromControl(uint8(parsed))
			input := reactor.NewPositionChange(label, current, desired, 5*time.Second)

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
			label := "secondary pump throttle"
			current := &s.Reactor.Secondary.Throttle
			desired := reactor.PositionFromControl(uint8(parsed))

			input := reactor.NewPositionChange(label, current, desired, 5*time.Second)
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

// FormatOutput formats the output.
func FormatOutput(output float64) string {
	if output > 1000*1000 {
		return fmt.Sprintf("%.2fgw/hr", output/(1000*1000))
	}
	if output > 1000 {
		return fmt.Sprintf("%.2fmw/hr", output/1000)
	}
	return fmt.Sprintf("%.2fkw/hr", output)
}

//
// control rect helpers
//

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
