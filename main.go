package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/blend/go-sdk/async"
	"github.com/blend/go-sdk/configutil"
	"github.com/blend/go-sdk/logger"

	"github.com/wcharczuk/reactor/pkg/reactor"
	"github.com/wcharczuk/reactor/pkg/ui"

	// using .
	"github.com/wcharczuk/termui"
)

var (
	flagConfigPath = flag.String("config", "config.yml", "The simulation config file path (optional)")
)

func main() {
	flag.Parse()

	err := termui.Init()
	if err != nil {
		logger.FatalExit(err)
	}
	defer func() {
		termui.Close()
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

	rc := &ui.RenderContext{
		Simulation: s,
	}

	err = async.RunToError(
		rc.HandleInputs(),
		rc.Render(),
		rc.Simulate(),
		rc.SampleStats(),
	)
}
