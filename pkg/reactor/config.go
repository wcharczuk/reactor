package reactor

import "time"

// Config is the reactor simulation config.
type Config struct {
	// TickInterval is the time between simulation steps.
	TickInterval time.Duration `yaml:"tickInterval"`
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

	// PrimaryBTU is the btu capacity of the primary loop.
	PrimaryBTU float64 `yaml:"primaryBTU"`
	// SecondaryBTU is the btu capacity of the secondary loop.
	SecondaryBTU float64 `yaml:"secondaryBTU"`

	// ControlRodAdjustment is the time to go from 0-255 on a control rod.
	ControlRodAdjustment time.Duration `yaml:"controlRodAdjustment"`
	// PumpThrottleAdjustment is the time to go from 0-255 on the pump throttle.
	PumpThrottleAdjustment time.Duration `yaml:"pumpThrottleAdjustment"`

	// Scripts are command sequences keyed by a single command.
	// A default script is "scam".
	Scripts map[string][]string `yaml:"sripts"`
}

const (
	// DefaultTickInterval is the default tick interval
	DefaultTickInterval = 250 * time.Millisecond
	// DefaultFissionRateMinute 8k Degrees a minute at full extension.
	DefaultFissionRateMinute = 8192
	// DefaultTurbineOutputRateMinute is the rpm => kw/hr ratio.
	DefaultTurbineOutputRateMinute = 512
	// DefaultTurbineTempRPMRate is the temp => rpm ratio.
	DefaultTurbineTempRPMRate = 16
	// DefaultTurbineDrag is the drag on the turbine shaft.
	DefaultTurbineDrag = 0.33
	// DefaultConductionRateMinute is a heat transfer constant.
	DefaultConductionRateMinute = 512
	// DefaultConvectionRateMinute is a heat transfer constant.
	DefaultConvectionRateMinute = 256
	// DefaultRadiantRateMinute is a heat transfer constant.
	DefaultRadiantRateMinute = 0.1
	// DefaultBaseTemperature is the starting reactor core temperature.
	DefaultBaseTemperature = 10.0
	// DefaultControlRodAdjustment is the default control rod adjustment rate.
	DefaultControlRodAdjustment = 10 * time.Second
	// DefaultPumpThrottleAdjustment is the default pump throttle adjustment rate.
	DefaultPumpThrottleAdjustment = 5 * time.Second
)

// TickIntervalOrDefault returns the tick interval or a default.
func (c Config) TickIntervalOrDefault() time.Duration {
	if c.TickInterval > 0 {
		return c.TickInterval
	}
	return DefaultTickInterval
}

// FissionRateMinuteOrDefault returns the fission rate per minute or a default.
func (c Config) FissionRateMinuteOrDefault() float64 {
	if c.FissionRateMinute > 0 {
		return c.FissionRateMinute
	}
	return DefaultFissionRateMinute
}
