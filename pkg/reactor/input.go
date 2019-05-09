package reactor

// Input is something that can be simulated and notifies when it's done.
type Input interface {
	Simulatable
	Done() bool
}
