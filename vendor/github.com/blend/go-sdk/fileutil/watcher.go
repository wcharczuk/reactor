package fileutil

import (
	"os"
	"time"

	"github.com/blend/go-sdk/async"
	"github.com/blend/go-sdk/ex"
)

// Watch constants
const (
	ErrWatchStopped          ex.Class = "watch file should stop"
	DefaultWatchPollInterval          = 500 * time.Millisecond
)

// Watch watches a file for changes and calls the action if there are changes.
// It does this by polling the file for ModTime changes every 500ms.
// It is not designed for watching a large number of files.
// You should probably call this with its own goroutine.
func Watch(path string, action WatchAction) error {
	errors := make(chan error, 1)
	w := NewWatcher(path, action)
	w.Errors = errors
	w.Starting()
	w.Watch()
	if len(errors) > 0 {
		return <-errors
	}
	return nil
}

// NewWatcher returns a new watcher.
func NewWatcher(path string, action WatchAction, opts ...WatcherOption) *Watcher {
	watch := Watcher{
		Latch:  async.NewLatch(),
		Path:   path,
		Action: action,
	}
	for _, opt := range opts {
		opt(&watch)
	}
	return &watch
}

// WatchAction is an action for the file watcher.
type WatchAction func(*os.File) error

// WatcherOption is an option for a watcher.
type WatcherOption func(*Watcher) error

// Watcher watches a file for changes and calls the action.
type Watcher struct {
	*async.Latch

	Path         string
	PollInterval time.Duration
	Action       func(*os.File) error
	Errors       chan error
}

// PollIntervalOrDefault returns the polling interval or a default.
func (w Watcher) PollIntervalOrDefault() time.Duration {
	if w.PollInterval > 0 {
		return w.PollInterval
	}
	return DefaultWatchPollInterval
}

// Watch watches a given file.
func (w Watcher) Watch() {
	stat, err := os.Stat(w.Path)
	if err != nil {
		w.handleError(err)
		return
	}

	w.Started()
	lastMod := stat.ModTime()
	ticker := time.Tick(w.PollIntervalOrDefault())
	for {
		select {
		case <-ticker:
			stat, err = os.Stat(w.Path)
			if err != nil {
				w.handleError(ex.New(err))
				return
			}
			if stat.ModTime().After(lastMod) {
				file, err := os.Open(w.Path)
				if err != nil {
					w.handleError(err)
					return
				}
				if err := w.Action(file); err != nil {
					if ex.Is(err, ErrWatchStopped) {
						return
					}
					w.handleError(ex.New(err))
					return
				}
				lastMod = stat.ModTime()
			}
		case <-w.NotifyStopping():
			w.Stopped()
			return
		}
	}
}

func (w Watcher) handleError(err error) {
	if err == nil {
		return
	}
	if w.Errors != nil {
		w.Errors <- err
	}
}
