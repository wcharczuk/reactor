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
	// XenonProductionRate is the amount of xenon created per unit of reaction rate.
	XenonProductionRate = 0.5
	// XenonThreshold is the point at which xemon starts to burn off.
	// It is a core temperature.
	XenonThreshold = 500
	// XenonAbsorbtionRate is the amount of reactivity absorbed per
	// unit of xenon.
	XenonAbsorbtionRate = 10

	// XenonBurnRateMinute is the rate xenon burns off per unit temperature above a threshold.
	XenonBurnRateMinute = 1024

	// SteamThreshold is the temperature at which water turns to steam.
	// If the core is above this threshold, the water in the core turns to steam.
	// If the pump is active, that steam is replaced by water.
	SteamThreshold = 100.0

	// CoolantLoopVolume is the volume of a coolant loop section.
	CoolantLoopVolume = 1024
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

	TurbineCoolantWarning  = 750.0
	TurbineCoolantCritical = 1500.0
	TurbineCoolantFatal    = 3000.0

	TurbineRPMWarning  = 5000.0
	TurbineRPMCritical = 6000.0
	TurbineRPMFatal    = 8000.0

	ControlRodTempWarning  = 2000.0
	ControlRodTempCritical = 3000.0
	ControlRodTempFatal    = 4000.0
)
