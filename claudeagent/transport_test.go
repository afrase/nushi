package claudeagent

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"sync"
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
	case "group": // its pid and its process group's
		out(os.Stdout, "{\"pid\":%d,\"pgid\":%d}\n", os.Getpid(), syscall.Getpgrp())
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
	case "trail": // two messages, then more and an error result on a stdin line, and code 1
		out(os.Stdout, "{\"type\":\"user\",\"n\":1}\n{\"type\":\"user\",\"n\":2}\n") // one write, read whole
		stdin.Scan()
		for i := range 30 {
			out(os.Stdout, "{\"type\":\"user\",\"n\":%d,\"pad\":%q}\n", i+3, strings.Repeat("x", 300))
		}
		out(os.Stdout, "%s\n", `{"type":"result","subtype":"success","is_error":true,"result":"late boom"}`)
		code = 1
	case "orphan": // leaves a process outside its group holding stdout and stderr
		sleep := exec.Command("/bin/sleep", "60")
		sleep.Stdout, sleep.Stderr = os.Stdout, os.Stderr
		sleep.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
		if err := sleep.Start(); err != nil {
			code = 9
			break
		}
		out(os.Stdout, "{\"type\":\"ready\",\"pid\":%d}\n", sleep.Process.Pid)
	}
	os.Exit(code) //nolint:revive // the stand-in's exit, before the test framework writes on its stdout
}

// clock is a fake clock: each wait the transport asks for is a timer the
// test fires, or not, when time stands still.
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

// helper starts the stand-in claude as mode says, with fake clocks for
// its shutdown and for giving up on its pipes.
func helper(t *testing.T, mode string, o Options) (tr *transport, shutdown, idle clock) {
	t.Helper()
	p, err := Exec(context.Background(), Spec{
		Path: os.Args[0], Args: []string{"-test.run=^TestHelperProcess$"},
		// The race detector's second at exit would only slow the tests.
		Env: append(os.Environ(), "CLAUDEAGENT_HELPER="+mode, "GORACE=atexit_sleep_ms=0"),
	})
	if err != nil {
		t.Fatal(err)
	}
	tr = makeTransport(p, o)
	shutdown, idle = make(clock, 4), make(clock, 4)
	tr.after, tr.idle = shutdown.after, idle.after
	tr.start(o.MaxLine)
	t.Cleanup(func() {
		_ = tr.proc.Signal(os.Kill)
		<-tr.done
	})
	return tr, shutdown, idle
}

