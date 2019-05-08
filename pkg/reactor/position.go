package reactor

// Position is a 0-255 value for a given control.
type Position uint8

// Ratio is the ratio of the given value to the maximum.
func (p Position) Ratio() float64 {
	return float64(uint8(p) / Max8)
}

// Percent is the ratio * 100.
func (p Position) Percent() float64 {
	return p.Ratio() * 100
}
