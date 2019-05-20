package reactor

import "time"

var (
	_ Simulatable = (*BoolObserver)(nil)
)

// NewBoolObserver returns a new Observer.
func NewBoolObserver(valueProvider func() bool) *BoolObserver {
	return &BoolObserver{
		valueProvider: valueProvider,
	}
}

// BoolObserver is a supervisor for a string value provider.
type BoolObserver struct {
	previous      bool
	new           bool
	valueProvider func() bool
}

// Value returns the value from the value provider.
func (bo *BoolObserver) Value() bool {
	return bo.valueProvider()
}

// New returns if the Observer is new or not.
func (bo *BoolObserver) New() bool {
	return bo.new
}

// Seen marks an Observer as seen.
func (bo *BoolObserver) Seen() {
	bo.new = false
}

// Simulate applies a simulation tick.
func (bo *BoolObserver) Simulate(quantum time.Duration) error {
	newValue := bo.valueProvider()
	if newValue != bo.previous {
		bo.new = true
	}
	bo.previous = newValue
	return nil
}
