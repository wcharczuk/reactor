package ui

import (
	"fmt"
	"image"
	"strings"
	"time"

	"github.com/wcharczuk/reactor/pkg/reactor"
	termui "github.com/wcharczuk/termui"
	"github.com/wcharczuk/termui/widgets"
)

// RenderContext is everything needed to render the simulation.
type RenderContext struct {
	CommandText   string
	OutputHistory []Sample
	Simulation    *reactor.Simulation

	Canvas image.Rectangle

	Controls []termui.Drawable
	Notices  []*widgets.Paragraph

	ControlRods     []*widgets.Gauge
	ControlRodTemps []*widgets.Paragraph
	FuelRods        []*widgets.Gauge
	FuelRodTemps    []*widgets.Paragraph

	Header      *widgets.Paragraph
	Command     *widgets.Paragraph
	MessageList *widgets.Paragraph

	ReactorOutput       *widgets.Paragraph
	TurbineOutput       *widgets.Paragraph
	TurbineSpeed        *widgets.Paragraph
	TurbineCoolantTemp  *widgets.Paragraph
	PrimaryInletTemp    *widgets.Paragraph
	PrimaryOutletTemp   *widgets.Paragraph
	SecondaryInletTemp  *widgets.Paragraph
	SecondaryOutletTemp *widgets.Paragraph
	CoreTemp            *widgets.Paragraph
	ContainmentTemp     *widgets.Paragraph

	PrimaryPump   *widgets.Gauge
	SecondaryPump *widgets.Gauge
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
		if len(rc.CommandText) == 0 {
			return nil
		}
		if processErr := rc.Simulation.ProcessCommand(rc.CommandText); processErr != nil {
			if processErr == reactor.ErrQuiting {
				err = processErr
				return
			}
			rc.Simulation.Message(processErr.Error())
		}
		rc.CommandText = ""
	case "<C-l>", "<Escape>":
		rc.CommandText = ""
	case "C-8>", "<Backspace>": // handle backspace
		rc.CommandText = strings.TrimRightFunc(rc.CommandText, firstRune())
	default:
		rc.CommandText = rc.CommandText + escapeInput(e.ID)
	}
	return
}

// Render renders controls and advances the simulation.
func (rc *RenderContext) Render() func() error {
	return func() (err error) {
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("%v", r)
				return
			}
		}()

		for {
			noticeTop := 0
			noticeCount := len(rc.Simulation.Notices)
			for _, noticeBox := range rc.Notices {
				noticeTop += Height(noticeBox)
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
				left := (rc.Canvas.Dx() >> 1) - (width >> 1)

				noticeBox.SetRect(RelativeRect(left, noticeTop, width+4, height))

				noticeTop = noticeTop + Height(noticeBox)
				rc.Notices = append(rc.Notices, noticeBox)
			}

			rc.ReactorOutput.Text = reactor.FormatOutput(rc.Simulation.Reactor.Reactivity)
			rc.TurbineOutput.Text = reactor.FormatOutput(rc.Simulation.Reactor.Turbine.Output)

			rc.CoreTemp.Text = fmt.Sprintf("%.2fc", rc.Simulation.Reactor.CoreTemp)
			rc.CoreTemp.TextStyle.Bg, rc.CoreTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.CoreTempAlarm.Severity())

			rc.ContainmentTemp.Text = fmt.Sprintf("%.2fc", rc.Simulation.Reactor.ContainmentTemp)
			rc.ContainmentTemp.TextStyle.Bg, rc.ContainmentTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.ContainmentTempAlarm.Severity())

			rc.TurbineCoolantTemp.Text = fmt.Sprintf("%.2fc", reactor.CoolantAverage(rc.Simulation.Reactor.Turbine.Coolant.Water))
			rc.TurbineCoolantTemp.TextStyle.Bg, rc.TurbineCoolantTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Turbine.CoolantTempAlarm.Severity())

			rc.TurbineSpeed.Text = fmt.Sprintf("%.2frpm", rc.Simulation.Reactor.Turbine.SpeedRPM)
			rc.TurbineSpeed.TextStyle.Bg, rc.TurbineSpeed.TextStyle.Fg = severity(rc.Simulation.Reactor.Turbine.SpeedRPMAlarm.Severity())

			rc.PrimaryInletTemp.Text = fmt.Sprintf("%.2fc", reactor.CoolantAverage(rc.Simulation.Reactor.Primary.Inlet.Water))
			rc.PrimaryInletTemp.TextStyle.Bg, rc.PrimaryInletTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Primary.InletTempAlarm.Severity())

			rc.PrimaryOutletTemp.Text = fmt.Sprintf("%.2fc", reactor.CoolantAverage(rc.Simulation.Reactor.Primary.Outlet.Water))
			rc.PrimaryOutletTemp.TextStyle.Bg, rc.PrimaryOutletTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Primary.OutletTempAlarm.Severity())

			rc.SecondaryInletTemp.Text = fmt.Sprintf("%.2fc", reactor.CoolantAverage(rc.Simulation.Reactor.Secondary.Inlet.Water))
			rc.SecondaryInletTemp.TextStyle.Bg, rc.SecondaryInletTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Secondary.InletTempAlarm.Severity())

			rc.SecondaryOutletTemp.Text = fmt.Sprintf("%.2fc", reactor.CoolantAverage(rc.Simulation.Reactor.Secondary.Outlet.Water))
			rc.SecondaryOutletTemp.TextStyle.Bg, rc.SecondaryOutletTemp.TextStyle.Fg = severity(rc.Simulation.Reactor.Secondary.OutletTempAlarm.Severity())

			rc.Command.Text = "> " + rc.CommandText
			if messageCount := len(rc.Simulation.Log); messageCount > 0 {
				var m reactor.LogMessage
				for x := 0; x < messageCount; x++ {
					m = <-rc.Simulation.Log
					rc.MessageList.Text = m.String() + "\n" + rc.MessageList.Text
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

			rc.PrimaryPump.Percent = int(rc.Simulation.Reactor.Primary.Throttle.Percent())
			rc.SecondaryPump.Percent = int(rc.Simulation.Reactor.Secondary.Throttle.Percent())

			termui.Render(rc.AllControls()...)
			time.Sleep(50 * time.Millisecond)
		}
	}
}

