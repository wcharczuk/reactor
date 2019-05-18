package logger

import (
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/blend/go-sdk/ansi"
	"github.com/blend/go-sdk/stringutil"
	"github.com/blend/go-sdk/webutil"
)

// WriteHTTPRequest is a helper method to write request start events to a writer.
func WriteHTTPRequest(tf TextFormatter, wr io.Writer, req *http.Request) {
	if ip := webutil.GetRemoteAddr(req); len(ip) > 0 {
		io.WriteString(wr, ip)
		io.WriteString(wr, Space)
	}
	io.WriteString(wr, tf.Colorize(req.Method, ansi.ColorBlue))
	io.WriteString(wr, Space)
	io.WriteString(wr, req.URL.Path)
}

// WriteHTTPResponse is a helper method to write request complete events to a writer.
func WriteHTTPResponse(tf TextFormatter, wr io.Writer, req *http.Request, statusCode, contentLength int, contentType string, elapsed time.Duration) {
	io.WriteString(wr, webutil.GetRemoteAddr(req))
	io.WriteString(wr, Space)
	io.WriteString(wr, tf.Colorize(req.Method, ansi.ColorBlue))
	io.WriteString(wr, Space)
	io.WriteString(wr, req.URL.String())
	io.WriteString(wr, Space)
	io.WriteString(wr, ColorizeStatusCode(statusCode))
	io.WriteString(wr, Space)
	io.WriteString(wr, elapsed.String())
	if len(contentType) > 0 {
		io.WriteString(wr, Space)
		io.WriteString(wr, contentType)
	}
	io.WriteString(wr, Space)
	io.WriteString(wr, stringutil.FileSize(contentLength))
}

// WriteFields writes fields.
func WriteFields(tf TextFormatter, wr io.Writer, fields map[string]string) {
	for key, value := range fields {
		io.WriteString(wr, fmt.Sprintf("%s=%s", key, value))
	}
}

// MergeDecomposed merges sets of decomposed data.
func MergeDecomposed(sets ...map[string]interface{}) map[string]interface{} {
	output := make(map[string]interface{})
	for _, set := range sets {
		for key, value := range set {
			output[key] = value
		}
	}
	return output
}
