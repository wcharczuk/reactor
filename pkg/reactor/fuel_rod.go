package reactor

import (
	"fmt"
	"time"
)

// NewFuelRod returns a new control rod.
func NewFuelRod(cfg Config, index int) *FuelRod {
	fr := &FuelRod{
		Component: NewComponent(cfg),
		Index:     index,
		Temp:      cfg.BaseTempOrDefault(),
	}
	fr.TempAlarm = NewThresholdAlarm(
		fmt.Sprintf("Fuel Rod %d temp", index),
		func() float64 { return fr.Temp },
		Thresholds(FuelRodTempFatal, FuelRodTempCritical, FuelRodTempWarning),
	)
	return fr
}

// FuelRod represents a fuel source.
type FuelRod struct {
	*Component
	Index      int
	Enrichment float64
	Temp       float64
	TempAlarm  *ThresholdAlarm
}

// Alarms returns alarms for the component.
func (fr *FuelRod) Alarms() []Alarm {
	return []Alarm{
		fr.TempAlarm,
	}
}

// Simulate implements simulatable.
func (fr *FuelRod) Simulate(quantum time.Duration) error {
	return nil
}
