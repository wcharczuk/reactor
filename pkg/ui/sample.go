package ui

import "time"

// Sample is a history graph value.
type Sample struct {
	Timestamp time.Time
	Value     float64
}
