package reactor

import "math"

const (
	// Max8 is the maximum uint8 value.
	Max8 = math.MaxUint8
	// Max16 is the maximum uint16 value.
	Max16 = math.MaxUint16
	// TurbineOutputPerRPM is a constant
	TurbineOutputPerRPM = 10
	// BaseTemperatureKelvin is the starting reactor core temperature.
	BaseTemperatureKelvin = 290
	// TemperatureTransferRateMinute is how much of a difference in temperatures
	// is transfered per minute.
	TemperatureTransferRateMinute = 0.5
	// ReactionRateMinute is the rate of reaction increase per full control rod per minute.
	ReactionRateMinute = 10.0
	// ReactionHeatRateMinute is the rate of reaction increase per full control rod per minute.
	ReactionHeatRateMinute = 0.6
)
