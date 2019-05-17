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
)

// Adjustment rates are how long it takes to fully adjust a control.
const (
	ControlRodAdjustmentRate   = 10 * time.Second
	PumpThrottleAdjustmentRate = 5 * time.Second
)

// Alarm Thresholds
const (
	ContainmentTempWarning  = 200.0
	ContainmentTempCritical = 400.0
	ContainmentTempFatal    = 500.0
)

// Alarm Thresholds
const (
	CoreTempWarning  = 3000.0
	CoreTempCritical = 5000.0
	CoreTempFatal    = 6000.0

	PumpInletWarning  = 1000.0
	PumpInletCritical = 2000.0
	PumpInletFatal    = 3000.0

	PumpOutletWarning  = 500.0
	PumpOutletCritical = 1000.0
	PumpOutletFatal    = 1500.0

	TurbineRPMWarning  = 5000.0
	TurbineRPMCritical = 6000.0
	TurbineRPMFatal    = 8000.0

	ControlRodTempWarning  = 4000.0
	ControlRodTempCritical = 6000.0
	ControlRodTempFatal    = 7000.0
)
