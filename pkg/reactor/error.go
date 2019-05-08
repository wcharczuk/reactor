package reactor

// Error is a string error.
type Error string

// Error returns the error as a string.
func (e Error) Error() string {
	return string(e)
}
