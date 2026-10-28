package ante

import (
	"errors"
	"testing"
	"time"
)

// A turn ends once: a second end (a failed write to a host that is going,
// and the host's going) is dropped, where it blocked on the answered
// result while holding the session's lock.
func TestATurnEndsOnce(t *testing.T) {
	s := &session{}
	tr := &turn{result: make(chan turnResult, 1)}
	s.mu.Lock()
	s.beginLocked(tr)
	s.endLocked(tr, nil, errors.New("Ante's host stopped before the turn ended"))
	s.mu.Unlock()
	again := make(chan struct{})
	go func() {
		s.mu.Lock()
		defer s.mu.Unlock()
		s.endLocked(tr, nil, errors.New("writing to Ante's host"))
		close(again)
	}()
	select {
	case <-again:
	case <-time.After(5 * time.Second):
		t.Fatal("a second end blocked")
	}
	if r := <-tr.result; r.err == nil || r.err.Error() != "Ante's host stopped before the turn ended" {
		t.Errorf("the turn ended with %v", r.err)
	}
}
