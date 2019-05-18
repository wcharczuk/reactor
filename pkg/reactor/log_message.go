package reactor

import (
	"fmt"
	"strings"
	"time"
)

var (
	// MessageTimeFormat is the message time format.
	MessageTimeFormat = "3:04:05PM"
)

// LogMessage is a log message.
type LogMessage struct {
	Timestamp time.Time
	Text      string
	Fields    map[string]string
}

func (lm LogMessage) String() string {
	var parts []string
	if !lm.Timestamp.IsZero() {
		parts = append(parts, fmt.Sprintf("%-7s", lm.Timestamp.Format(MessageTimeFormat)))
	}
	parts = append(parts, lm.Text)
	if lm.Fields != nil {
		parts = append(parts, FormatFields(lm.Fields))
	}
	return strings.Join(parts, " ")
}
