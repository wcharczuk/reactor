package reactor

import (
	"fmt"
	"time"
)

// NewPositionChange returns a new position change.
func NewPositionChange(label string, position *Position, desired Position, quantum time.Duration) *PositionChange {
	from := float64(*position)
	to := float64(desired)
	return &PositionChange{
		Position: position,
		Label:    label,
		Original: *position,
		Desired:  desired,
		Rate:     NewLinearRate(from, to, RelativeQuantum(from, to, 1.0, quantum)),
	}
}

// PositionChange change is a change to a position.
type PositionChange struct {
	Position *Position
	Label    string
	Desired  Position
	Original Position
	Rate     PositionChangeRate
}

// String implements fmt.Stringer.
func (pc PositionChange) String() string {
	return fmt.Sprintf("%s; %d to %d (%v)", pc.Label, pc.Position.Control(), pc.Desired.Control(), pc.Rate)
}

// Done returns the done channel.
func (pc PositionChange) Done() bool {
	return *pc.Position == pc.Desired
}

// Simulate applies a simulation tick.
func (pc *PositionChange) Simulate(quantum time.Duration) error {
	pc.Rate.Affect(pc.Position, quantum)
	if pc.Rate.IsAdditive() && (*pc.Position > pc.Desired) {
		*pc.Position = pc.Desired
	} else if !pc.Rate.IsAdditive() && (*pc.Position < pc.Desired) {
		*pc.Position = pc.Desired
	}
	return nil
}
