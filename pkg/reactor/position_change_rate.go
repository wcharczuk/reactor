package reactor

import (
	"fmt"
	"time"
)

// NewPositionChangeRate returns a new position rate.
func NewPositionChangeRate(original float64, desired float64, quantum time.Duration) PositionChangeRate {
	return PositionChangeRate{
		Delta:   desired - original,
		Quantum: quantum,
	}
}

// PositionChangeRate is a change in position over a given time.
type PositionChangeRate struct {
	Delta   float64
	Quantum time.Duration
}

// String implements fmt.Stringer.
func (pr PositionChangeRate) String() string {
	return fmt.Sprintf("%d/%v", int(pr.Delta*255), pr.Quantum)
}

// IsAdditive returns if the position rate is additive.
func (pr PositionChangeRate) IsAdditive() bool {
	return pr.Delta > 0
}

// Affect applies the position rate to a given position for a given quantum.
func (pr PositionChangeRate) Affect(value *Position, quantum time.Duration) {
	ratio := float64(quantum) / float64(pr.Quantum)
	change := ratio * pr.Delta
	*value = *value + Position(change)
}
