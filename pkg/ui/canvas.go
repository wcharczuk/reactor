package ui

import "fmt"

// NewCanvas returns a new canvas.
func NewCanvas(height, width int) Canvas {
	return Canvas{
		Height: height,
		Width:  width,
	}
}

// Canvas is the rendering canvas.
type Canvas struct {
	Height, Width int
}

// Width2 returns half the width.
func (c Canvas) Width2() int { return c.Width >> 1 }

// Height2 returns half the height.
func (c Canvas) Height2() int { return c.Height >> 1 }

// RowHeight returns the height of a row.
func (c Canvas) RowHeight() int { return 3 }

// ColWidth returns the width of a single column.
func (c Canvas) ColWidth() int { return c.Width / 12 }

// Row returns the offset of a row by index, starting with 0 as the top most.
func (c Canvas) Row(i int) int {
	if i < 0 {
		panic(fmt.Sprintf("canvas; invalid row, must be greater than 0; %d", i))
	}
	return i * c.RowHeight()
}

// Col returns the offset of a given column.
func (c Canvas) Col(i int) int {
	if i < 0 || i > 11 {
		panic(fmt.Sprintf("canvas; invalid column, must be between 0 and 11; %d", i))
	}
	return i * c.ColWidth()
}

// Cols returns a single row with a given width in 12ths of a window.
func (c Canvas) Cols(top, left, cols int) (x0, y0, x1, y1 int) {
	x0 = left
	y0 = top
	x1 = left + c.Col(cols)
	y1 = top + c.RowHeight()
	return
}
