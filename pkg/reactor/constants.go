package reactor

// Alarm Severity
const (
	SeverityFatal    = "FATAL"
	SeverityCritical = "CRITICAL"
	SeverityWarning  = "WARN"
	SeverityInfo     = "INFO"
)

const (
	// PositionMin is the maximum minimum value.
	PositionMin Position = 0.0
	// PositionMax is the maximum position value.
	PositionMax Position = 1.0
)

// Threshold message formats.
const (
	TempThresholdMessageFormat = "Above %0.2f"
	RPMThresholdMessageFormat  = "RPM Above %0.2f"
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

	PumpOutletWarning  = 500.0
	PumpOutletCritical = 1000.0
	PumpOutletFatal    = 1500.0

	TurbineRPMWarning  = 5000.0
	TurbineRPMCritical = 6000.0
	TurbineRPMFatal    = 8000.0

	ControlRodTempWarning  = 2000.0
	ControlRodTempCritical = 3000.0
	ControlRodTempFatal    = 4000.0
)
