package reactor

import (
	"fmt"
	"time"
)

var (
	// MessageTimeFormat is the message time format.
	MessageTimeFormat = "3:04:05PM"
)

// Message is a log message.
type Message struct {
	Timestamp time.Time
	Text      string
	Fields    map[string]string
}

func (m Message) String() string {
	if m.Fields != nil {
		return fmt.Sprintf("%-7s %s %#v", m.Timestamp.Format(MessageTimeFormat), m.Text, m.Fields)
	}
	return fmt.Sprintf("%-7s %s", m.Timestamp.Format(MessageTimeFormat), m.Text)
}
