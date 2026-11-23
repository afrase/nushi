package e2e

import (
	"testing"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/testcheck"
)

// An app whose stream ends (here its daemon stops) has its events end
// with the stream's error, so a wait on them fails at once saying why,
// not by timing out on an event that can no longer come.
func TestAnAppsEventsEndWithTheirStream(t *testing.T) {
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	d.stop()
	ended := make(chan struct{})
	go func() {
		for range a.events { // whatever came before the stop
		}
		close(ended)
	}()
	testcheck.Wait(t, "the app's events to end", func() bool {
		select {
		case <-ended:
			return true
		default:
			return false
		}
	})
	if a.ended == nil {
		t.Error("the events ended without the stream's error")
	}
}
