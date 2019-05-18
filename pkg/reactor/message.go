package reactor

import (
	"fmt"
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
	if lm.Fields != nil {
		return fmt.Sprintf("%-7s %s %#v", lm.Timestamp.Format(MessageTimeFormat), lm.Text, FormatFields(lm.Fields))
	}
	return fmt.Sprintf("%-7s %s", lm.Timestamp.Format(MessageTimeFormat), lm.Text)
}
