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

// Xenon constants
const (
	XenonProductionCoefficient = 0.05 // how much xenon is produced per unit reactivity
	XenonCoefficient           = 0.9  // how much does xenon affect reactivity
	XenonTempThreshold         = 500  // when does xenon start burning off
	XenonBurnRateMinute        = 1024 //
)

const (
	// SteamThreshold is the temperature at which water turns to steam.
	// If the core is above this threshold, the water in the core turns to steam.
	// If the pump is active, that steam is replaced by water.
	SteamThreshold = 100.0

	// VoidCoefficient is the rate that a void (or steam) increases reactivity.
	VoidCoefficient = 1.05
)

// Alarm Thresholds
const (
	CoreTempWarning  = 500.0
	CoreTempCritical = 750.0
	CoreTempFatal    = 1000.0

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

	FuelRodTempWarning  = 2000.0
	FuelRodTempCritical = 3000.0
	FuelRodTempFatal    = 4000.0

	ControlRodTempWarning  = 2000.0
	ControlRodTempCritical = 3000.0
	ControlRodTempFatal    = 4000.0
)
