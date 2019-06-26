package reactor

import "time"

// PositionChangeRate is a change in a position over time.
type PositionChangeRate interface {
	Affect(*Position, time.Duration)
	IsAdditive() bool
}
