package reactor

import (
	"math"
	"time"
)

// PositionRate is a change in position over a given time.
type PositionRate struct {
	Delta   int16
	Quantum time.Duration
}

// IsAdditive returns if the position rate is additive.
func (pr PositionRate) IsAdditive() bool {
	return pr.Delta > 0
}

// Affect applies the position rate to a given position for a given quantum.
func (pr PositionRate) Affect(position *Position, quantum time.Duration) {
	ratio := float64(quantum) / float64(pr.Quantum)
	change := math.Ceil(ratio * float64(pr.Delta))
	*position = *position + Position(uint8(change))
}
