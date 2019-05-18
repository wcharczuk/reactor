package timeutil

import (
	"math"
	"time"
)

// Milliseconds returns a duration as milliseconds.
func Milliseconds(d time.Duration) float64 {
	return float64(d) / float64(time.Millisecond)
}

// FromMilliseconds returns a duration from a given float64 millis value.
func FromMilliseconds(millis float64) time.Duration {
	// we use a `math.Ceil` here to avoid floating point precision issues.
	// it will add, at most, a nanosecond error to the calculation.
	return time.Duration(math.Ceil(millis * float64(time.Millisecond)))
}
