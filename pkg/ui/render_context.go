package ui

import (
	"fmt"
	"strings"
	"time"

	"github.com/wcharczuk/reactor/pkg/reactor"
	termui "github.com/wcharczuk/termui"
	"github.com/wcharczuk/termui/widgets"
)

// RenderContext is everything needed to render the simulation.
type RenderContext struct {
	Command         string
	OutputHistory   []Sample
	Simulation      *reactor.Simulation
	Controls        []termui.Drawable
	ControlRods     []*widgets.Gauge
	ControlRodTemps []*widgets.Paragraph
	Notices         []*widgets.Paragraph
}

// AllControls returns a unified list of controls.
func (rc RenderContext) AllControls() (all []termui.Drawable) {
	for _, c := range rc.Controls {
		all = append(all, c)
	}
	for _, c := range rc.ControlRods {
		all = append(all, c)
	}
	for _, c := range rc.ControlRodTemps {
		all = append(all, c)
	}
	for _, c := range rc.Notices {
		all = append(all, c)
	}
	return
}

// Simulate runs the actual simulation.
func (rc *RenderContext) Simulate() func() error {
	return func() (err error) {
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("%v", r)
				return
			}
		}()
		rc.Simulation.Message("reactor idle")

		for {
			rc.Simulation.Simulate(rc.Simulation.TickIntervalOrDefault())
			time.Sleep(rc.Simulation.TickIntervalOrDefault())
		}
	}
}

// HandleInputs handles inputs.
func (rc *RenderContext) HandleInputs() func() error {
	return func() error {
		uiEvents := termui.PollEvents()
		var e termui.Event
		var err error
		for {
			select {
			case e = <-uiEvents:
				if err = rc.HandleInput(e); err != nil {
					return err
				}
			}

		}
	}
}

// HandleInput handles a ui event and catches panics.
func (rc *RenderContext) HandleInput(e termui.Event) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("%v", r)
		}
	}()

	// if we're showing an alert ...
	if len(rc.Notices) > 0 {
		switch e.ID {
		case "<C-c>":
			err = reactor.ErrQuiting
			return
		case "<Enter>", "<Escape>":
			rc.Notices = nil
			termui.Clear()
			return
		default:
			rc.Notices = nil
			termui.Clear()
			return
		}
	}

	// process command as normal ...
	switch e.ID {
	case "<C-c>":
		err = reactor.ErrQuiting
		return
	case "<Enter>":
		if len(rc.Command) == 0 {
			return nil
		}
		if processErr := rc.Simulation.ProcessCommand(rc.Command); processErr != nil {
			if processErr == reactor.ErrQuiting {
				err = processErr
				return
			}
			rc.Simulation.Message(processErr.Error())
		}
		rc.Command = ""
	case "<C-l>", "<Escape>":
		rc.Command = ""
	case "C-8>", "<Backspace>": // handle backspace
		rc.Command = strings.TrimRightFunc(rc.Command, firstRune())
	default:
		rc.Command = rc.Command + escapeInput(e.ID)
	}
	return
}

