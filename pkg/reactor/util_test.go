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

func TestRollFailureFromProvider(t *testing.T) {
	assert := assert.New(t)

	fatal := func() float64 {
		return 0.9
	}
	critical := func() float64 {
		return 0.7
	}
	warning := func() float64 {
		return 0.1
	}
	none := func() float64 {
		return 0.01
	}

	assert.False(RollFailureFromProvider(none, FailureProbability(SeverityFatal), time.Minute))
	assert.False(RollFailureFromProvider(warning, FailureProbability(SeverityFatal), time.Minute))
	assert.False(RollFailureFromProvider(critical, FailureProbability(SeverityFatal), time.Minute))
	assert.True(RollFailureFromProvider(fatal, FailureProbability(SeverityFatal), time.Minute))

	assert.False(RollFailureFromProvider(none, FailureProbability(SeverityCritical), time.Minute))
	assert.False(RollFailureFromProvider(warning, FailureProbability(SeverityCritical), time.Minute))
	assert.True(RollFailureFromProvider(critical, FailureProbability(SeverityCritical), time.Minute))
	assert.True(RollFailureFromProvider(fatal, FailureProbability(SeverityCritical), time.Minute))

	assert.False(RollFailureFromProvider(none, FailureProbability(SeverityWarning), time.Minute))
	assert.True(RollFailureFromProvider(warning, FailureProbability(SeverityWarning), time.Minute))
	assert.True(RollFailureFromProvider(critical, FailureProbability(SeverityWarning), time.Minute))
	assert.True(RollFailureFromProvider(fatal, FailureProbability(SeverityWarning), time.Minute))
}

func TestTransfer(t *testing.T) {
	assert := assert.New(t)

	from := 100.0
	to := 10.0
	quantum := 500 * time.Millisecond
	rate := 1000.0

	Transfer(&from, &to, rate, quantum)
	assert.Equal(55, from)
	assert.Equal(55, to)
}
