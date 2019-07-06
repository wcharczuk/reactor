package ui

import (
	"github.com/wcharczuk/reactor/pkg/reactor"
	"github.com/wcharczuk/termui"
)

// firstRune returns the first rune should be trimmed, otherwise false.
func firstRune() func(r rune) bool {
	var done bool
	return func(r rune) bool {
		if !done {
			done = true
			return true
		}
		return false
	}
}

// escapeInput escapes the input.
func escapeInput(value string) string {
	switch value {
	case "<Space>":
		return " "
	case "<Enter>", "<MouseLeft>", "<MouseRight>", "<MouseRelease>", "<Resize>":
		return ""
	default:
		return value
	}
}

func severity(severity reactor.Severity) (background, foreground termui.Color) {
	switch severity {
	case reactor.SeverityFatal:
		{
			background = termui.ColorMagenta
			foreground = termui.ColorWhite
			return
		}
	case reactor.SeverityCritical:
		{
			background = termui.ColorRed
			foreground = termui.ColorBlack
			return
		}
	case reactor.SeverityWarning:
		{
			background = termui.ColorYellow
			foreground = termui.ColorBlack
			return
		}
	default:
		background = termui.ColorClear
		foreground = termui.ColorWhite
		return
	}
}
