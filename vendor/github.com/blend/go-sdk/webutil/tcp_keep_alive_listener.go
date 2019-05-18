package webutil

import (
	"net"
	"time"
)

var (
	_ net.Listener = (*TCPKeepAliveListener)(nil)
)

// TCPKeepAliveListener sets TCP keep-alive timeouts on accepted
// connections. It's used by ListenAndServe and ListenAndServeTLS so
// dead TCP connections (e.g. closing laptop mid-download) eventually
// go away.
// Taken from net/http/server.go
type TCPKeepAliveListener struct {
	*net.TCPListener

	KeepAlive       bool
	KeepAlivePeriod time.Duration
}

// Accept implements net.Listener
func (ln TCPKeepAliveListener) Accept() (c net.Conn, err error) {
	tc, err := ln.AcceptTCP()
	if err != nil {
		return
	}
	tc.SetKeepAlive(ln.KeepAlive)
	tc.SetKeepAlivePeriod(ln.KeepAlivePeriod)
	return tc, nil
}
