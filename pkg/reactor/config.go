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
		"az5": []string{
			"script scram",
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
	// NeutronFuel is the amount of base neutron emiter fuel the reactor starts with.
	NeutronFuel float64 `yaml:"neutronFuel"`

	// VoidCoefficient is the amount steam (void) contributes to reactivity.
	VoidCoefficient float64 `yaml:"voidCoefficient"`
	// TempCoefficient is the amount the temperature contributes to reactivity.
	TempCoefficient float64 `yaml:"tempCoefficient"`
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

	// PumpTransferRateMinute is the btu capacity of the primary loop.
	PumpTransferRateMinute float64 `yaml:"primaryTransferRateMinute"`

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
	// DefaultBaseTemp is the starting reactor core temperature.
	DefaultBaseTemp = 10.0
	// DefaultNeutronFuel is the default starting neutron fuel.
	DefaultNeutronFuel = 1024.0
	// DefaultNeutronRateMinute is the default consumption rate per min at max extension.
	DefaultNeutronRateMinute = 1.0
	// DefaultVoidCoefficient is the default void coefficient.
	DefaultVoidCoefficient = 1.05
	// DefaultTempCoefficient is the default temperature coefficient.
	DefaultTempCoefficient = 0.90
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
	DefaultRadiantRateMinute = 0.01
	// DefaultControlRodAdjustment is the default control rod adjustment rate.
	DefaultControlRodAdjustment = 10 * time.Second
	// DefaultPumpThrottleAdjustment is the default pump throttle adjustment rate.
	DefaultPumpThrottleAdjustment = 5 * time.Second
	// DefaultPumpTransferRateMinute is the default primary heat transfer.
	// The throttle * this is how much heat we can move from the inlet to the outlet per minute.
	DefaultPumpTransferRateMinute = 4096
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

// NeutronFuelOrDefault returns the neutron fuel or a default.
func (c Config) NeutronFuelOrDefault() float64 {
	if c.NeutronFuel > 0 {
		return c.NeutronFuel
	}
	return DefaultNeutronFuel
}

// VoidCoefficientOrDefault returns the void coefficient or a default.
func (c Config) VoidCoefficientOrDefault() float64 {
	if c.VoidCoefficient > 0 {
		return c.VoidCoefficient
	}
	return DefaultVoidCoefficient
}

// TempCoefficientOrDefault returns the temperature coefficient or a default.
func (c Config) TempCoefficientOrDefault() float64 {
	if c.TempCoefficient > 0 {
		return c.TempCoefficient
	}
	return DefaultTempCoefficient
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

// PumpTransferRateMinuteOrDefault returns a value or a default
func (c Config) PumpTransferRateMinuteOrDefault() float64 {
	if c.PumpTransferRateMinute > 0 {
		return c.PumpTransferRateMinute
	}
	return DefaultPumpTransferRateMinute
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
