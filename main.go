package main

import (
	"flag"
	"fmt"
	"image"
	"os"
	"strings"
	"time"

	"github.com/blend/go-sdk/async"
	"github.com/blend/go-sdk/configutil"
	"github.com/blend/go-sdk/logger"
	ui "github.com/gizak/termui/v3"
	"github.com/gizak/termui/v3/widgets"
	"github.com/wcharczuk/reactor/pkg/reactor"
)

var (
	flagConfigPath = flag.String("config", "config.yml", "The simulation config file path (optional)")
)

func main() {
	flag.Parse()

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

	cfg := reactor.DefaultConfig
	if _, err := configutil.Read(&cfg, configutil.OptAddPreferredPaths(*flagConfigPath)); !configutil.IsIgnored(err) {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return
	}

	s := reactor.NewSimulation(reactor.DefaultConfig)

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
	alertWidth := 100
	gaugeWidth := 50
	controlRodTempWidth := 15
	messageListWidth := 60

	middleWidth := totalWidth - (gaugeWidth + controlRodTempWidth + messageListWidth)
	middleWidth2 := middleWidth >> 1

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
		messageList.Title = "Log"
		messageList.SetRect(r(totalWidth-messageListWidth, 0, messageListWidth, 24))
		controls = append(controls, messageList)

		command := widgets.NewParagraph()
		command.Text = "> " + s.Command
		command.SetRect(r(9, 0, totalWidth-(w(messageList)+w(header)), 3))
		controls = append(controls, command)

		var controlRods []*widgets.Gauge
		var controlRodTemps []*widgets.Paragraph
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
		output.SetRect(r(gaugeWidth+controlRodTempWidth, h(header), middleWidth, 3))
		controls = append(controls, output)

		turbineInletTemp := widgets.NewParagraph()
		turbineInletTemp.Title = "Turb. Temp"
		turbineInletTemp.SetRect(r(gaugeWidth+controlRodTempWidth, h(header)+h(output), middleWidth2, 3))
		controls = append(controls, turbineInletTemp)

		turbineSpeed := widgets.NewParagraph()
		turbineSpeed.Title = "Turbine RPM"
		turbineSpeed.SetRect(r(gaugeWidth+controlRodTempWidth+w(turbineInletTemp), h(header)+h(output), middleWidth2+1, 3))
		controls = append(controls, turbineSpeed)

		coreTemp := widgets.NewParagraph()
		coreTemp.Title = "Core Temp"
		coreTemp.SetRect(r(gaugeWidth+controlRodTempWidth, h(header)+h(output)+h(turbineInletTemp), middleWidth2, 3))
		controls = append(controls, coreTemp)

		containmentTemp := widgets.NewParagraph()
		containmentTemp.Title = "Cont. Temp"
		containmentTemp.SetRect(r(gaugeWidth+controlRodTempWidth+w(coreTemp), h(header)+h(output)+h(turbineInletTemp), middleWidth2+1, 3))
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

		var activeControls []ui.Drawable
		for {
			activeControls = controls[:]
			if len(s.Alert) > 0 {
				alert := widgets.NewParagraph()

				alert.Title = "Alert"
				alert.Text = s.Alert
				alert.BorderStyle.Fg = ui.ColorRed

				left := (totalWidth / 2.0) - (alertWidth / 2.0)
				top := 3

				alert.SetRect(r(left, top, alertWidth, 3))
				activeControls = append(activeControls, alert)
			}

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
			if messageCount := len(s.Log); messageCount > 0 {
				var m reactor.LogMessage
				for x := 0; x < messageCount; x++ {
					m = <-s.Log
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

			ui.Render(activeControls...)

			time.Sleep(50 * time.Millisecond)
		}
	}
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

	// if we're showing an alert ...
	if len(s.Alert) > 0 {
		switch e.ID {
		case "<C-c>":
			err = reactor.ErrQuiting
			return
		case "<Enter>", "<Escape>":
			s.Alert = ""
			ui.Clear()
			return
		default:
			return
		}
	}

	// process command as normal ...
	switch e.ID {
	case "<C-c>":
		err = reactor.ErrQuiting
		return
	case "<Enter>":
		if processErr := s.ProcessCommand(s.Command); processErr != nil {
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
		s.Command = strings.TrimRightFunc(s.Command, firstRune())
	default:
		s.Command = s.Command + escapeInput(e.ID)
	}
	return
}

//
// input helpers
//

// firstRune returns the first rune should be trimmed, otherwise false.
func firstRune() func(r rune) bool {
	var done bool
	return func(r rune) bool {
		if !done {
			done = true
			return true
		}
		return false
	}
}

// escapeInput escapes the input.
func escapeInput(value string) string {
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

func show(control *widgets.Paragraph) {

	//
}

func hide(control ui.Drawable) {
	//
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
