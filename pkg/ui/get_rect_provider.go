package ui

import "image"

// GetRectProvider is a type that returns the rect bounding box.
type GetRectProvider interface {
	GetRect() image.Rectangle
}
