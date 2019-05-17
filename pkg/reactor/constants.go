package reactor

import "time"

const (
	// DefaultTickInterval is the default tick interval
	DefaultTickInterval = 250 * time.Millisecond

	// FissionRateMinute 32k Degrees a minute at full extension.
	FissionRateMinute = 32768

	// PositionMin is the maximum minimum value.
	PositionMin Position = 0.0
	// PositionMax is the maximum position value.
	PositionMax Position = 1.0

	// TurbineOutputRateMinute is the rpm => kw/hr ratio.
	TurbineOutputRateMinute = 25

	// SinkTransferRateMinute is a constant.
	SinkTransferRateMinute = 250
	// ContainmentTransferRateMinute is a constant.
	ContainmentTransferRateMinute = 0.1
	// PumpTransferRateMinute is a constant.
	PumpTransferRateMinute = 250

	// BaseTemperature is the starting reactor core temperature.
	BaseTemperature = 20
	// TemperatureTransferRateMinute is how much of a difference in temperatures
	// is transfered per minute.
	TemperatureTransferRateMinute = 0.5
)
