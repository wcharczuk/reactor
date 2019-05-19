package reactor

// Alarm is a thing that can fail.
type Alarm interface {
	New() bool
	Seen()

	Active() bool
	Severity() string
	String() string
}
