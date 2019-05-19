package reactor

import (
	"image"
	"strings"
)

// NewNotice returtns a new notice.
func NewNotice(severity, heading string, messageLines ...string) Notice {
	var width int
	for _, line := range messageLines {
		if width < len(line) {
			width = len(line)
		}
	}
	height := len(messageLines)
	return Notice{
		Rectangle: image.Rect(0, 0, width, height),
		Severity:  severity,
		Heading:   heading,
		Lines:     messageLines,
	}
}

// Notice is an alert or info message.
type Notice struct {
	image.Rectangle
	Severity string
	Heading  string
	Lines    []string
}

// Message returns the notice message body.
func (n Notice) Message() string {
	return strings.Join(n.Lines, "\n")
}
