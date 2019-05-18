package configutil

import (
	"os"

	"github.com/blend/go-sdk/ex"
)

const (
	// ErrConfigPathUnset is a common error.
	ErrConfigPathUnset = ex.Class("config path unset")

	// ErrInvalidConfigExtension is a common error.
	ErrInvalidConfigExtension = ex.Class("config extension invalid")
)

// IsIgnored returns if we should ignore the config read error.
func IsIgnored(err error) bool {
	if err == nil {
		return true
	}
	if IsNotExist(err) || IsConfigPathUnset(err) || IsInvalidConfigExtension(err) {
		return true
	}
	return false
}

// IsNotExist returns if an error is an os.ErrNotExist.
func IsNotExist(err error) bool {
	if err == nil {
		return false
	}
	if typed, ok := err.(*ex.Ex); ok && typed != nil {
		err = typed.Class
	}
	return os.IsNotExist(err)
}

// IsConfigPathUnset returns if an error is an ErrConfigPathUnset.
func IsConfigPathUnset(err error) bool {
	return ex.Is(err, ErrConfigPathUnset)
}

// IsInvalidConfigExtension returns if an error is an ErrInvalidConfigExtension.
func IsInvalidConfigExtension(err error) bool {
	return ex.Is(err, ErrInvalidConfigExtension)
}
