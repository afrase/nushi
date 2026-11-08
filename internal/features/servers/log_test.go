package servers

import (
	"bytes"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// watched follows a server's log until it ends or stop closes, keeping
// what came.
type watched struct {
	mu    sync.Mutex
	data  bytes.Buffer
	ended bool
	err   error
	done  chan struct{}
}

func watch(s *Service, chat, id string, stop <-chan struct{}) *watched {
	w := &watched{done: make(chan struct{})}
	go func() {
		defer close(w.done)
		ended, err := s.Watch(chat, id, stop, func(b []byte) bool {
			w.mu.Lock()
			w.data.Write(b)
			w.mu.Unlock()
			return true
		})
		w.mu.Lock()
		w.ended, w.err = ended, err
		w.mu.Unlock()
	}()
	return w
}

func (w *watched) has(s string) bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	return strings.Contains(w.data.String(), s)
}

// A running server's log is what it wrote, escapes kept, then what it
// writes, then its end; an ended one's is what it kept.
func TestALogFollowsItsServer(t *testing.T) {
	p := freePort(t)
	s, _, _ := setup(t, entry("web", p, "-delay", "300ms"))
	r, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	if r.LogID != r.ServerID {
		t.Errorf("a started server's log: %+v", r)
	}
	w := watch(s, "c", r.ServerID, make(chan struct{}))
	if !testcheck.Eventually(func() bool { return w.has("fakeserver starting") && w.has("listening on "+strconv.Itoa(p)) }) {
		t.Fatalf("the log has %q", w.data.String())
	}
	testcheck.NoErr(t, s.Stop("c", r.ServerID))
	<-w.done
	if !w.ended || w.err != nil {
		t.Errorf("a stopped server's watch: ended %v, %v", w.ended, w.err)
	}
	ended := watch(s, "c", r.ServerID, make(chan struct{}))
	<-ended.done
	if !ended.ended || !ended.has("listening on") || !bytes.Equal(ended.data.Bytes(), w.data.Bytes()) {
		t.Errorf("an ended server's log: %q, ended %v, %v", ended.data.String(), ended.ended, ended.err)
	}
}

// A watch that stops early isn't an end.
func TestAWatchStops(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t)))
	r, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	row(t, s, "web", Running)
	stop := make(chan struct{})
	w := watch(s, "c", r.ServerID, stop)
	close(stop)
	<-w.done
	if w.ended || w.err != nil {
		t.Errorf("ended %v, %v", w.ended, w.err)
	}
}

// Only a server of the chat's folder has a log to give.
func TestALogIsTheFoldersOnly(t *testing.T) {
	s, chats, _ := setup(t, entry("web", freePort(t)))
	chats.set(model.ChatRecord{ID: "other", Folder: t.TempDir()})
	r, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	for _, c := range []struct{ chat, id string }{{"other", r.ServerID}, {"c", "nope"}, {"gone", r.ServerID}} {
		if _, err := s.Watch(c.chat, c.id, nil, func([]byte) bool { return true }); err == nil {
			t.Errorf("%s's %s: no error", c.chat, c.id)
		}
	}
}

// A failed server's row keeps its log, and one that never started has
// none.
func TestAFailedServerKeepsItsLog(t *testing.T) {
	s, _, _ := setup(t, entry("web", freePort(t), "-exit", "2"), `{"name": "gone", "runtimeExecutable": "no-such-program-here"}`)
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	if r := row(t, s, "web", Failed); r.LogID == "" {
		t.Errorf("failed: %+v", r)
	}
	if _, err := s.Start(t.Context(), "c", Pick{Name: "gone"}); err == nil {
		t.Fatal("a missing program started")
	}
	if r := row(t, s, "gone", Failed); r.LogID != "" {
		t.Errorf("never started: %+v", r)
	}
}

func TestLogTail(t *testing.T) {
	line := strings.Repeat("x", 99) + "\n"
	raw := []byte(strings.Repeat(line, 3000)) // 300 KB
	got := logTail(raw)
	if len(got) > logBytes || len(got) < logBytes-100 || got[0] != 'x' || !bytes.HasSuffix(raw, got) || (len(got))%100 != 0 {
		t.Errorf("logTail kept %d bytes", len(got))
	}
	if got := logTail(nil); got == nil || len(got) != 0 {
		t.Errorf("logTail(nil) = %v", got)
	}
}
