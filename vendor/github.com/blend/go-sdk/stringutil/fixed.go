package stringutil

import "fmt"

// Fixed returns a fixed width, right aligned, string with a given minimum space padded width.
func Fixed(text string, width int) string {
	fixedToken := fmt.Sprintf("%%%d.%ds", width, width)
	return fmt.Sprintf(fixedToken, text)
}

// FixedLeft returns a fixed width, left aligned, string with a given minimum space padded width.
func FixedLeft(text string, width int) string {
	if width < len(text) {
		return text[0:width]
	}
	fixedToken := fmt.Sprintf("%%-%ds", width)
	return fmt.Sprintf(fixedToken, text)
}
