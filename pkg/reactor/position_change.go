package reactor

import "time"

// NewPositionChange returns a new position change.
func NewPositionChange(position *Position, desired Position, quantum time.Duration) *PositionChange {
	return &PositionChange{
		Position: position,
		Desired:  desired,
		Original: *position,
		Rate: PositionRate{
			Delta:   int16(*position) - int16(desired),
			Quantum: quantum,
		},
		done: make(chan struct{}),
	}
}

// PositionChange change is a change to a position.
type PositionChange struct {
	Position *Position
	Desired  Position
	Original Position
	Rate     PositionRate
	done     chan struct{}
}

// Done returns the done channel.
func (pc *PositionChange) Done() bool {
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
