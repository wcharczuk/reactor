package reactor

import "fmt"

var (
	_ fmt.Stringer = (*Severity)(nil)
)

// Alarm Severity
const (
	SeverityNone     Severity = 0
	SeverityInfo     Severity = 1
	SeverityWarning  Severity = 2
	SeverityCritical Severity = 4
	SeverityFatal    Severity = 8
)

// ParseSeverity parses a string value for a severity.
func ParseSeverity(raw string) (Severity, error) {
	switch raw {
	case "NONE":
		return SeverityNone, nil
	case "INFO":
		return SeverityInfo, nil
	case "WARN":
		return SeverityWarning, nil
	case "CRITICAL":
		return SeverityCritical, nil
	case "FATAL":
		return SeverityFatal, nil
	default:
		return SeverityNone, fmt.Errorf("invalid severity value")
	}
}

// Severity is a class of alarm or error.
type Severity uint8

func (s Severity) String() string {
	switch s {
	case SeverityNone:
		return "NONE"
	case SeverityInfo:
		return "INFO"
	case SeverityWarning:
		return "WARN"
	case SeverityCritical:
		return "CRITICAL"
	case SeverityFatal:
		return "FATAL"
	default:
		return ""
	}
}
