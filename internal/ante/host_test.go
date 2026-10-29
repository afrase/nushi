package ante

import (
	"io"
	"strings"
	"testing"

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
