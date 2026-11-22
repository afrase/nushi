package transcripts

import (
	"errors"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// While one chat's copy work holds its lock, another chat's goes on, and
// List takes no lock at all: one chat's slow write (a long copy's rewrite,
// an image's fsync) holds up no other.
func TestOneChatHoldsUpNoOther(t *testing.T) {
	s, _ := open(t)
	add(t, s, "a", "", msg("a1", "one"))
	add(t, s, "b", "", msg("b1", "one"))
	held := s.lock("a") // as a slow write of chat a holds it
	defer held.Unlock()
	done := make(chan error, 1)
	go func() {
		err := s.Append("b", []model.Item{msg("b2", "two")}, []string{"b1"})
		if err == nil {
			_, err = s.Read("b")
		}
		if err == nil {
			_, err = s.Heads("b")
		}
		if err == nil {
			_, err = s.List()
		}
		if err == nil && !s.Has("a") {
			err = errors.New("chat a's copy isn't seen")
		}
		done <- err
	}()
	var err error
	if !testcheck.Eventually(func() bool {
		select {
		case err = <-done:
			return true
		default:
			return false
		}
	}) {
		t.Fatal("chat b waited on chat a's lock")
	}
	testcheck.NoErr(t, err)
}
