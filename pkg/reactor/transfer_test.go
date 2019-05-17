package reactor

import (
	"testing"
	"time"

	"github.com/blend/go-sdk/assert"
)

func TestTransfer(t *testing.T) {
	assert := assert.New(t)

	from := 100.0
	to := 10.0
	quantum := 500 * time.Millisecond
	rate := 1000.0

	Transfer(&from, &to, quantum, rate)
	assert.Equal(55, from)
	assert.Equal(55, to)
}
