package pig

import (
	"io"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/agentproc"
)

type discard struct{ io.Writer }

func (discard) Close() error { return nil }

// A line over agentproc.MaxRead ends pig's output: what came before it
// is read, and pig is killed.
func TestReadLimit(t *testing.T) {
	agentproc.MaxRead = 100
	defer func() { agentproc.MaxRead = 256 << 20 }()
	killed := make(chan struct{})
	out := `{"type":"agent_start"}` + "\n" + strings.Repeat("x", 200) + "\n" + `{"type":"agent_end"}` + "\n"
	p, err := startProc(func(string, ...string) (Pig, error) {
		return Pig{In: discard{io.Discard}, Out: strings.NewReader(out), Kill: func() { close(killed) }}, nil
	}, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if ev := <-p.events; ev.Type != "agent_start" {
		t.Errorf("%+v", ev)
	}
	if ev, ok := <-p.events; ok {
		t.Errorf("read past the long line: %+v", ev)
	}
	<-killed
}
