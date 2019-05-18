package timeutil

import "time"

// Min returns the earliest (min) time in a list of times.
func Min(times ...time.Time) (min time.Time) {
	if len(times) == 0 {
		return
	}

	min = times[0]
	for _, t := range times[1:] {
		if t.Before(min) {
			min = t
		}
	}
	return
}
