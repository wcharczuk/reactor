package reactor

import "time"

// DefaultConfig is the default configuration.
var DefaultConfig = Config{
	Scripts: map[string][]string{
		"scram": []string{
			"notice initiating emergency shutdown of the reactor",
			"cr * 255",
			"pp 255",
			"sp 255",
			"notice scram initiated",
		},
		"base": []string{
			"cr * 135",
			"pp 255",
			"sp 255",
			"notice reactor set to base config",
		},
		"full": []string{
			"cr * 0",
			"pp 255",
			"sp 255",
			"notice reactor set to full output config",
		},
		"fail": []string{
			"cr * 0",
			"pp 0",
			"sp 0",
			"notice reactor set to failure config",
		},
	},
}

// Config is the reactor simulation config.
type Config struct {
	// TickInterval is the time between simulation steps.
	TickInterval time.Duration `yaml:"tickInterval"`
	// BaseTemp is the simulation base temperature.
	BaseTemp float64 `yaml:"baseTemp"`
	// FissionRateMinute is the btu per minute produced by a control rod.
	FissionRateMinute float64 `yaml:"fissionRate"`
	// TurbineOutputRateMinute is the rpm => kw/hr conversion rate.
	TurbineOutputRateMinute float64 `yaml:"turbineOutputRateMinute"`
	// TurbineThermalRateMinute is the c => rpm conversion rate.
	TurbineThermalRateMinute float64 `yaml:"turbineThermalRateMinute"`
	// TurbineDrag is the drag coefficient. It is a percentage of the current rpm.
	TurbineDrag float64 `yaml:"turbineDrag"`

	// ConductionRateMinute is the transfer rate between connected components
	// in a thermal chain, like the reactor to the primary coolant loop.
	ConductionRateMinute float64 `yaml:"conductionRateMinute"`
	// ConvectionRateMinute is the transfer rate between convection sections
	// such as between the secondary loop and the turbine.
	ConvectionRateMinute float64 `yaml:"convectionRateMinute"`
	// RadiantRateMinute is the transfer rate between unconneted components.
	RadiantRateMinute float64 `yaml:"radiantRateMinute"`

	// PrimaryTransferRateMinute is the btu capacity of the primary loop.
	PrimaryTransferRateMinute float64 `yaml:"primaryTransferRateMinute"`
	// SecondaryTransferRateMinute is the btu capacity of the secondary loop.
	SecondaryTransferRateMinute float64 `yaml:"secondaryTransferRateMinute"`

	// ControlRodAdjustment is the time to go from 0-255 on a control rod.
	ControlRodAdjustment time.Duration `yaml:"controlRodAdjustment"`
	// PumpThrottleAdjustment is the time to go from 0-255 on the pump throttle.
	PumpThrottleAdjustment time.Duration `yaml:"pumpThrottleAdjustment"`

	// Scripts are command sequences keyed by a single command.
	// A default script is "scam".
	Scripts map[string][]string `yaml:"scripts"`
}

const (
	// DefaultTickInterval is the default tick interval
	DefaultTickInterval = 250 * time.Millisecond
	// DefaultFissionRateMinute 16k Degrees a minute at full extension.
	DefaultFissionRateMinute = 16384
	// DefaultTurbineOutputRateMinute is the rpm => kw/hr ratio.
	DefaultTurbineOutputRateMinute = 512
	// DefaultTurbineThermalRateMinute is the temp => rpm ratio.
	DefaultTurbineThermalRateMinute = 16
	// DefaultTurbineDrag is the drag on the turbine shaft.
	DefaultTurbineDrag = 0.33
	// DefaultConductionRateMinute is a heat transfer constant.
	DefaultConductionRateMinute = 512
	// DefaultConvectionRateMinute is a heat transfer constant.
	DefaultConvectionRateMinute = 256
	// DefaultRadiantRateMinute is a heat transfer constant.
	DefaultRadiantRateMinute = 0.1
	// DefaultBaseTemp is the starting reactor core temperature.
	DefaultBaseTemp = 10.0
	// DefaultControlRodAdjustment is the default control rod adjustment rate.
	DefaultControlRodAdjustment = 10 * time.Second
	// DefaultPumpThrottleAdjustment is the default pump throttle adjustment rate.
	DefaultPumpThrottleAdjustment = 5 * time.Second
	// DefaultPrimaryTransferRateMinute is the default primary btu transfer.
	// The throttle * this is how much heat we can move from the inlet to the outlet.
	DefaultPrimaryTransferRateMinute = 1024
	// DefaultSecondaryTransferRateMinute is the default secondary btu transfer.
	// The throttle * this is how much heat we can move from the inlet to the outlet.
	DefaultSecondaryTransferRateMinute = 1024
)

