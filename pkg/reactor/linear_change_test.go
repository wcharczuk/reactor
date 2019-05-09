package reactor

import (
	"testing"
	"time"

	"github.com/blend/go-sdk/assert"
)

func TestLinearChange(t *testing.T) {
	assert := assert.New(t)

	var position Position = 1.0
	rate := NewLinearChange(float64(position), 0.5, 5*time.Second)
	assert.False(rate.IsAdditive())

	rate.Affect(&position, 2500*time.Millisecond)
	assert.Equal(0.75, position)

	rate.Affect(&position, 2500*time.Millisecond)
	assert.Equal(0.5, position)
}