// Blank lines, lines that aren't JSON and the transport's own frames are
// skipped; a line over the cap is a warning, and the stream goes on.
func TestTransportFrames(t *testing.T) {
	tr, _, _ := helper(t, "frames", Options{MaxLine: 200})
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
	tr, c, _ := helper(t, "echo", Options{})
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
	tr, c, _ := helper(t, "linger", Options{})
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
	tr, c, _ := helper(t, "stubborn", Options{})
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
	tr, _, _ := helper(t, "fail", Options{Stderr: func(l string) { lines <- l }})
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

// stall lets time pass after claude exits with a pipe's reader behind: it
// fires each idle timer asked for until one of d is asked for again, which
// says the transport waited on and didn't give up on the pipe.
func stall(t *testing.T, idle clock, d time.Duration) {
	t.Helper()
	fired := false
	// One bound for the whole wait: the other pipe's timers can come
	// forever once this one is given up on.
	guard := time.After(5 * time.Second)
	for {
		select {
		case tm := <-idle:
			if tm.d == d && fired {
				return
			}
			fired = fired || tm.d == d
			tm.fire <- time.Time{}
		case <-guard:
			t.Fatal("gave up on a pipe whose reader was behind")
		}
	}
}

// A consumer that's behind when claude exits still gets every message
// claude wrote, and the exit error the error result among them.
func TestTransportSlowConsumer(t *testing.T) {
	tr, _, idle := helper(t, "trail", Options{})
	msgs := tr.messages()
	<-msgs // the second waits to be handed on; the rest will wait in the pipe
	if err := tr.write(map[string]any{"type": "go"}); err != nil {
		t.Fatal(err)
	}
	<-tr.exited
	stall(t, idle, time.Second)
	n := 1
	for range msgs {
		n++
	}
	if n != 33 {
		t.Errorf("%d messages, want 33", n)
	}
	var ee *ExitError
	if err := tr.wait(); !errors.As(err, &ee) || ee.Code != 1 || ee.Result != "late boom" {
		t.Errorf("%v", err)
	}
}

// A stderr callback that's behind when claude exits still gets every line,
// and the exit error has the end of stderr.
func TestTransportSlowStderr(t *testing.T) {
	release, reading := make(chan struct{}), make(chan struct{}, 1)
	var lines []string
	tr, _, idle := helper(t, "fail", Options{Stderr: func(l string) {
		select {
		case reading <- struct{}{}:
		default:
		}
		<-release
		lines = append(lines, l)
	}})
	<-tr.exited
	// The reader is past its first Read, held by the callback: until then
	// a Read under way can't be told from one waiting on an empty pipe, and
	// the fake clock's 200 ms pass at once.
	<-reading
	stall(t, idle, 200*time.Millisecond)
	close(release)
	for range tr.messages() {
		continue
	}
	var ee *ExitError
	if err := tr.wait(); !errors.As(err, &ee) || !strings.HasSuffix(ee.Stderr, "fatal: no login") {
		t.Fatalf("%v", err)
	}
	if len(lines) != 101 {
		t.Errorf("%d stderr lines", len(lines))
	}
}

// Pipes a process outside claude's group holds open are given up on once
// nothing comes on them, with a warning; claude's exit is still reported.
func TestTransportGivesUp(t *testing.T) {
	var log lockedBuffer
	tr, _, idle := helper(t, "orphan", Options{Log: slog.New(slog.NewTextHandler(&log, nil))})
	msgs := tr.messages()
	var ready struct{ PID int }
	if err := json.Unmarshal((<-msgs).Frame().Raw, &ready); err != nil || ready.PID == 0 {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = syscall.Kill(ready.PID, syscall.SIGKILL) })
	for open := true; open; {
		select {
		case tm := <-idle: // each wait is long enough
			tm.fire <- time.Time{}
		case m, ok := <-msgs:
			if open = ok; ok {
				t.Errorf("%+v", m)
			}
		}
	}
	if err := tr.wait(); err != nil {
		t.Error(err)
	}
	for _, pipe := range []string{"stdout", "stderr"} {
		if !strings.Contains(log.String(), "holds its "+pipe) {
			t.Errorf("no warning for %s: %s", pipe, log.String())
		}
	}
}

// lockedBuffer is a log that the transport's goroutines write and the test
// reads.
type lockedBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (l *lockedBuffer) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.Write(p)
}

func (l *lockedBuffer) String() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.String()
}

// Start builds claude's spec from the options and hands it to the spawner.
func TestStartTransport(t *testing.T) {
	var got Spec
	_, err := startTransport(context.Background(), Options{CLIPath: "/c", Env: []string{}, Model: "m", SharedGroup: true, Spawner: func(_ context.Context, s Spec) (*Proc, error) {
		got = s
		return nil, errors.New("no")
	}})
	if err == nil || got.Path != "/c" || got.Args[len(got.Args)-1] != "--model=m" || !strings.Contains(strings.Join(got.Env, " "), "CLAUDE_CODE_ENTRYPOINT=sdk-cli") || !got.SharedGroup {
		t.Errorf("%+v %v", got, err)
	}
	if _, err := startTransport(context.Background(), Options{CLIPath: t.TempDir() + "/none", Env: []string{}}); err == nil {
		t.Error("a missing claude started")
	}
	tr, err := startTransport(context.Background(), Options{CLIPath: "/c", Env: []string{}, Spawner: func(context.Context, Spec) (*Proc, error) {
		_, in := io.Pipe()
		return &Proc{
			Stdin: in, Stdout: io.NopCloser(strings.NewReader("")), Stderr: io.NopCloser(strings.NewReader("")),
			Process: exitedProcess{},
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

// exitedProcess is a claude that has exited with 0.
type exitedProcess struct{}

func (exitedProcess) Wait() error            { return nil }
func (exitedProcess) Signal(os.Signal) error { return os.ErrProcessDone }
