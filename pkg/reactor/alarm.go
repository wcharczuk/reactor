package reactor

import "fmt"

// Alarm is a thing that can fail.
type Alarm interface {
	fmt.Stringer
	Active() bool
	Severity() string
}
