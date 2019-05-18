package reactor

import (
	"fmt"
	"math"
	"strconv"
	"strings"
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

// FormatFields formats a fields set.
func FormatFields(fields map[string]string) string {
	var pairs []string
	for key, value := range fields {
		pairs = append(pairs, fmt.Sprintf("%s=%s", key, value))
	}
	return strings.Join(pairs, " ")
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

// RoundMillis rounds a given duration to milliseconds
func RoundMillis(d time.Duration) time.Duration {
	millis := int64(d) / int64(time.Millisecond)
	return time.Duration(millis) * time.Millisecond
}

// ParseValue parses string as an int, and applies a given validator.
func ParseValue(validator func(int) error, value string) (int, error) {
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, err
	}

	if validator != nil {
		if err := validator(parsed); err != nil {
			return 0, err
		}
	}
	return parsed, nil
}

// ParseValues parses a list of strings as ints, and applies a given validator.
func ParseValues(validator func(int) error, values ...string) ([]int, error) {
	output := make([]int, len(values))
	for index, value := range values {
		parsed, err := strconv.Atoi(value)
		if err != nil {
			return nil, err
		}

		if validator != nil {
			if err := validator(parsed); err != nil {
				return nil, err
			}
		}
		output[index] = parsed
	}
	return output, nil
}

// ParseCommand splits a raw command into a command and arguments.
func ParseCommand(rawCommand string) (command string, args []string) {
	parts := strings.Split(rawCommand, " ")
	if len(parts) > 0 {
		command = parts[0]
	} else {
		command = rawCommand
	}

	if len(parts) > 1 {
		args = parts[1:]
	}
	return
}

// Between returns if a value is between the given min and max.
func Between(min, max int) func(int) error {
	return func(v int) error {
		if v < min || v > max {
			return fmt.Errorf("validation error: %d is not between %d and %d", v, min, max)
		}
		return nil
	}
}

// Below returns if a value is below a given maximum.
func Below(max int) func(int) error {
	return func(v int) error {
		if v >= max {
			return fmt.Errorf("validation error: %d is not below %d", v, max)
		}
		return nil
	}
}

// ValidUint8 returns a validator for uint8s.
func ValidUint8(v int) error {
	return Between(0, int(math.MaxUint8))(v)
}
