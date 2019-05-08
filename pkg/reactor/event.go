package reactor

// Event is something that can be simulated and notifies when it's done.
type Event interface {
	Simulatable
	Done() bool
}
