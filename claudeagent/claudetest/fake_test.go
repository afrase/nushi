package claudetest

import (
	"bufio"
	"context"
	"errors"
	"io"
	"os"
	"slices"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/claudeagent"
)

// started is a fake's process as a client sees it: its stdout's lines,
// and all of its stderr once it ends.
type started struct {
	*claudeagent.Proc
	lines  *bufio.Scanner
	stderr chan string
}

func start(t *testing.T, f *Fake) started {
	t.Helper()
	p, err := f.Spawn(context.Background(), claudeagent.Spec{Path: "/claude", Args: []string{"--verbose"}, Env: []string{"K=v"}})
	if err != nil {
		t.Fatal(err)
	}
	s := started{p, bufio.NewScanner(p.Stdout), make(chan string, 1)}
	go func() {
		b, _ := io.ReadAll(p.Stderr)
		s.stderr <- string(b)
	}()
	t.Cleanup(func() {
		_ = p.Signal(os.Kill)
		<-f.Exited()
	})
	return s
}

func (s started) write(t *testing.T, line string) {
	t.Helper()
	if _, err := io.WriteString(s.Stdin, line+"\n"); err != nil {
		t.Fatal(err)
	}
}

func (s started) read(t *testing.T) string {
	t.Helper()
	if !s.lines.Scan() {
		t.Fatalf("stdout ended: %v", s.lines.Err())
	}
	return s.lines.Text()
}

// A script answers what it expects with what it captured, then exits
// when stdin closes, as claude does.
func TestScript(t *testing.T) {
	f := New(
		Expect(`{"type":"control_request","request":{"subtype":"initialize"}}`),
		Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req"}}`),
		Expect(`{"type":"user","message":{"role":"user"}}`),
		Send(`{"type":"user","uuid":"$uuid","isReplay":true}`),
		Stderr("working\n"),
	)
	s := start(t, f)
	s.write(t, `{"type":"control_request","request_id":"req_1_ab","request":{"subtype":"initialize","hooks":{}}}`)
	if got := s.read(t); got != `{"type":"control_response","response":{"subtype":"success","request_id":"req_1_ab"}}` {
		t.Errorf("%s", got)
	}
	s.write(t, `{"type":"keep_alive"}`)
	s.write(t, `{"type":"user","uuid":"u-1","message":{"role":"user","content":"hi"}}`)
	if got := s.read(t); got != `{"type":"user","uuid":"u-1","isReplay":true}` {
		t.Errorf("%s", got)
	}
	<-f.Played() // before stdin closes
	_ = s.Stdin.Close()
	if err := s.Wait(); err != nil || f.Err() != nil {
		t.Errorf("%v %v", err, f.Err())
	}
	if s.lines.Scan() {
		t.Errorf("more on stdout: %s", s.lines.Text())
	}
	if got := <-s.stderr; got != "working\n" {
		t.Errorf("stderr %q", got)
	}
	if sp := f.Spec(); sp.Path != "/claude" || !slices.Equal(sp.Args, []string{"--verbose"}) || !slices.Equal(sp.Env, []string{"K=v"}) {
		t.Errorf("%+v", sp)
	}
	if _, err := f.Spawn(context.Background(), claudeagent.Spec{}); err == nil {
		t.Error("started twice")
	}
}

// A line the script doesn't expect, or stdin closing before one it does,
// ends the fake with code 1, saying why.
func TestScriptFails(t *testing.T) {
	for _, tc := range []struct {
		name  string
		steps []Step
		write string
		want  string
	}{
		{"no match", []Step{Expect(`{"type":"user"}`)}, `{"type":"control_request"}`, `claudetest: expect {"type":"user"}: got {"type":"control_request"}`},
		{"stdin closed", []Step{Expect(`{"type":"user"}`)}, "", `claudetest: expect {"type":"user"}: stdin: EOF`},
		{"a line after the script", nil, `{"type":"user"}`, `claudetest: expect EOF: got {"type":"user"}`},
		{"not JSON", []Step{Expect(`{"type":"user"}`)}, `nope`, `claudetest: expect {"type":"user"}: got nope`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := New(tc.steps...)
			s := start(t, f)
			if tc.write != "" {
				s.write(t, tc.write)
			}
			_ = s.Stdin.Close()
			var ee *claudeagent.ExitError
			if err := s.Wait(); !errors.As(err, &ee) || ee.Code != 1 {
				t.Fatalf("%v", err)
			}
			if f.Err() == nil || f.Err().Error() != tc.want {
				t.Errorf("%v", f.Err())
			}
			if got := <-s.stderr; got != tc.want+"\n" {
				t.Errorf("stderr %q", got)
			}
		})
	}
}

