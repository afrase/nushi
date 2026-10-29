package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// The test binary is three programs: the tests; claude-tee, with
// CLAUDE_TEE_TEST=1; and a fake claude, when run by the name "claude"
// (a link to it), since the tee hands claude its own environment.
func TestMain(m *testing.M) {
	switch {
	case filepath.Base(os.Args[0]) == "claude":
		os.Exit(fakeClaude())
	case os.Getenv("CLAUDE_TEE_TEST") == "1":
		main()
	default:
		m.Run()
	}
}

// fakeClaude says its version, or echoes each stdin line as JSON after a
// line that isn't JSON, as some builds print; on "hang" it says so and
// waits for a signal, which ends it as the default action does; at EOF
// it exits with $FAKE_EXIT.
func fakeClaude() int {
	if slices.Contains(os.Args[1:], "--version") {
		_, _ = fmt.Fprintln(os.Stdout, "9.9.9 (Fake)")
		return 0
	}
	fmt.Fprintln(os.Stderr, "fake claude's stderr")
	_, _ = fmt.Fprintln(os.Stdout, "[SandboxDebug] not JSON")
	sc := bufio.NewScanner(os.Stdin)
	for sc.Scan() {
		if sc.Text() == `{"type":"hang"}` {
			c := make(chan os.Signal, 1)
			signal.Notify(c, syscall.SIGTERM)
			_, _ = fmt.Fprintln(os.Stdout, `{"type":"hanging"}`)
			<-c
			signal.Reset(syscall.SIGTERM)
			_ = syscall.Kill(os.Getpid(), syscall.SIGTERM)
			select {}
		}
		b, _ := json.Marshal(map[string]any{"type": "echo", "got": json.RawMessage(sc.Bytes())})
		_, _ = fmt.Fprintln(os.Stdout, string(b))
	}
	code, _ := strconv.Atoi(os.Getenv("FAKE_EXIT"))
	return code
}

// teeCmd is claude-tee running the fake claude, recording into out.
func teeCmd(t *testing.T, out string, args ...string) *exec.Cmd {
	t.Helper()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	claude := filepath.Join(t.TempDir(), "claude")
	if err := os.Symlink(exe, claude); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(exe, args...)
	cmd.Env = append(os.Environ(), "CLAUDE_TEE_TEST=1", "CLAUDE_TEE_REAL="+claude, "CLAUDE_TEE_OUT="+out, "SECRET_TOKEN=hunter2")
	return cmd
}

func readCassette(t *testing.T, path string) (*claudetest.Cassette, string) {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	c, err := claudetest.ReadCassette(bytes.NewReader(b))
	if err != nil {
		t.Fatal(err)
	}
	return c, string(b)
}

