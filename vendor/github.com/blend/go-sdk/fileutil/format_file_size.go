package fileutil

import "strconv"

const (
	// Kilobyte represents the bytes in a kilobyte.
	Kilobyte int64 = 1 << 10
	// Megabyte represents the bytes in a megabyte.
	Megabyte int64 = Kilobyte << 10
	// Gigabyte represents the bytes in a gigabyte.
	Gigabyte int64 = Megabyte << 10
	//Terrabyte represents the bytes in a terrabyte.
	Terrabyte int64 = Gigabyte << 10
)

// FormatFileSize returns a string representation of a file size in bytes.
func FormatFileSize(sizeBytes int64) string {
	if sizeBytes >= 1<<40 {
		return strconv.FormatInt(sizeBytes/Terrabyte, 10) + "tb"
	} else if sizeBytes >= 1<<30 {
		return strconv.FormatInt(sizeBytes/Gigabyte, 10) + "gb"
	} else if sizeBytes >= 1<<20 {
		return strconv.FormatInt(sizeBytes/Megabyte, 10) + "mb"
	} else if sizeBytes >= 1<<10 {
		return strconv.FormatInt(sizeBytes/Kilobyte, 10) + "kb"
	}
	return strconv.FormatInt(sizeBytes, 10)
}
