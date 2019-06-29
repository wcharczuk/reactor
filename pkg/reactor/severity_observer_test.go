package reactor

import (
	"testing"
	"time"

	"github.com/blend/go-sdk/assert"
)

func TestSeverityObserver(t *testing.T) {
	assert := assert.New(t)

	fatal := 100.0
	critical := 50.0
	warn := 10.0

	innerProvider := Thresholds(fatal, critical, warn)

	var value float64
	outerProvider := func() Severity {
		return innerProvider(value)
	}
	obs := NewSeverityObserver(outerProvider)

	assert.Equal(SeverityNone, obs.Value())
	assert.False(obs.New())

	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityNone, obs.Value())
	assert.False(obs.New())

	value = 20.0
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityWarning, obs.Value())
	assert.True(obs.New())
	obs.Seen()
	assert.False(obs.New())
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityWarning, obs.Value())
	assert.False(obs.New())

	value = 60.0
	assert.Equal(SeverityWarning, obs.previous)
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityCritical, obs.previous)
	assert.Equal(SeverityCritical, obs.Value())
	assert.True(obs.New())
	obs.Seen()
	assert.False(obs.New())
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityCritical, obs.Value())
	assert.False(obs.New())

	value = 110.0
	assert.Equal(SeverityCritical, obs.previous)
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityFatal, obs.previous)
	assert.Equal(SeverityFatal, obs.Value())
	assert.True(obs.New())
	obs.Seen()
	assert.False(obs.New())
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityFatal, obs.Value())
	assert.False(obs.New())
}
