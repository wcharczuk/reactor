package reactor

import (
	"testing"
	"time"

	"github.com/blend/go-sdk/assert"
)

func TestRelativeQuantum(t *testing.T) {
	assert := assert.New(t)

	res := RelativeQuantum(1.0, 0, 1.0, time.Second)
	assert.Equal(time.Second, res)

	res = RelativeQuantum(0, 1.0, 1.0, time.Second)
	assert.Equal(time.Second, res)

	res = RelativeQuantum(0, 0.5, 1.0, time.Second)
	assert.Equal(500*time.Millisecond, res)

	res = RelativeQuantum(0.5, 0, 1.0, time.Second)
	assert.Equal(500*time.Millisecond, res)

	res = RelativeQuantum(0.5, 0.5, 1.0, time.Second)
	assert.Zero(res)
}
