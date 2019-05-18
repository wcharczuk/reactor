package timeutil

import "time"

// DiffHours returns the difference in hours between two times.
func DiffHours(t1, t2 time.Time) (hours int) {
	t1n := t1.Unix()
	t2n := t2.Unix()
	var diff int64
	if t1n > t2n {
		diff = t1n - t2n
	} else {
		diff = t2n - t1n
	}
	return int(diff / (SecondsPerHour))
}
