package reflectutil

import "strings"

// IsExported returns if a field is exported given its name and capitalization.
func IsExported(fieldName string) bool {
	return fieldName != "" && strings.ToUpper(fieldName)[0] == fieldName[0]
}
