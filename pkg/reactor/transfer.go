package reactor

import (
	"time"
)

// Transfer moves quantity from one value to another given a rate and quantum.
func Transfer(from, to *float64, rate float64, quantum time.Duration) {
	quantumFraction := float64(quantum) / float64(time.Minute)
	effectiveRate := rate * quantumFraction
	delta := (*from - *to)

	transferred := delta * effectiveRate
	if transferred > delta {
		transferred = delta
	}

	*from = *from - (transferred / 2.0)
	*to = *to + (transferred / 2.0)
}
