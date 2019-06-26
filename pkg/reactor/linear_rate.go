package reactor

import (
	"fmt"
	"time"
)

var (
	_ PositionChangeRate = (*LinearRate)(nil)
)

// NewLinearRate returns a new position rate.
func NewLinearRate(original float64, desired float64, quantum time.Duration) LinearRate {
	return LinearRate{
		Delta:   desired - original,
		Quantum: quantum,
	}
}

// LinearRate is a change in position over a given time.
type LinearRate struct {
	Delta   float64
	Quantum time.Duration
}

// String implements fmt.Stringer.
func (lc LinearRate) String() string {
	return fmt.Sprintf("%d/%v", int(lc.Delta*255), RoundMillis(lc.Quantum))
}

// IsAdditive returns if the position rate is additive.
func (lc LinearRate) IsAdditive() bool {
	return lc.Delta > 0
}

// Affect applies the position rate to a given position for a given quantum.
func (lc LinearRate) Affect(value *Position, quantum time.Duration) {
	ratio := float64(quantum) / float64(lc.Quantum)
	change := ratio * lc.Delta
	*value = *value + Position(change)
}