// Render renders controls and advances the simulation.
func (rc *RenderContext) Render() func() error {
	totalWidth := 160
	totalHeight := 24

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

		header := widgets.NewParagraph()
		header.Text = "Reactor"
		header.SetRect(r(0, 0, 9, 3))
		rc.Controls = append(rc.Controls, header)

		messageList := widgets.NewParagraph()
		messageList.Title = "Log"
		messageList.SetRect(r(totalWidth-messageListWidth, 0, messageListWidth, totalHeight))
		rc.Controls = append(rc.Controls, messageList)

		command := widgets.NewParagraph()
		command.Text = "> " + rc.Command
		command.SetRect(r(9, 0, totalWidth-(w(messageList)+w(header)), 3))
		rc.Controls = append(rc.Controls, command)

		gaugeTop := h(header)
		for index := range rc.Simulation.Reactor.ControlRods {
			gauge := widgets.NewGauge()
			gauge.SetRect(r(0, gaugeTop, gaugeWidth, 3))
			gauge.Title = fmt.Sprintf("Control Rod %d", index)
			rc.ControlRods = append(rc.ControlRods, gauge)

			gaugeTemp := widgets.NewParagraph()
			gaugeTemp.Title = fmt.Sprintf("CR %d Temp", index)
			gaugeTemp.SetRect(r(gaugeWidth, gaugeTop, controlRodTempWidth, 3))
			rc.ControlRodTemps = append(rc.ControlRodTemps, gaugeTemp)

			gaugeTop = gaugeTop + h(gauge)
		}

		output := widgets.NewParagraph()
		output.Title = "Output"
		output.SetRect(r(gaugeWidth+controlRodTempWidth, h(header), middleWidth, 3))
		rc.Controls = append(rc.Controls, output)

		turbineInletTemp := widgets.NewParagraph()
		turbineInletTemp.Title = "Turb. Temp"
		turbineInletTemp.SetRect(r(gaugeWidth+controlRodTempWidth, h(header)+h(output), middleWidth2, 3))
		rc.Controls = append(rc.Controls, turbineInletTemp)

		turbineSpeed := widgets.NewParagraph()
		turbineSpeed.Title = "Turbine RPM"
		turbineSpeed.SetRect(r(gaugeWidth+controlRodTempWidth+w(turbineInletTemp), h(header)+h(output), middleWidth2+1, 3))
		rc.Controls = append(rc.Controls, turbineSpeed)

		coreTemp := widgets.NewParagraph()
		coreTemp.Title = "Core Temp"
		coreTemp.SetRect(r(gaugeWidth+controlRodTempWidth, h(header)+h(output)+h(turbineInletTemp), middleWidth2, 3))
		rc.Controls = append(rc.Controls, coreTemp)

		containmentTemp := widgets.NewParagraph()
		containmentTemp.Title = "Cont. Temp"
		containmentTemp.SetRect(r(gaugeWidth+controlRodTempWidth+w(coreTemp), h(header)+h(output)+h(turbineInletTemp), middleWidth2+1, 3))
		rc.Controls = append(rc.Controls, containmentTemp)

		primaryPump := widgets.NewGauge()
		primaryPump.Title = "Primary Pump"
		primaryPump.SetRect(r(0, gaugeTop, 50, 3))
		rc.Controls = append(rc.Controls, primaryPump)

		primaryInletTemp := widgets.NewParagraph()
		primaryInletTemp.Title = "Pr. In Temp"
		primaryInletTemp.SetRect(r(gaugeWidth, gaugeTop, 17, 3))
		rc.Controls = append(rc.Controls, primaryInletTemp)

		primaryOutletTemp := widgets.NewParagraph()
		primaryOutletTemp.Title = "Pr. Out Temp"
		primaryOutletTemp.SetRect(r(gaugeWidth+w(primaryInletTemp), gaugeTop, 17, 3))
		rc.Controls = append(rc.Controls, primaryOutletTemp)

		gaugeTop = gaugeTop + h(primaryPump)

		secondaryPump := widgets.NewGauge()
		secondaryPump.Title = "Secondary Pump"
		secondaryPump.SetRect(r(0, gaugeTop, 50, 3))
		rc.Controls = append(rc.Controls, secondaryPump)

		secondaryInletTemp := widgets.NewParagraph()
		secondaryInletTemp.Title = "Sec. In Temp"
		secondaryInletTemp.SetRect(r(50, gaugeTop, 17, 3))
		rc.Controls = append(rc.Controls, secondaryInletTemp)

		secondaryOutletTemp := widgets.NewParagraph()
		secondaryOutletTemp.Title = "Sec. Out Temp"
		secondaryOutletTemp.SetRect(r(50+w(secondaryInletTemp), gaugeTop, 17, 3))
		rc.Controls = append(rc.Controls, secondaryOutletTemp)

		for {
			noticeTop := 0
			noticeCount := len(rc.Simulation.Notices)
			for _, noticeBox := range rc.Notices {
				noticeTop += h(noticeBox)
			}

			for x := 0; x < noticeCount; x++ {
				notice := <-rc.Simulation.Notices

				noticeBox := widgets.NewParagraph()
				noticeBox.Title = notice.Heading + " (press <Enter> to dismiss)"

				noticeBox.Text = "\n" + notice.Message() + "\n"
				noticeBox.BorderStyle.Fg, _ = severity(notice.Severity)

				width := notice.Dx()
				if titleLen := len(noticeBox.Title); titleLen > width {
					width = titleLen
				}
				height := notice.Dy() + 4
				left := (totalWidth / 2.0) - (width / 2.0)

				noticeBox.SetRect(r(left, noticeTop, width+4, height))

				noticeTop = noticeTop + h(noticeBox)
				rc.Notices = append(rc.Notices, noticeBox)
			}

			output.Text = reactor.FormatOutput(rc.Simulation.Reactor.Turbine.Output)

			coreTemp.Text = fmt.Sprintf("%.2fc", rc.Simulation.Reactor.CoreTemp)
			coreTemp.TextStyle.Bg, coreTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.CoreTempAlarm.Severity())

			containmentTemp.Text = fmt.Sprintf("%.2fc", rc.Simulation.Reactor.ContainmentTemp)
			containmentTemp.TextStyle.Bg, containmentTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.ContainmentTempAlarm.Severity())

			turbineInletTemp.Text = fmt.Sprintf("%.2fc", rc.Simulation.Reactor.Turbine.InletTemp)
			turbineInletTemp.TextStyle.Bg, turbineInletTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Turbine.InletTempAlarm.Severity())

			turbineSpeed.Text = fmt.Sprintf("%.2frpm", rc.Simulation.Reactor.Turbine.SpeedRPM)
			turbineSpeed.TextStyle.Bg, turbineSpeed.TextStyle.Fg = severity(rc.Simulation.Reactor.Turbine.SpeedRPMAlarm.Severity())

			primaryInletTemp.Text = fmt.Sprintf("%.2fc", rc.Simulation.Reactor.Primary.InletTemp)
			primaryInletTemp.TextStyle.Bg, primaryInletTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Primary.InletTempAlarm.Severity())

			primaryOutletTemp.Text = fmt.Sprintf("%.2fc", rc.Simulation.Reactor.Primary.OutletTemp)
			primaryOutletTemp.TextStyle.Bg, primaryOutletTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Primary.OutletTempAlarm.Severity())

			secondaryInletTemp.Text = fmt.Sprintf("%.2fc", rc.Simulation.Reactor.Secondary.InletTemp)
			secondaryInletTemp.TextStyle.Bg, secondaryInletTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Secondary.InletTempAlarm.Severity())

			secondaryOutletTemp.Text = fmt.Sprintf("%.2fc", rc.Simulation.Reactor.Secondary.OutletTemp)
			secondaryOutletTemp.TextStyle.Bg, secondaryOutletTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Secondary.OutletTempAlarm.Severity())

			command.Text = "> " + rc.Command
			if messageCount := len(rc.Simulation.Log); messageCount > 0 {
				var m reactor.LogMessage
				for x := 0; x < messageCount; x++ {
					m = <-rc.Simulation.Log
					messageList.Text = m.String() + "\n" + messageList.Text
				}
			}

			var gauge *widgets.Gauge
			var label *widgets.Paragraph
			for index, controlRod := range rc.Simulation.Reactor.ControlRods {
				gauge = rc.ControlRods[index]
				label = rc.ControlRodTemps[index]
				gauge.Percent = int(controlRod.Position.Percent())
				label.Text = fmt.Sprintf("%.2fc", controlRod.Temp)
				label.TextStyle.Bg, label.TextStyle.Fg = severity(controlRod.TempAlarm.Severity())
			}

			primaryPump.Percent = int(rc.Simulation.Reactor.Primary.Throttle.Percent())
			secondaryPump.Percent = int(rc.Simulation.Reactor.Secondary.Throttle.Percent())

			termui.Render(rc.AllControls()...)
			time.Sleep(50 * time.Millisecond)
		}
	}
}

// SampleStats pulls relevant stats off the simulation.
func (rc *RenderContext) SampleStats() func() error {
	tick := time.Tick(time.Second)
	return func() error {
		for {
			<-tick
			rc.OutputHistory = append(rc.OutputHistory, Sample{
				Timestamp: time.Now(),
				Value:     rc.Simulation.Reactor.Turbine.Output,
			})
		}
	}
}

// utility functions

func (rc *RenderContext) getOutputHistory(last int) (data []float64) {
	if len(rc.OutputHistory) == 0 {
		return
	}

	var samples []Sample
	if len(rc.OutputHistory) > last {
		samples = rc.OutputHistory[:len(rc.OutputHistory)-last]
	} else {
		samples = rc.OutputHistory[:]
	}

	if len(samples) == 0 {
		return
	}

	for _, value := range samples {
		data = append(data, value.Value)
	}
	return
}