// Exit ends the fake with its code and stderr; what's written after fails.
func TestExit(t *testing.T) {
	f := New(Send(`{"type":"system","subtype":"init"}`), Exit(2, "fatal\n"))
	s := start(t, f)
	if got := s.read(t); !strings.Contains(got, `"init"`) {
		t.Errorf("%s", got)
	}
	var ee *claudeagent.ExitError
	if err := s.Wait(); !errors.As(err, &ee) || ee.Code != 2 || ee.Signal != nil {
		t.Fatalf("%v", err)
	}
	if got := <-s.stderr; got != "fatal\n" {
		t.Errorf("stderr %q", got)
	}
	if _, err := io.WriteString(s.Stdin, "{}\n"); err == nil {
		t.Error("a write after exit")
	}
	if err := s.Signal(syscall.SIGTERM); !errors.Is(err, os.ErrProcessDone) {
		t.Errorf("a signal after exit: %v", err)
	}
	if f.Err() != nil {
		t.Error(f.Err())
	}
}

// Until holds the fake after stdin closes, until it is released or
// killed.
func TestUntil(t *testing.T) {
	for _, tc := range []struct {
		name string
		kill bool
	}{{"released", false}, {"killed", true}} {
		t.Run(tc.name, func(t *testing.T) {
			release := make(chan struct{})
			f := New(ExpectEOF(), Until(release))
			s := start(t, f)
			_ = s.Stdin.Close()
			select {
			case <-f.Exited():
				t.Fatal("exited while held")
			case <-f.Played():
				t.Fatal("played while held")
			default:
			}
			if tc.kill {
				_ = s.Signal(os.Kill)
			} else {
				close(release)
			}
			if err := s.Wait(); tc.kill != (err != nil) || f.Err() != nil {
				t.Errorf("%v %v", err, f.Err())
			}
		})
	}
}

// SIGTERM ends the fake, unless it ignores SIGTERM; SIGKILL always does.
// Other signals are only noted.
func TestSignals(t *testing.T) {
	for _, tc := range []struct {
		name       string
		ignoreTerm bool
		send       []os.Signal
		want       os.Signal
	}{
		{"term", false, []os.Signal{syscall.SIGINT, syscall.SIGTERM}, syscall.SIGTERM},
		{"term ignored", true, []os.Signal{syscall.SIGTERM, os.Kill}, os.Kill},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := New(Expect(`{"type":"user"}`))
			f.IgnoreTerm = tc.ignoreTerm
			s := start(t, f)
			for _, sig := range tc.send {
				if err := s.Signal(sig); err != nil {
					t.Fatal(err)
				}
			}
			var ee *claudeagent.ExitError
			if err := s.Wait(); !errors.As(err, &ee) || ee.Signal != tc.want || ee.Code != -1 {
				t.Fatalf("%v", err)
			}
			if !slices.Equal(f.Signals(), tc.send) || f.Err() != nil {
				t.Errorf("%v %v", f.Signals(), f.Err())
			}
		})
	}
}

// Respond answers its lines whenever they come, out of the script's
// order, and Do runs between steps.
func TestRespond(t *testing.T) {
	reached := make(chan struct{})
	f := New(
		Expect(`{"type":"user"}`),
		Do(func() { close(reached) }),
		Send(`{"type":"result","uuid":"$uuid"}`),
	).Respond(`{"type":"control_request","request":{"subtype":"interrupt"}}`,
		`{"type":"control_response","response":{"subtype":"success","request_id":"$req"}}`)
	s := start(t, f)
	s.write(t, `{"type":"control_request","request_id":"r1","request":{"subtype":"interrupt"}}`)
	if got := s.read(t); got != `{"type":"control_response","response":{"subtype":"success","request_id":"r1"}}` {
		t.Errorf("%s", got)
	}
	s.write(t, `{"type":"user","uuid":"u-1"}`)
	<-reached
	if got := s.read(t); got != `{"type":"result","uuid":"u-1"}` {
		t.Errorf("%s", got)
	}
	s.write(t, `{"type":"control_request","request_id":"r2","request":{"subtype":"interrupt"}}`)
	if got := s.read(t); !strings.Contains(got, `"r2"`) {
		t.Errorf("%s", got)
	}
	_ = s.Stdin.Close()
	if err := s.Wait(); err != nil || f.Err() != nil {
		t.Errorf("%v %v", err, f.Err())
	}
	if got := f.Responded(); len(got) != 2 || !strings.Contains(got[1], `"r2"`) {
		t.Errorf("%q", got)
	}
}
