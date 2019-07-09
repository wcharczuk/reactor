package ui

import (
	"fmt"
	"strings"
	"time"

	"github.com/wcharczuk/reactor/pkg/reactor"
	termui "github.com/wcharczuk/termui"
	"github.com/wcharczuk/termui/widgets"
)

// NewRenderContext returns a new render context.
func NewRenderContext(sim *reactor.Simulation) *RenderContext {
	return &RenderContext{
		Canvas:     NewCanvas(25, 160),
		Simulation: sim,
	}
}

// RenderContext is everything needed to render the simulation.
type RenderContext struct {
	Canvas

	Recover bool

	CommandText   string
	OutputHistory []Sample
	Simulation    *reactor.Simulation

	Controls            []termui.Drawable
	Notices             []*widgets.Paragraph
	ControlRods         []*widgets.Paragraph
	ControlRodTemps     []*widgets.Paragraph
	FuelRodTemps        []*widgets.Paragraph
	Header              *widgets.Paragraph
	Command             *widgets.Paragraph
	MessageList         *widgets.Paragraph
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
	PrimaryPump         *widgets.Paragraph
	SecondaryPump       *widgets.Paragraph
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

// Init sets up controls.
func (rc *RenderContext) Init() {

	// row 0
	rc.Header = rc.Div("", rc.RowStart(0, 2), OptText("Reactor"))
	rc.Command = rc.Div("", rc.RightOf(rc.Header, 12))
	rc.MessageList = rc.Div("SKALA", rc.RightOf(rc.Command, 10), OptHeight(rc.Canvas.Height))

	// control rods
	var lastCR *widgets.Paragraph
	for index := range rc.Simulation.Reactor.ControlRods {
		var cr *widgets.Paragraph
		if index == 0 {
			cr = rc.Div("", rc.RowStart(1, 2), OptNoPadding, OptBorderHide)
		} else {
			cr = rc.Div("", rc.Below(lastCR, 2), OptNoPadding, OptBorderHide)
		}
		crTemp := rc.Div("", rc.RightOf(cr, 2), OptNoPadding, OptBorderHide)

		rc.ControlRods = append(rc.ControlRods, cr)
		rc.ControlRodTemps = append(rc.ControlRodTemps, crTemp)
		lastCR = cr
	}

	// other controls in rows 1-N
	// row 0
	rc.ReactorOutput = rc.Div("React. Output", rc.RightOf(rc.ControlRodTemps[0], 3))
	rc.TurbineOutput = rc.Div("Turb. Output", rc.RightOf(rc.ReactorOutput, 3))
	rc.TurbineCoolantTemp = rc.Div("Turb. Temp", rc.RightOf(rc.TurbineOutput, 3))

	// row 1
	rc.TurbineSpeed = rc.Div("Turb. Speed", rc.RightOf(rc.ControlRodTemps[1], 3))
	rc.CoreTemp = rc.Div("Core Temp", rc.RightOf(rc.TurbineSpeed, 3))
	rc.ContainmentTemp = rc.Div("Cont. Temp", rc.RightOf(rc.CoreTemp, 3))

	// row 2
	rc.PrimaryPump = rc.Div("Primary Pump", rc.RightOf(rc.ControlRodTemps[2], 3))
	rc.PrimaryInletTemp = rc.Div("Pr. In Temp", rc.RightOf(rc.PrimaryPump, 3))
	rc.PrimaryOutletTemp = rc.Div("Pr. Out Temp", rc.RightOf(rc.PrimaryInletTemp, 3))

	// row 3
	rc.SecondaryPump = rc.Div("Secondary Pump", rc.RightOf(rc.ControlRodTemps[3], 3))
	rc.SecondaryInletTemp = rc.Div("Sec. In Temp", rc.RightOf(rc.SecondaryPump, 3))
	rc.SecondaryOutletTemp = rc.Div("Sec. Out Temp", rc.RightOf(rc.SecondaryInletTemp, 3))
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
			rc.drawNotices()

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

			var gauge *widgets.Paragraph
			var label *widgets.Paragraph
			for index, controlRod := range rc.Simulation.Reactor.ControlRods {
				gauge = rc.ControlRods[index]
				label = rc.ControlRodTemps[index]
				gauge.Text = fmt.Sprintf("%0.2f%%", controlRod.Position.Percent())
				label.Text = fmt.Sprintf("%.2fc", controlRod.Temp)
				label.TextStyle.Bg, label.TextStyle.Fg = severity(controlRod.TempAlarm.Severity())
			}

			rc.PrimaryPump.Text = fmt.Sprintf("%0.2f%%", rc.Simulation.Reactor.Primary.Throttle.Percent())
			rc.SecondaryPump.Text = fmt.Sprintf("%0.2f%%", rc.Simulation.Reactor.Secondary.Throttle.Percent())

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
		rc.PrimaryPump,
		rc.PrimaryInletTemp,
		rc.PrimaryOutletTemp,
		rc.CoreTemp,
		rc.ContainmentTemp,
		rc.SecondaryPump,
		rc.SecondaryInletTemp,
		rc.SecondaryOutletTemp,
	}
	for _, c := range rc.ControlRods {
		all = append(all, c)
	}
	for _, c := range rc.ControlRodTemps {
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

// Div returns a new text paragraph.
func (rc *RenderContext) Div(title string, options ...ControlOption) *widgets.Paragraph {
	div := widgets.NewParagraph()
	div.Title = title
	for _, opt := range options {
		opt(div)
	}
	return div
}

// RowStart returns a control option
func (rc *RenderContext) RowStart(row, colWidth int) ControlOption {
	return OptSetRect(0, rc.Row(row), rc.Col(colWidth), rc.Row(row)+rc.RowHeight())
}

// RightOf returns a control option that sets the rect to position to the right
// of a given control on the same row.
func (rc *RenderContext) RightOf(control GetRectProvider, colWidth int) ControlOption {
	topLeft := control.GetRect().Min
	bottomRight := control.GetRect().Max
	return OptSetRect(bottomRight.X, topLeft.Y, bottomRight.X+rc.Canvas.Col(colWidth), bottomRight.Y)
}

// Below returns a control option that sets the rect to the position below
// a given control.
func (rc *RenderContext) Below(control GetRectProvider, colWidth int) ControlOption {
	topLeft := control.GetRect().Min
	bottomRight := control.GetRect().Max
	return OptSetRect(topLeft.X, bottomRight.Y, topLeft.X+rc.Canvas.Col(colWidth), bottomRight.Y+rc.Canvas.RowHeight())
}

func (rc *RenderContext) drawNotices() {
	// figure out where to add new notices ...
	var noticeTop int
	noticeCount := len(rc.Simulation.Notices)
	for _, noticeBox := range rc.Notices {
		noticeTop += noticeBox.GetRect().Dy()
	}

	if noticeTop >= rc.Canvas.Height {
		return
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

		left := rc.Width2() - (width >> 1)
		right := width + 4
		bottom := notice.Dy() + 4

		noticeBox.SetRect(left, noticeTop, right, bottom)

		noticeTop = noticeTop + noticeBox.GetRect().Dy()
		rc.Notices = append(rc.Notices, noticeBox)
	}
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