// AllControls returns a unified list of controls.
func (rc RenderContext) AllControls() (all []termui.Drawable) {
	all = []termui.Drawable{
		rc.Header,
		rc.Command,
		rc.MessageList,
		rc.ReactorOutput,
		rc.TurbineOutput,
		rc.TurbineSpeed,
		rc.TurbineCoolantTemp,
		rc.PrimaryInletTemp,
		rc.PrimaryOutletTemp,
		rc.CoreTemp,
		rc.ContainmentTemp,
		rc.PrimaryPump,
		rc.SecondaryPump,
	}
	for _, c := range rc.ControlRods {
		all = append(all, c)
	}
	for _, c := range rc.ControlRodTemps {
		all = append(all, c)
	}
	for _, c := range rc.FuelRods {
		all = append(all, c)
	}
	for _, c := range rc.FuelRodTemps {
		all = append(all, c)
	}
	for _, c := range rc.Notices {
		all = append(all, c)
	}
	return
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

func (rc *RenderContext) initControls() {
	totalWidth := 160
	controlHeight := 3
	totalHeight := controlHeight + (controlHeight * len(rc.Simulation.Reactor.ControlRods)) + (2 * controlHeight)

	gaugeWidth := 50
	controlRodTempWidth := 15
	messageListWidth := 60

	middleWidth := totalWidth - (gaugeWidth + controlRodTempWidth + messageListWidth)
	middleWidth2 := middleWidth >> 1

	col12 := totalWidth
	col1 := totalWidth / 12
	col2 := totalWidth / 2
	col3 := totalWidth / 4
	col4 := totalWidth / 3

	rowHeight := 3
	row0 := 0
	row1 := rowHeight
	row2 := 2 * rowHeight
	row3 := 3 * rowHeight
	row4 := 4 * rowHeight
	row5 := 5 * rowHeight

	rc.Header = widgets.NewParagraph()
	rc.Header.Text = "Reactor"
	rc.Header.SetRect(RelativeRect(0, 0, 9, controlHeight))

	rc.MessageList = widgets.NewParagraph()
	rc.MessageList.Title = "SKALA"
	rc.MessageList.SetRect(RelativeRect(totalWidth-messageListWidth, 0, messageListWidth, totalHeight))

	rc.Command = widgets.NewParagraph()
	rc.Command.Text = "> " + rc.CommandText
	rc.Command.SetRect(RelativeRect(9, 0, totalWidth-(Width(rc.MessageList)+Width(rc.Header)), 3))

	gaugeTop := row1
	for index := range rc.Simulation.Reactor.ControlRods {
		gauge := widgets.NewGauge()
		gauge.Title = fmt.Sprintf("Control Rod %d", index)
		gauge.SetRect(RelativeRect(0, gaugeTop, gaugeWidth, 3))

		gaugeTemp := widgets.NewParagraph()
		gaugeTemp.Title = fmt.Sprintf("CR %d Temp", index)
		gaugeTemp.SetRect(RelativeRect(gaugeWidth, gaugeTop, controlRodTempWidth, 3))

		rc.ControlRods = append(rc.ControlRods, gauge)
		rc.ControlRodTemps = append(rc.ControlRodTemps, gaugeTemp)

		gaugeTop = gaugeTop + Height(gauge)
	}

	rc.ReactorOutput = widgets.NewParagraph()
	rc.ReactorOutput.Title = "React. Output"
	rc.ReactorOutput.SetRect(RelativeRect(gaugeWidth+controlRodTempWidth, controlHeight, middleWidth2, 3))

	rc.TurbineOutput = widgets.NewParagraph()
	rc.TurbineOutput.Title = "Turb. Output"
	rc.TurbineOutput.SetRect(RelativeRect(gaugeWidth+controlRodTempWidth+middleWidth2, controlHeight, middleWidth2+1, 3))

	rc.TurbineCoolantTemp = widgets.NewParagraph()
	rc.TurbineCoolantTemp.Title = "Turb. Temp"
	rc.TurbineCoolantTemp.SetRect(RelativeRect(gaugeWidth+controlRodTempWidth, 2*controlHeight, middleWidth2, 3))

	rc.TurbineSpeed = widgets.NewParagraph()
	rc.TurbineSpeed.Title = "Turbine RPM"
	rc.TurbineSpeed.SetRect(RelativeRect(gaugeWidth+controlRodTempWidth+Width(rc.TurbineCoolantTemp), 2*controlHeight, middleWidth2+1, 3))

	rc.CoreTemp = widgets.NewParagraph()
	rc.CoreTemp.Title = "Core Temp"
	rc.CoreTemp.SetRect(RelativeRect(gaugeWidth+controlRodTempWidth, 3*controlHeight, middleWidth2, 3))

	rc.ContainmentTemp = widgets.NewParagraph()
	rc.ContainmentTemp.Title = "Cont. Temp"
	rc.ContainmentTemp.SetRect(RelativeRect(gaugeWidth+controlRodTempWidth+Width(rc.CoreTemp), 3*controlHeight, middleWidth2+1, 3))

	rc.PrimaryPump = widgets.NewGauge()
	rc.PrimaryPump.Title = "Primary Pump"
	rc.PrimaryPump.SetRect(RelativeRect(0, gaugeTop, 50, 3))

	rc.PrimaryInletTemp = widgets.NewParagraph()
	rc.PrimaryInletTemp.Title = "Pr. In Temp"
	rc.PrimaryInletTemp.SetRect(RelativeRect(gaugeWidth, gaugeTop, 17, 3))

	rc.PrimaryOutletTemp = widgets.NewParagraph()
	rc.PrimaryOutletTemp.Title = "Pr. Out Temp"
	rc.PrimaryOutletTemp.SetRect(RelativeRect(gaugeWidth+Width(rc.PrimaryInletTemp), gaugeTop, 17, 3))

	gaugeTop = gaugeTop + Height(rc.PrimaryPump)

	rc.SecondaryPump = widgets.NewGauge()
	rc.SecondaryPump.Title = "Secondary Pump"
	rc.SecondaryPump.SetRect(RelativeRect(0, gaugeTop, 50, 3))

	rc.SecondaryInletTemp = widgets.NewParagraph()
	rc.SecondaryInletTemp.Title = "Sec. In Temp"
	rc.SecondaryInletTemp.SetRect(RelativeRect(50, gaugeTop, 17, 3))

	rc.SecondaryOutletTemp = widgets.NewParagraph()
	rc.SecondaryOutletTemp.Title = "Sec. Out Temp"
	rc.SecondaryOutletTemp.SetRect(RelativeRect(50+Width(rc.SecondaryInletTemp), gaugeTop, 17, 3))
}

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
