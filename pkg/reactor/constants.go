package reactor

const (
	// PositionMin is the maximum minimum value.
	PositionMin Position = 0.0
	// PositionMax is the maximum position value.
	PositionMax Position = 1.0

	// TurbineOutputPerRPM is a constant
	TurbineOutputPerRPM = 10
	// BaseTemperature is the starting reactor core temperature.
	BaseTemperature = 20
	// TemperatureTransferRateMinute is how much of a difference in temperatures
	// is transfered per minute.
	TemperatureTransferRateMinute = 0.5
	// ReactionRateMinute is the rate of reaction increase per full control rod per minute.
	ReactionRateMinute = 10.0
	// ReactionHeatRateMinute is the rate of reaction increase per full control rod per minute.
	ReactionHeatRateMinute = 0.6
)
