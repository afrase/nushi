package ante

import (
	"io"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/agentproc"
)

type discard struct{ io.Writer }

func (discard) Close() error { return nil }

// A line over agentproc.MaxRead ends the host's output: what came before
// it is read, and the host is killed.
func TestReadLimit(t *testing.T) {
	agentproc.MaxRead = 100
	defer func() { agentproc.MaxRead = 256 << 20 }()
	killed := make(chan struct{})
	out := `{"event":"Goodbye"}` + "\n" + strings.Repeat("x", 200) + "\n" + `{"event":"Goodbye"}` + "\n"
	h, err := startHost(func(string) (io.WriteCloser, io.Reader, func(), error) {
		return discard{io.Discard}, strings.NewReader(out), func() { close(killed) }, nil
	}, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if ev := <-h.events; ev.Name != "Goodbye" {
		t.Errorf("%+v", ev)
	}
	if ev, ok := <-h.events; ok {
		t.Errorf("read past the long line: %+v", ev)
	}
	<-killed
}

// endOf is a host's output that says when its reader has come to its end.
type endOf struct {
	io.Reader
	ended chan struct{}
}

func (e endOf) Read(b []byte) (int, error) {
	n, err := e.Reader.Read(b)
	if err == io.EOF {
		close(e.ended)
	}
	return n, err
}

// A session that fails to open has its host's events read while the host
// stops: more than the reader's buffer follow the failure, and the reader
// still comes to their end.
func TestFailedOpenReadsTheHostOut(t *testing.T) {
	out := endOf{strings.NewReader(`{"event":{"Error":"no such session"}}` + "\n" + strings.Repeat(`{"event":"Goodbye"}`+"\n", 300)), make(chan struct{})}
	b := &bridge{spawn: func(string) (io.WriteCloser, io.Reader, func(), error) {
		return discard{io.Discard}, out, func() {}, nil
	}, sessions: map[string]*session{}}
	if _, err := b.open(t.Context(), t.TempDir(), resume("s1"), false); err == nil || err.Error() != "no such session" {
		t.Fatalf("open: %v", err)
	}
	select {
	case <-out.ended:
	case <-time.After(5 * time.Second):
		t.Fatal("the host's events are left unread")
	}
}
