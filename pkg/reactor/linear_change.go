package reactor

import (
	"fmt"
	"time"
)

// NewLinearChange returns a new position rate.
func NewLinearChange(original float64, desired float64, quantum time.Duration) LinearChange {
	return LinearChange{
		Delta:   desired - original,
		Quantum: quantum,
	}
}

// LinearChange is a change in position over a given time.
type LinearChange struct {
	Delta   float64
	Quantum time.Duration
}

// String implements fmt.Stringer.
func (lc LinearChange) String() string {
	return fmt.Sprintf("%d/%v", int(lc.Delta*255), lc.Quantum)
}

// IsAdditive returns if the position rate is additive.
func (lc LinearChange) IsAdditive() bool {
	return lc.Delta > 0
}

// Affect applies the position rate to a given position for a given quantum.
func (lc LinearChange) Affect(value *Position, quantum time.Duration) {
	ratio := float64(quantum) / float64(lc.Quantum)
	change := ratio * lc.Delta
	*value = *value + Position(change)
}
