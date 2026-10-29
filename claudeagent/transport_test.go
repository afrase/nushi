package claudeagent

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
	"testing"
	"time"
	"unicode/utf8"
)

// TestHelperProcess is a stand-in claude, run by the tests below as the
// test binary with CLAUDEAGENT_HELPER naming what it does. It ends as a
// process does, with an exit code.
func TestHelperProcess(*testing.T) {
	mode := os.Getenv("CLAUDEAGENT_HELPER")
	if mode == "" {
		return
	}
	stdin := bufio.NewScanner(os.Stdin)
	out := func(f *os.File, format string, a ...any) { _, _ = fmt.Fprintf(f, format, a...) }
	block := func() {
		for {
			time.Sleep(time.Hour)
		}
	}
	code := 0
	switch mode {
	case "frames": // what claude may write besides messages
		out(os.Stdout, "\n[SandboxDebug] hello\n{\"type\":\"keep_alive\"}\n{not json\n")
		out(os.Stdout, "{\"type\":\"user\",\"pad\":%q}\n", strings.Repeat("x", 300))
		out(os.Stdout, "{\"type\":\"transcript_mirror\"}\n{\"type\":\"system\",\"subtype\":\"session_state_changed\",\"state\":\"idle\"}\r\n")
	case "echo": // each stdin line back, until EOF
		for stdin.Scan() {
			out(os.Stdout, "%s\n", stdin.Text())
		}
	case "linger": // stays after EOF, until a signal
		for stdin.Scan() {
			continue
		}
		block()
	case "stubborn": // ignores SIGTERM, with a process of its own in the group
		signal.Ignore(syscall.SIGTERM)
		sleep := exec.Command("/bin/sleep", "100")
		if err := sleep.Start(); err != nil {
			code = 9
			break
		}
		out(os.Stdout, "{\"type\":\"ready\",\"pid\":%d}\n", sleep.Process.Pid)
		block()
	case "fail": // a lot of stderr, an error result, and code 3
		for i := range 100 {
			out(os.Stderr, "line %d %s\n", i, strings.Repeat("é", 30))
		}
		out(os.Stderr, "fatal: no login\n")
		out(os.Stdout, "%s\n", `{"type":"result","subtype":"error_during_execution","is_error":true,"errors":["boom"]}`)
		code = 3
	}
	os.Exit(code) //nolint:revive // the stand-in's exit, before the test framework writes on its stdout
}

// clock is a fake shutdown clock: each wait claude's shutdown asks for is
// a timer the test fires.
type clock chan timer

type timer struct {
	d    time.Duration
	fire chan time.Time
}

func (c clock) after(d time.Duration) <-chan time.Time {
	t := timer{d, make(chan time.Time, 1)}
	c <- t
	return t.fire
}

// helper starts the stand-in claude as mode says.
func helper(t *testing.T, mode string, o Options) (*transport, clock) {
	t.Helper()
	p, err := Exec(context.Background(), Spec{
		Path: os.Args[0], Args: []string{"-test.run=^TestHelperProcess$"},
		// The race detector's second at exit would only slow the tests.
		Env: append(os.Environ(), "CLAUDEAGENT_HELPER="+mode, "GORACE=atexit_sleep_ms=0"),
	})
	if err != nil {
		t.Fatal(err)
	}
	tr := newTransport(p, o)
	c := make(clock, 4)
	tr.after = c.after
	t.Cleanup(func() {
		_ = tr.proc.Signal(os.Kill)
		<-tr.done
	})
	return tr, c
}

// Blank lines, lines that aren't JSON and the transport's own frames are
// skipped; a line over the cap is a warning, and the stream goes on.
func TestTransportFrames(t *testing.T) {
	tr, _ := helper(t, "frames", Options{MaxLine: 200})
	var got []Message
	for m := range tr.messages() {
		got = append(got, m)
	}
	if len(got) != 2 {
		t.Fatalf("%d messages: %+v", len(got), got)
	}
	if w, ok := got[0].(*TransportWarning); !ok || w.Size != 324 {
		t.Errorf("%+v", got[0])
	}
	if s, ok := got[1].(*SessionState); !ok || s.State != "idle" {
		t.Errorf("%+v", got[1])
	}
	if err := tr.wait(); err != nil {
		t.Error(err)
	}
}

// Each write is one line; closing stdin ends claude, which needs no
// signal; nothing is written after.
func TestTransportWriteAndEOF(t *testing.T) {
	tr, c := helper(t, "echo", Options{})
	if err := tr.write(map[string]any{"type": "user", "message": map[string]any{"role": "user", "content": "a\nb"}}); err != nil {
		t.Fatal(err)
	}
	m := <-tr.messages()
	if u, ok := m.(*User); !ok || u.Message.Content[0].Text != "a\nb" {
		t.Fatalf("%+v", m)
	}
	tr.close()
	if err := tr.wait(); err != nil {
		t.Error(err)
	}
	if len(c) != 1 || (<-c).d != 2*time.Second {
		t.Error("the shutdown didn't wait 2 s for EOF to be honoured")
	}
	if err := tr.write(map[string]any{"type": "user"}); !errors.Is(err, ErrClosed) {
		t.Errorf("a write after close: %v", err)
	}
	if err := tr.write(func() {}); err == nil || errors.Is(err, ErrClosed) {
		t.Errorf("a value that can't be JSON: %v", err)
	}
}

