package chats

import (
	"bufio"
	"encoding/json"
	"io"
	"path/filepath"
	"reflect"
	"sync"
	"testing"

	"github.com/afrase/claude-acp-go/claudeagent"
)

// TestTheReplayWaitsForATasksWord holds the parity replay to what the
// recording's client saw before its next line: a task's word, which
// claude writes just before its answer to a stop and the Go agent may
// pass on just after that answer (claudeacp's StopTaskMethod). The
// recorder paused after the stop, so its recording has the stop's
// "killed" and "stopped" before the session's close; a replay that sends
// the close on the answer alone closes the session before the Go agent
// passed them on, and claude's words read but not yet handed on are lost
// with it, so the stopped workflow reads as running (CI on 2026-11-26).
// Here the first claude's task words reach the Go agent only once the
// replay waits for its updates, which it must before the close.
func TestTheReplayWaitsForATasksWord(t *testing.T) {
	dir := filepath.Join("testdata", "claude-parity", "workflow-resume-load")
	skipUnrecorded(t, dir)
	recorded, sent := readACP(t, filepath.Join(dir, "acp.jsonl"))
	fake := readReplays(t, dir)
	held := &taskWords{}
	fake.started = func(n int, p *claudeagent.Proc) {
		if n == 1 {
			p.Stdout = held.hold(p.Stdout)
		}
	}
	fake.waiting = held.release
	goRun := runGoAgentOn(t, fake, dir, sent, nil)
	want, got := views(t, recorded), views(t, goRun)
	if !reflect.DeepEqual(got, want) {
		t.Errorf("the Go agent's chats differ from the recording's:\n%s", differences(got, want))
	}
}

// taskWords is a claude's stdout with its task words (task_updated,
// task_notification) held back until release, while the rest goes on:
// the order the Go agent may pass on a stop's words and its answer in.
// The lock covers its lines only: a write to the Go agent waits for it to
// read, and the replay calls release while the Go agent may wait for it.
type taskWords struct {
	mu       sync.Mutex
	queue    [][]byte // to write, in order
	held     [][]byte
	released bool
	ended    bool          // claude's stdout ended
	wake     chan struct{} // the writer's: a line came, or the end
}

// hold starts passing claude's stdout on, and returns what the Go agent
// reads in its place.
func (w *taskWords) hold(stdout io.ReadCloser) io.ReadCloser {
	pr, pw := io.Pipe()
	w.wake = make(chan struct{}, 1)
	go w.read(stdout)
	go w.write(pw)
	return readCloser{pr, stdout}
}

// read takes claude's lines, holding its task words until release.
func (w *taskWords) read(stdout io.Reader) {
	r := bufio.NewReader(stdout)
	for {
		line, err := r.ReadBytes('\n')
		w.mu.Lock()
		switch {
		case len(line) == 0:
		case !w.released && isTaskWord(line):
			w.held = append(w.held, line)
		default:
			w.queue = append(w.queue, line)
		}
		w.ended = err != nil
		w.mu.Unlock()
		w.poke()
		if err != nil {
			return
		}
	}
}

// write hands the lines on to the Go agent until claude's stdout ended:
// what is held then never comes.
func (w *taskWords) write(out *io.PipeWriter) {
	for {
		w.mu.Lock()
		if len(w.queue) > 0 {
			line := w.queue[0]
			w.queue = w.queue[1:]
			w.mu.Unlock()
			_, _ = out.Write(line) // fails once the Go agent closed what it reads
			continue
		}
		ended := w.ended
		w.mu.Unlock()
		if ended {
			_ = out.Close()
			return
		}
		<-w.wake
	}
}

func (w *taskWords) poke() {
	select {
	case w.wake <- struct{}{}:
	default:
	}
}

// isTaskWord says whether a line of claude's is a task's word.
func isTaskWord(line []byte) bool {
	var f struct {
		Subtype string `json:"subtype"`
	}
	return json.Unmarshal(line, &f) == nil && (f.Subtype == "task_updated" || f.Subtype == "task_notification")
}

// release lets the words held so far go to the Go agent, after what it
// has been sent, and all that follows; with none held yet it does
// nothing.
func (w *taskWords) release() {
	w.mu.Lock()
	defer w.poke()
	defer w.mu.Unlock()
	if w.released || len(w.held) == 0 {
		return
	}
	w.queue = append(w.queue, w.held...)
	w.held, w.released = nil, true
}

// readCloser reads r and closes both r and the stdout it was made from.
type readCloser struct {
	r      *io.PipeReader
	stdout io.Closer
}

func (c readCloser) Read(p []byte) (int, error) { return c.r.Read(p) }

func (c readCloser) Close() error {
	_ = c.r.Close()
	return c.stdout.Close()
}
