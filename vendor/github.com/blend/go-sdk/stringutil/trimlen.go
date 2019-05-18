package stringutil

// TrimLen trims a string to a given length, i.e. the substring [0, length).
func TrimLen(val string, length int) string {
	if len(val) > length {
		return val[0:length]
	}
	return val
}
