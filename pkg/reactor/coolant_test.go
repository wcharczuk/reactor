package reactor

import (
	"testing"

	"github.com/blend/go-sdk/assert"
)

func TestCoolant(t *testing.T) {
	assert := assert.New(t)

	src := NewCoolant()
	water := src.Pull(10)
	assert.Len(water, 10)
	assert.Len(src.Water, 1014)

	CoolantMap(water, func(w *Water) {
		w.Temp = w.Temp - 5.0
	})

	dst := NewCoolant()
	dst.Push(water...)
	assert.Len(dst.Water, 1034)
	assert.NotEqual(dst.Water[0], dst.Water[len(dst.Water)-1])
}
