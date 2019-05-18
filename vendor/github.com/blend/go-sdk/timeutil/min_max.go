package timeutil

import "time"

// MinMax returns the minimum and maximum times in a given range.
func MinMax(times ...time.Time) (min time.Time, max time.Time) {
	if len(times) == 0 {
		return
	}
	min = times[0]
	max = times[0]

	for index := 1; index < len(times); index++ {
		if times[index].Before(min) {
			min = times[index]
		}
		if times[index].After(max) {
			max = times[index]
		}
	}
	return
}
