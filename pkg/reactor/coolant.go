package reactor

import "time"

//
// utilities
//

// CoolantMap applies a map function to a pool of water.
func CoolantMap(pool []*Water, action func(*Water)) {
	poolCount := len(pool)
	for x := 0; x < poolCount; x++ {
		action(pool[x])
	}
}

// CoolantAverage averages the temperature values in a coolant flow.
func CoolantAverage(pool []*Water) float64 {
	poolCount := len(pool)
	var accum float64
	CoolantMap(pool, func(w *Water) {
		accum += w.Temp
	})
	return accum / float64(poolCount)
}

// CoolantHeatTransfer transfers heat from a source into the pool given as a chanel of water.
func CoolantHeatTransfer(pool []*Water, sourceTemp *float64, rate float64, quantum time.Duration) {
	poolCount := len(pool)
	effectiveRate := rate / float64(poolCount)
	CoolantMap(pool, func(w *Water) {
		Transfer(sourceTemp, &w.Temp, effectiveRate, quantum)
	})
}

// NewCoolant returns a new coolant cell.
func NewCoolant() *Coolant {
	c := &Coolant{
		Water: make([]*Water, 1024),
	}
	for x := 0; x < 1024; x++ {
		c.Water[x] = NewWater()
	}
	return c
}

// Coolant is a pool of water in a tube.
type Coolant struct {
	Water []*Water
}

// Push pushes a block of water through the loop.
// It first pulls water out of the loop, and then adds water passed in one by one.
func (c *Coolant) Push(water ...*Water) {
	c.Water = append(c.Water, water...)
}

// Pull removes water from the coolant line.
func (c *Coolant) Pull(count int) []*Water {
	if count < len(c.Water) {
		pulled := c.Water[:count]
		c.Water = c.Water[count:]
		return pulled
	}

	pulled := c.Water
	c.Water = nil
	return pulled
}