// claude still running 2 s after EOF gets SIGTERM.
func TestTransportTerm(t *testing.T) {
	tr, c := helper(t, "linger", Options{})
	closed := make(chan struct{})
	go func() {
		tr.close()
		close(closed)
	}()
	if tm := <-c; tm.d != 2*time.Second {
		t.Fatalf("waited %s", tm.d)
	} else {
		tm.fire <- time.Time{}
	}
	<-closed
	var ee *ExitError
	if err := tr.wait(); !errors.As(err, &ee) || ee.Signal != syscall.SIGTERM || ee.Code != -1 {
		t.Fatalf("%v", err)
	}
	if !strings.HasPrefix(ee.Error(), "claude ended on a signal (terminated)") {
		t.Error(ee.Error())
	}
}

// claude that ignores SIGTERM gets SIGKILL 5 s later, its group with it.
func TestTransportKill(t *testing.T) {
	tr, c := helper(t, "stubborn", Options{})
	m := <-tr.messages() // SIGTERM is ignored by now
	var ready struct{ PID int }
	if err := json.Unmarshal(m.Frame().Raw, &ready); err != nil || ready.PID == 0 {
		t.Fatalf("%s %v", m.Frame().Raw, err)
	}
	closed := make(chan struct{})
	go func() {
		tr.close()
		close(closed)
	}()
	for _, d := range []time.Duration{2 * time.Second, 5 * time.Second} {
		tm := <-c
		if tm.d != d {
			t.Fatalf("waited %s, want %s", tm.d, d)
		}
		tm.fire <- time.Time{}
	}
	<-closed
	var ee *ExitError
	if err := tr.wait(); !errors.As(err, &ee) || ee.Signal != syscall.SIGKILL {
		t.Fatalf("%v", err)
	}
	for end := time.Now().Add(5 * time.Second); syscall.Kill(ready.PID, 0) == nil; time.Sleep(10 * time.Millisecond) {
		if time.Now().After(end) {
			t.Fatal("the process claude started outlived it")
		}
	}
}

// The exit error has the end of stderr, cut at a character, and the last
// error result's text, which comes first; every stderr line reaches the
// callback.
func TestTransportExitError(t *testing.T) {
	lines := make(chan string, 200)
	tr, _ := helper(t, "fail", Options{Stderr: func(l string) { lines <- l }})
	for range tr.messages() {
		continue // the result is noted as it's read
	}
	var ee *ExitError
	if err := tr.wait(); !errors.As(err, &ee) || ee.Code != 3 || ee.Signal != nil {
		t.Fatalf("%v", err)
	}
	if len(ee.Stderr) > tailSize || len(ee.Stderr) < tailSize-100 || !utf8.ValidString(ee.Stderr) || !strings.HasSuffix(ee.Stderr, "fatal: no login") {
		t.Errorf("stderr %d bytes: %.40q…", len(ee.Stderr), ee.Stderr)
	}
	if ee.Result != "boom" || ee.Error() != "claude returned an error result: boom" {
		t.Errorf("%q", ee.Error())
	}
	if len(lines) != 101 {
		t.Errorf("%d stderr lines", len(lines))
	}
	if s := (&ExitError{Code: 2, Stderr: "x"}).Error(); s != "claude exited with code 2: x" {
		t.Error(s)
	}
}

// Start builds claude's spec from the options and hands it to the spawner.
func TestStartTransport(t *testing.T) {
	var got Spec
	_, err := startTransport(context.Background(), Options{CLIPath: "/c", Env: []string{}, Model: "m", Spawner: func(_ context.Context, s Spec) (*Proc, error) {
		got = s
		return nil, errors.New("no")
	}})
	if err == nil || got.Path != "/c" || got.Args[len(got.Args)-1] != "--model=m" || !strings.Contains(strings.Join(got.Env, " "), "CLAUDE_CODE_ENTRYPOINT=sdk-cli") {
		t.Errorf("%+v %v", got, err)
	}
	if _, err := startTransport(context.Background(), Options{CLIPath: t.TempDir() + "/none", Env: []string{}}); err == nil {
		t.Error("a missing claude started")
	}
	tr, err := startTransport(context.Background(), Options{CLIPath: "/c", Env: []string{}, Spawner: func(context.Context, Spec) (*Proc, error) {
		_, in := io.Pipe()
		return &Proc{
			Stdin: in, Stdout: io.NopCloser(strings.NewReader("")), Stderr: io.NopCloser(strings.NewReader("")),
			Wait: func() error { return nil }, Signal: func(os.Signal) error { return os.ErrProcessDone },
		}, nil
	}})
	if err != nil {
		t.Fatal(err)
	}
	tr.close()
	if err := tr.wait(); err != nil {
		t.Error(err)
	}
}
