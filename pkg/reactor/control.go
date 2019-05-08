package reactor

import (
	"context"
	"errors"
)

// DialControl is a control that can be set on a semi-continuous range from 0 to 1.
type DialControl struct {
	Value float64
}

// Set sets the control value.
func (dc *DialControl) Set(ctx context.Context, desired float64) error {
	dc.Value = desired
}

// SwitchControl is a
type SwitchControl struct {
	Value bool
}

func (sc *SwitchControl) Set(ctx context.Context, desired bool) 
