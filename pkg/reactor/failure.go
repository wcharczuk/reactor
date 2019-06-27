package reactor

import (
	"math/rand"
	"time"
)

// RollFailure rolls a failure probability with the stdlib random provider.
func RollFailure(probability float64, quantum time.Duration) bool {
	return RollFailureFromProvider(rand.Float64, probability, quantum)
}

// RollFailureFromProvider rolls a failure probability with a given random provider.
func RollFailureFromProvider(randomProvider func() float64, probability float64, quantum time.Duration) bool {
	probability = probability / (float64(quantum) / float64(time.Minute))
	return randomProvider() >= probability
}

// FailureProbability returns a failure probability based on an alarm severity.
func FailureProbability(severity Severity) float64 {
	switch severity {
	case SeverityFatal:
		return 0.8
	case SeverityCritical:
		return 0.2
	case SeverityWarning:
		return 0.05
	default:
		return 0
	}
}
