package reactor

import (
	"testing"
	"time"

	"github.com/blend/go-sdk/assert"
)

func TestObservable(t *testing.T) {
	assert := assert.New(t)

	fatal := 100.0
	critical := 50.0
	warn := 10.0

	innerProvider := SeverityThreshold(fatal, critical, warn)

	var value float64
	outerProvider := func() Severity {
		return innerProvider(value)
	}
	obs := NewObservable(outerProvider)

	assert.Equal(SeverityNone, obs.ValueProvider())
	assert.False(obs.New())

	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityNone, obs.ValueProvider())
	assert.False(obs.New())

	value = 20.0
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityWarning, obs.ValueProvider())
	assert.True(obs.New())
	obs.Seen()
	assert.False(obs.New())
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityWarning, obs.ValueProvider())
	assert.False(obs.New())

	value = 60.0
	assert.Equal(SeverityWarning, obs.previous)
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityCritical, obs.previous)
	assert.Equal(SeverityCritical, obs.ValueProvider())
	assert.True(obs.New())
	obs.Seen()
	assert.False(obs.New())
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityCritical, obs.ValueProvider())
	assert.False(obs.New())

	value = 110.0
	assert.Equal(SeverityCritical, obs.previous)
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityFatal, obs.previous)
	assert.Equal(SeverityFatal, obs.ValueProvider())
	assert.True(obs.New())
	obs.Seen()
	assert.False(obs.New())
	assert.Nil(obs.Simulate(time.Millisecond))
	assert.Equal(SeverityFatal, obs.ValueProvider())
	assert.False(obs.New())
}
