package reactor

// Alarm is a thing that can fail.
type Alarm interface {
	Severity() string
}
