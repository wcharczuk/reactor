package ui

import "image"

// RelativeRect returns an absolute rect from a relative position and height and width.
func RelativeRect(x, y, width, height int) (x0, y0, x1, y1 int) {
	x0 = x
	y0 = y
	x1 = x + width
	y1 = y + height
	return
}

// RectProvider is a type that provides a rectange through GetRect().
type RectProvider interface {
	GetRect() image.Rectangle
}

// Width returns the width from a rect provider.
func Width(c RectProvider) int {
	return c.GetRect().Dx()
}

// Height returns the height of a rect provider.
func Height(c RectProvider) int {
	return c.GetRect().Dy()
}
