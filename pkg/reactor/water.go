package reactor

// FillWater fills a container with water.
func FillWater(units int) chan *Water {
	container := make(chan *Water, units)
	for x := 0; x < units; x++ {
		container <- NewWater()
	}
	return container
}

// NewWater returns a new water instance.
func NewWater() *Water {
	return &Water{
		Temp: DefaultBaseTemp,
	}
}

// Water is a unit of water.
type Water struct {
	Temp          float64
	SteamFraction float64
}
