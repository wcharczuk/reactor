package reactor

import (
	"fmt"
	"math"
	"time"
)

// Percent returns the percent of the maximum of a given value.
func Percent(value uint8) int {
	return int((float64(value) / float64(math.MaxUint8)) * 100)
}

// FormatOutput formats the output.
func FormatOutput(output float64) string {
	if output > 1000*1000 {
		return fmt.Sprintf("%.2fgw/hr", output/(1000*1000))
	}
	if output > 1000 {
		return fmt.Sprintf("%.2fmw/hr", output/1000)
	}
	return fmt.Sprintf("%.2fkw/hr", output)
}

// RelativeQuantum returns a normalized quantum based on a from and to position change.
func RelativeQuantum(from, to, max float64, quantum time.Duration) time.Duration {
	if from == to {
		return 0
	}

	var a, b float64
	if from > to {
		a = from
		b = to
	} else {
		a = to
		b = from
	}

	delta := a - b
	pctChange := delta / max
	return time.Duration(pctChange * float64(quantum))
}
