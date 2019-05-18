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
	ui "github.com/gizak/termui/v3"
	"github.com/gizak/termui/v3/widgets"
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
		controlRodTempWidth := 15
		gaugeTop := h(header)
		for index := range s.Reactor.ControlRods {
			gauge := widgets.NewGauge()
			gauge.SetRect(r(0, gaugeTop, gaugeWidth, 3))
			gauge.Title = fmt.Sprintf("Control Rod %d", index)
			controls = append(controls, gauge)
			controlRods = append(controlRods, gauge)

			gaugeTemp := widgets.NewParagraph()
			gaugeTemp.Title = fmt.Sprintf("CR %d Temp", index)
			gaugeTemp.SetRect(r(gaugeWidth, gaugeTop, controlRodTempWidth, 3))
			controls = append(controls, gaugeTemp)
			controlRodTemps = append(controlRodTemps, gaugeTemp)

			gaugeTop = gaugeTop + h(gauge)
		}

		output := widgets.NewParagraph()
		output.Title = "Output"
		output.SetRect(r(gaugeWidth+controlRodTempWidth, h(header), 15, 3))
		controls = append(controls, output)

		turbineInletTemp := widgets.NewParagraph()
		turbineInletTemp.Title = "Turb. Temp"
		turbineInletTemp.SetRect(r(gaugeWidth+controlRodTempWidth, h(header)+h(output), 15, 3))
		controls = append(controls, turbineInletTemp)

		turbineSpeed := widgets.NewParagraph()
		turbineSpeed.Title = "Turbine RPM"
		turbineSpeed.SetRect(r(gaugeWidth+controlRodTempWidth+w(turbineInletTemp), h(header)+h(output), 15, 3))
		controls = append(controls, turbineSpeed)

		coreTemp := widgets.NewParagraph()
		coreTemp.Title = "Core Temp"
		coreTemp.SetRect(r(gaugeWidth+controlRodTempWidth, h(header)+h(output)+h(turbineInletTemp), 15, 3))
		controls = append(controls, coreTemp)

		containmentTemp := widgets.NewParagraph()
		containmentTemp.Title = "Cont. Temp"
		containmentTemp.SetRect(r(gaugeWidth+controlRodTempWidth+w(coreTemp), h(header)+h(output)+h(turbineInletTemp), 15, 3))
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

			output.Text = reactor.FormatOutput(s.Reactor.Turbine.Output)

			coreTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.CoreTemp)
			coreTemp.TextStyle.Bg, coreTemp.TextStyle.Fg = severity(s.Reactor.CoreTempAlarm.Severity())

			containmentTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.ContainmentTemp)
			containmentTemp.TextStyle.Bg, containmentTemp.TextStyle.Fg = severity(s.Reactor.ContainmentTempAlarm.Severity())

			turbineInletTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.Turbine.InletTemp)

			turbineSpeed.Text = fmt.Sprintf("%.2frpm", s.Reactor.Turbine.SpeedRPM)
			turbineSpeed.TextStyle.Bg, turbineSpeed.TextStyle.Fg = severity(s.Reactor.Turbine.SpeedRPMAlarm.Severity())

			primaryInletTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.Primary.InletTemp)
			primaryInletTemp.TextStyle.Bg, primaryInletTemp.TextStyle.Fg = severity(s.Reactor.Primary.InletTempAlarm.Severity())

			primaryOutletTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.Primary.OutletTemp)
			primaryOutletTemp.TextStyle.Bg, primaryOutletTemp.TextStyle.Fg = severity(s.Reactor.Primary.OutletTempAlarm.Severity())

			secondaryInletTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.Secondary.InletTemp)
			secondaryInletTemp.TextStyle.Bg, secondaryInletTemp.TextStyle.Fg = severity(s.Reactor.Secondary.InletTempAlarm.Severity())

			secondaryOutletTemp.Text = fmt.Sprintf("%.2fc", s.Reactor.Secondary.OutletTemp)
			secondaryOutletTemp.TextStyle.Bg, secondaryOutletTemp.TextStyle.Fg = severity(s.Reactor.Secondary.OutletTempAlarm.Severity())

			command.Text = "> " + s.Command
			if messageCount := len(s.Messages); messageCount > 0 {
				var m reactor.Message
				for x := 0; x < messageCount; x++ {
					m = <-s.Messages
					messageList.Text = m.String() + "\n" + messageList.Text
				}
			}

			var gauge *widgets.Gauge
			var label *widgets.Paragraph
			for index, controlRod := range s.Reactor.ControlRods {
				gauge = controlRods[index]
				label = controlRodTemps[index]
				gauge.Percent = int(controlRod.Position.Percent())
				label.Text = fmt.Sprintf("%.2fc", controlRod.Temp)
				label.TextStyle.Bg, label.TextStyle.Fg = severity(controlRod.TempAlarm.Severity())
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
		{
			s.Message("initiated SCRAM of reactor")
			s.Message("scram; extending all control rods")
			for index, cr := range s.Reactor.ControlRods {
				s.Inputs <- reactor.NewPositionChange(fmt.Sprintf("control rod %d", index), &cr.Position, reactor.PositionMax, reactor.ControlRodAdjustmentRate)
			}
			s.Message("scram; primary pump throttle to full")
			s.Inputs <- reactor.NewPositionChange("primary pump throttle", &s.Reactor.Primary.Throttle, reactor.PositionMax, reactor.PumpThrottleAdjustmentRate)
			s.Message("scram; secondary pump throttle to full")
			s.Inputs <- reactor.NewPositionChange("secondary pump throttle", &s.Reactor.Secondary.Throttle, reactor.PositionMax, reactor.PumpThrottleAdjustmentRate)
		}
	case "run":
		{
			s.Message("setting baseline config")
			s.Message("baseline; retracting all control rods")
			for index, cr := range s.Reactor.ControlRods {
				s.Inputs <- reactor.NewPositionChange(fmt.Sprintf("control rod %d", index), &cr.Position, 0.16, reactor.ControlRodAdjustmentRate)
			}
			s.Message("baseline; primary pump throttle to full")
			s.Inputs <- reactor.NewPositionChange("primary pump throttle", &s.Reactor.Primary.Throttle, reactor.PositionMax, reactor.PumpThrottleAdjustmentRate)
			s.Message("baseline; secondary pump throttle to full")
			s.Inputs <- reactor.NewPositionChange("secondary pump throttle", &s.Reactor.Secondary.Throttle, reactor.PositionMax, reactor.PumpThrottleAdjustmentRate)
		}
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
					desired := reactor.PositionFromControl(uint8(parsedValue))
					input := reactor.NewPositionChange(label, &cr.Position, desired, reactor.ControlRodAdjustmentRate)
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
			desired := reactor.PositionFromControl(uint8(parsedValues[1]))

			input := reactor.NewPositionChange(label, current, desired, reactor.ControlRodAdjustmentRate)
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
			input := reactor.NewPositionChange(label, current, desired, reactor.PumpThrottleAdjustmentRate)

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

			input := reactor.NewPositionChange(label, current, desired, reactor.PumpThrottleAdjustmentRate)
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

func severity(severity string) (background, foreground ui.Color) {
	switch severity {
	case reactor.AlarmFatal:
		{
			background = ui.ColorRed
			foreground = ui.ColorWhite
			return
		}
	case reactor.AlarmCritical:
		{
			background = ui.ColorYellow
			foreground = ui.ColorWhite
			return
		}
	case reactor.AlarmWarning:
		{
			background = ui.ColorYellow
			foreground = ui.ColorWhite
			return
		}
	default:
		background = ui.ColorClear
		foreground = ui.ColorWhite
		return
	}
}
