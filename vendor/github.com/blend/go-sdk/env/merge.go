package env

// Merge merges a given set of environment variables.
func Merge(sets ...Vars) Vars {
	output := Vars{}
	for _, set := range sets {
		for key, value := range set {
			output[key] = value
		}
	}
	return output
}
