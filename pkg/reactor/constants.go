package reactor

const (
	// PositionMin is the maximum minimum value.
	PositionMin Position = 0.0
	// PositionMax is the maximum position value.
	PositionMax Position = 1.0
)

// Threshold message formats.
const (
	TempThresholdMessageFormat = "Temperature Above %0.2f"
	RPMThresholdMessageFormat  = "RPM Above %0.2f"
)

const (
	// XenonFulcrum is the temperature at which xenon is burned off.
	XenonFulcrum = 500.0
	// XenonThreshold is the minimum threshold for where the reactor will create xenon.
	XenonThreshold = 100.0
	// SteamThreshold is the temperature at which water turns to steam.
	SteamThreshold = 100.0
)

// Alarm Thresholds
const (
	CoreTempWarning  = 1000.0
	CoreTempCritical = 2000.0
	CoreTempFatal    = 3000.0

	ContainmentTempWarning  = 200.0
	ContainmentTempCritical = 400.0
	ContainmentTempFatal    = 500.0

	PumpInletWarning  = 1000.0
	PumpInletCritical = 2000.0
	PumpInletFatal    = 3000.0

	PumpOutletWarning  = 750.0
	PumpOutletCritical = 1500.0
	PumpOutletFatal    = 3000.0

	TurbineRPMWarning  = 5000.0
	TurbineRPMCritical = 6000.0
	TurbineRPMFatal    = 8000.0

	ControlRodTempWarning  = 2000.0
	ControlRodTempCritical = 3000.0
	ControlRodTempFatal    = 4000.0
)
