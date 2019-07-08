package ui

import (
	"github.com/wcharczuk/termui"
	"github.com/wcharczuk/termui/widgets"
)

// ControlOption sets a control option.
type ControlOption func(termui.Drawable)

// OptText sets the text of a paragraph.
func OptText(text string) ControlOption {
	return func(c termui.Drawable) {
		switch c.(type) {
		case *widgets.Paragraph:
			c.(*widgets.Paragraph).Text = text
		}
	}
}

// OptSetRect sets the rectangle on a drawable.
func OptSetRect(x0, y0, x1, y1 int) ControlOption {
	return func(c termui.Drawable) {
		c.SetRect(x0, y0, x1, y1)
	}
}

// OptHeight sets the control height.
func OptHeight(height int) ControlOption {
	return func(c termui.Drawable) {
		current := c.GetRect()
		c.SetRect(current.Min.X, current.Min.Y, current.Max.X, current.Min.Y+height)
	}

}