func TestRecord(t *testing.T) {
	out := filepath.Join(t.TempDir(), "cli.jsonl")
	in := `{"type":"control_request","request_id":"1","request":{"subtype":"initialize"}}` + "\n" + `{"type":"user","message":{"role":"user","content":"hi"}}` + "\n"
	var stdout, stderr bytes.Buffer
	for run := 1; run <= 2; run++ {
		stdout.Reset()
		cmd := teeCmd(t, out, "--output-format", "stream-json", "--verbose", "--input-format=stream-json")
		cmd.Stdin, cmd.Stdout, cmd.Stderr = strings.NewReader(in), &stdout, &stderr
		cmd.Env = append(cmd.Env, "FAKE_EXIT=3")
		var ee *exec.ExitError
		if err := cmd.Run(); !errors.As(err, &ee) || ee.ExitCode() != 3 {
			t.Fatalf("run %d: %v, want claude's exit code 3", run, err)
		}
	}
	want := "[SandboxDebug] not JSON\n" +
		`{"got":{"type":"control_request","request_id":"1","request":{"subtype":"initialize"}},"type":"echo"}` + "\n" +
		`{"got":{"type":"user","message":{"role":"user","content":"hi"}},"type":"echo"}` + "\n"
	if stdout.String() != want {
		t.Errorf("stdout\n%s\nwant\n%s", stdout.String(), want)
	}
	if !strings.Contains(stderr.String(), "fake claude's stderr") {
		t.Errorf("stderr %q", stderr.String())
	}
	for _, path := range []string{out, strings.TrimSuffix(out, ".jsonl") + "-2.jsonl"} {
		c, raw := readCassette(t, path)
		if strings.Contains(raw, "hunter2") || strings.Contains(raw, "CLAUDE_TEE_REAL") || strings.Contains(raw, "CLAUDE_TEE_OUT") {
			t.Errorf("%s has an environment value or the tee's own variables:\n%s", path, raw)
		}
		h := c.Header
		if !slices.Equal(h.Argv, []string{"--output-format", "stream-json", "--verbose", "--input-format=stream-json"}) || h.CLI != "9.9.9" || !slices.Contains(h.EnvKeys, "SECRET_TOKEN") {
			t.Errorf("%s: header %+v", path, h)
		}
		var got []string
		last := int64(0)
		for _, f := range c.Frames {
			got = append(got, f.Dir+" "+string(f.Frame))
			if f.MS < last {
				t.Errorf("%s: time went back: %+v", path, c.Frames)
			}
			last = f.MS
		}
		// The order of an "in" and the "out" it causes is kept; the
		// line that isn't JSON comes first, or after the first "in".
		in1 := `in {"type":"control_request","request_id":"1","request":{"subtype":"initialize"}}`
		out1 := `out {"got":{"type":"control_request","request_id":"1","request":{"subtype":"initialize"}},"type":"echo"}`
		if len(got) != 5 || !slices.Contains(got, `out "[SandboxDebug] not JSON"`) || slices.Index(got, in1) > slices.Index(got, out1) {
			t.Errorf("%s: frames\n%s", path, strings.Join(got, "\n"))
		}
	}
}

// A signal the tee gets goes on to claude, and the tee ends as claude
// did.
func TestSignal(t *testing.T) {
	out := filepath.Join(t.TempDir(), "cli.jsonl")
	cmd := teeCmd(t, out, "--input-format", "stream-json")
	stdin, err := cmd.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	if _, err := io.WriteString(stdin, `{"type":"hang"}`+"\n"); err != nil {
		t.Fatal(err)
	}
	sc := bufio.NewScanner(stdout)
	for sc.Scan() {
		if sc.Text() == `{"type":"hanging"}` {
			break
		}
	}
	if err := cmd.Process.Signal(syscall.SIGTERM); err != nil {
		t.Fatal(err)
	}
	err = cmd.Wait()
	var ee *exec.ExitError
	if !errors.As(err, &ee) {
		t.Fatalf("the tee ended with %v", err)
	}
	if ws := ee.Sys().(syscall.WaitStatus); !ws.Signaled() || ws.Signal() != syscall.SIGTERM {
		t.Errorf("the tee ended with %v, want SIGTERM", ws)
	}
	c, _ := readCassette(t, out)
	if n := len(c.Frames); n != 3 {
		t.Errorf("%d frames, want the hang, the line that isn't JSON and hanging", n)
	}
}

func TestNotRecorded(t *testing.T) {
	out := filepath.Join(t.TempDir(), "cli.jsonl")
	for _, args := range [][]string{{"--version"}, {"auth", "status", "--json"}} {
		b, err := teeCmd(t, out, args...).Output()
		if err != nil || args[0] == "--version" && string(b) != "9.9.9 (Fake)\n" {
			t.Errorf("%v: %q, %v", args, b, err)
		}
		if _, err := os.Stat(out); !errors.Is(err, os.ErrNotExist) {
			t.Errorf("a cassette for %v: %v", args, err)
		}
	}
	cmd := teeCmd(t, out, "--input-format", "stream-json")
	cmd.Env = append(cmd.Env, "CLAUDE_TEE_REAL=")
	if err := cmd.Run(); err == nil {
		t.Error("ran with no claude named")
	}
}
