package reactor

import (
	"math"
	"time"
)

// Percent returns the percent of the maximum of a given value.
func Percent(value uint8) int {
	return int((float64(value) / float64(math.MaxUint8)) * 100)
}

// Transfer moves quantity from one value to another given a rate and quantum.
func Transfer(from, to *uint16, quantum time.Duration, rate float64) {
	transferRate := rate * float64(quantum/time.Minute)
	tempDelta := *from - *to
	transferred := uint16(float64(tempDelta) * transferRate)
	*from = *from - transferred
	*to = *to + transferred
}

// Const returns a constant version of a value.
func Const(value uint16) *uint16 {
	return &value
}
