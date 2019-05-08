package reactor

import "time"

// Simulatable is something that can be simulated.
type Simulatable interface {
	Simulate(time.Duration) error
}
