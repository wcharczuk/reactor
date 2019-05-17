package reactor

// NewTurbine returns a new turbine.
func NewTurbine() *Turbine {
	return &Turbine{}
}

// Turbine generates power based on fan rpm.
type Turbine struct {
	SpeedRPM float64
}

// Output is the power output of the turbine.
func (t Turbine) Output() float64 {
	return t.SpeedRPM * TurbineOutputRateMinute
}
