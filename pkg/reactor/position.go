package reactor

// PositionFromControl returns a position value from a control value.
func PositionFromControl(control uint8) Position {
	return Position(float64(control) / 255)
}

// Position is a 0-255 value for a given control.
type Position float64

// Control returns the uint8 (i.e. 0-255) value for a position.
func (p Position) Control() uint8 {
	return uint8(p * 255)
}

// Percent is the ratio * 100.
func (p Position) Percent() float64 {
	return float64(p) * 100
}
