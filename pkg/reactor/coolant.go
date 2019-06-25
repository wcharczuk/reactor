package reactor

// NewCoolant returns a new coolant cell.
func NewCoolant() *Coolant {
	c := &Coolant{
		Water: make(chan *Water, 1024),
	}
	for x := 0; x < 1024; x++ {
		c.Water <- NewWater()
	}
	return c
}

// Coolant is a pool of water in a tube.
type Coolant struct {
	Water chan *Water
}

// Push pushes a block of water through the loop.
// It first pulls water out of the loop, and then adds water passed in one by one.
func (c *Coolant) Push(water ...*Water) {
	moved := make([]*Water, len(water))
	for x := 0; x < len(water); x++ {
		moved = append(moved, <-c.Water)
		c.Water <- water[x]
	}
}

// Pull removes water from the coolant line.
func (c *Coolant) Pull(count int) []*Water {
	var pulled []*Water
	for x := 0; x < count; x++ {
		pulled = append(pulled, <-c.Water)
	}
	return pulled
}
