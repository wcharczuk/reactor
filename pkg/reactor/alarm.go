package reactor

// Alarm is a thing that can fail.
type Alarm interface {
	Active() bool
	Severity() string
	String() string
}
