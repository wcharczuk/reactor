package reactor

import (
	"fmt"
	"time"
)

// GradientChange is a change in position over a given time.
// It applies half the delta per quantum until the change is complete.
type GradientChange struct {
	Delta   float64
	Quantum time.Duration
}

// String implements fmt.Stringer.
func (gc GradientChange) String() string {
	return fmt.Sprintf("%d/%v", int(gc.Delta*255), gc.Quantum)
}

// IsAdditive returns if the position rate is additive.
func (gc GradientChange) IsAdditive() bool {
	return gc.Delta > 0
}