// TickIntervalOrDefault returns the tick interval or a default.
func (c Config) TickIntervalOrDefault() time.Duration {
	if c.TickInterval > 0 {
		return c.TickInterval
	}
	return DefaultTickInterval
}

// BaseTempOrDefault returns a value or a default
func (c Config) BaseTempOrDefault() float64 {
	if c.BaseTemp > 0 {
		return c.BaseTemp
	}
	return DefaultBaseTemp
}

// FissionRateMinuteOrDefault returns the fission rate per minute or a default.
func (c Config) FissionRateMinuteOrDefault() float64 {
	if c.FissionRateMinute > 0 {
		return c.FissionRateMinute
	}
	return DefaultFissionRateMinute
}

// TurbineOutputRateMinuteOrDefault returns a value or a default.
func (c Config) TurbineOutputRateMinuteOrDefault() float64 {
	if c.TurbineOutputRateMinute > 0 {
		return c.TurbineOutputRateMinute
	}
	return DefaultTurbineOutputRateMinute
}

// TurbineThermalRateMinuteOrDefault returns a value or a default.
func (c Config) TurbineThermalRateMinuteOrDefault() float64 {
	if c.TurbineThermalRateMinute > 0 {
		return c.TurbineThermalRateMinute
	}
	return DefaultTurbineThermalRateMinute
}

// TurbineDragOrDefault returns a value or a default
func (c Config) TurbineDragOrDefault() float64 {
	if c.TurbineDrag > 0 {
		return c.TurbineDrag
	}
	return DefaultTurbineDrag
}

// ConductionRateMinuteOrDefault returns a value or a default
func (c Config) ConductionRateMinuteOrDefault() float64 {
	if c.ConductionRateMinute > 0 {
		return c.ConductionRateMinute
	}
	return DefaultConductionRateMinute
}

// ConvectionRateMinuteOrDefault returns a value or a default
func (c Config) ConvectionRateMinuteOrDefault() float64 {
	if c.ConvectionRateMinute > 0 {
		return c.ConvectionRateMinute
	}
	return DefaultConvectionRateMinute
}

// RadiantRateMinuteOrDefault returns a value or a default
func (c Config) RadiantRateMinuteOrDefault() float64 {
	if c.RadiantRateMinute > 0 {
		return c.RadiantRateMinute
	}
	return DefaultRadiantRateMinute
}

// PrimaryTransferRateMinuteOrDefault returns a value or a default
func (c Config) PrimaryTransferRateMinuteOrDefault() float64 {
	if c.PrimaryTransferRateMinute > 0 {
		return c.PrimaryTransferRateMinute
	}
	return DefaultPrimaryTransferRateMinute
}

// SecondaryTransferRateMinuteOrDefault returns a value or a default
func (c Config) SecondaryTransferRateMinuteOrDefault() float64 {
	if c.SecondaryTransferRateMinute > 0 {
		return c.SecondaryTransferRateMinute
	}
	return DefaultSecondaryTransferRateMinute
}

// ControlRodAdjustmentOrDefault returns a value or a default
func (c Config) ControlRodAdjustmentOrDefault() time.Duration {
	if c.ControlRodAdjustment > 0 {
		return c.ControlRodAdjustment
	}
	return DefaultControlRodAdjustment
}

// PumpThrottleAdjustmentOrDefault returns a value or a default
func (c Config) PumpThrottleAdjustmentOrDefault() time.Duration {
	if c.PumpThrottleAdjustment > 0 {
		return c.PumpThrottleAdjustment
	}
	return DefaultPumpThrottleAdjustment
}
