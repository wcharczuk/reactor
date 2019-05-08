package main

import (
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"

	"reactor/pkg/reactor"

	"github.com/blend/go-sdk/async"
	"github.com/blend/go-sdk/logger"

	ui "github.com/gizak/termui"
)

func main() {
	err := ui.Init()
	if err != nil {
		logger.FatalExit(err)
	}
	defer ui.Close()

	s := reactor.NewSimulation()
	if err := async.RunToError(HandleInputs(s), RenderLoop(s)); err != nil {
		logger.Sync().SyncFatal(err)
	}
}

// HandleInputs handles inputs.
func HandleInputs(s *reactor.Simulation) func() error {
	return func() error {
		uiEvents := ui.PollEvents()
		var e ui.Event
		for {
			select {
			case e = <-uiEvents:
				switch e.ID {
				case "q", "<C-c>":
					return fmt.Errorf("quitting")
				case "<Enter>":
					if err := ProcessCommand(s); err != nil {
						s.Errors <- err
					}
					s.Command = ""
				default:
					s.Command = s.Command + e.ID
				}
			}
		}
	}
}

// ProcessCommand processes a command.
func ProcessCommand(s *reactor.Simulation) error {
	parts := strings.Split(s.Command, " ")
	first := parts[0]
	var rest []string
	if len(parts) > 1 {
		rest = parts[1:]
	}

	switch first {
	case "cr":
		if len(rest) < 2 {
			return fmt.Errorf("invalid `cr` args; must provide index and amount (0-255)")
		}

		parsed, err := ParseInts(ValidUint8, rest...)
		if err != nil {
			return err
		}

		controlRod := s.Reactor.ControlRods[parsed[0]]
		s.Events <- reactor.NewPositionChange(&controlRod.Position, reactor.Position(parsed[0]), 5*time.Second)
	}

	return nil
}

// RenderLoop renders controls and advances the simulation.
func RenderLoop(s *reactor.Simulation) func() error {
	return func() error {
		var top, left int
		header := ui.NewParagraph("Reactor")
		header.Width = 9
		header.Height = 3
		header.X = left
		header.Y = top

		top = top + header.Height

		var gauges []*ui.Gauge
		for index := range s.Reactor.ControlRods {
			gauge := ui.NewGauge()
			gauge.Width = 50
			gauge.Height = 3
			gauge.X = left
			gauge.Y = top
			gauge.BorderLabel = fmt.Sprintf("Control Rod %d", index)
			gauges = append(gauges, gauge)
			top = top + gauge.Height
		}

		var controls []ui.Bufferer
		controls = append(controls, header)
		for _, gauge := range gauges {
			controls = append(controls, gauge)
		}

		last := time.Now()
		for {
			s.Reactor.Simulate(time.Since(last))
			last = time.Now()

			for index, gauge := range gauges {
				gauge.Percent = int(s.Reactor.ControlRods[index].Position.Percent())
			}

			ui.Render(controls...)
		}
	}
}

// ParseInts parses a list of strings as ints, and applies a given validator.
func ParseInts(validator func(int) error, values ...string) ([]int, error) {
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

// Between returns if a value is between the given min and max.
func Between(min, max int) func(int) error {
	return func(v int) error {
		if v < min || v >= max {
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
