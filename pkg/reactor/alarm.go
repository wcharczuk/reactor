package reactor

// Alarm is a thing that can fail.
type Alarm interface {
	Simulatable

	New() bool
	Seen()
	Severity() Severity
	String() string
}
