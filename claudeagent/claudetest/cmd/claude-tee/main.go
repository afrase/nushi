// Command claude-tee records a run of claude into a cassette (package
// claudetest's): put it where a client runs claude, such as
// claude-agent-acp's CLAUDE_CODE_EXECUTABLE, with
//
//	CLAUDE_TEE_REAL  the claude to run
//	CLAUDE_TEE_OUT   the cassette to write
//
// It runs CLAUDE_TEE_REAL with its own arguments, passing stdin, stdout
// and stderr through, and writes a header (the arguments, the
// environment's names and claude's version) and then each line of stdin
// and stdout as {"dir":"in"|"out","ms":…,"frame":…}. It never writes an
// environment variable's value, which may be a secret. A line that isn't
// JSON is kept as a JSON string. Claude's exit code is its own, and a
// signal it gets goes on to claude; a signal that ends claude ends it too.
//
// When CLAUDE_TEE_OUT exists it writes beside it, -2, -3… before the
// extension, so a client that runs claude several times leaves a cassette
// a run. Only runs on the stream-JSON protocol are recorded: claude run as
// a command (--version, auth status) just runs.
//
// With -schema-diff it compares recorded frames with claude's schemas
// instead (schemadiff.go).
package main

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
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "-schema-diff" {
		os.Exit(schemaDiff(os.Args[2:], os.Stdout, os.Stderr))
	}
	os.Exit(tee(os.Args[1:]))
}

// tee runs claude with args, recording it, and returns the code to exit
// with.
func tee(args []string) int {
	claude, out := os.Getenv("CLAUDE_TEE_REAL"), os.Getenv("CLAUDE_TEE_OUT")
	if claude == "" || out == "" {
		fmt.Fprintln(os.Stderr, "claude-tee: set CLAUDE_TEE_REAL (the claude to run) and CLAUDE_TEE_OUT (the cassette)")
		return 2
	}
	env := slices.DeleteFunc(os.Environ(), func(kv string) bool {
		return strings.HasPrefix(kv, "CLAUDE_TEE_REAL=") || strings.HasPrefix(kv, "CLAUDE_TEE_OUT=")
	})
	cmd := exec.Command(claude, args...) //nolint:gosec,noctx // the claude the caller names; it lives as long as this process
	cmd.Env, cmd.Stderr = env, os.Stderr
	if !streams(args) {
		cmd.Stdin, cmd.Stdout = os.Stdin, os.Stdout
		return exitCode(cmd.Run())
	}
	f, err := create(out)
	if err != nil {
		fmt.Fprintln(os.Stderr, "claude-tee:", err)
		return 1
	}
	defer f.Close() //nolint:errcheck // written a line at a time; each Write's error is checked
	c := &cassette{w: f, start: time.Now()}
	if err := c.header(args, env, version(claude, env)); err != nil {
		fmt.Fprintln(os.Stderr, "claude-tee:", err)
		return 1
	}
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return 1
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return 1
	}
	sigs := make(chan os.Signal, 4)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP, syscall.SIGQUIT, syscall.SIGUSR1, syscall.SIGUSR2)
	if err := cmd.Start(); err != nil {
		fmt.Fprintln(os.Stderr, "claude-tee:", err)
		return 1
	}
	go func() {
		for s := range sigs {
			_ = cmd.Process.Signal(s)
		}
	}()
	go func() {
		c.copy("in", stdin, os.Stdin)
		_ = stdin.Close() // claude reads EOF as the client going, as without the tee
	}()
	c.copy("out", os.Stdout, stdout)
	err = cmd.Wait()
	signal.Stop(sigs)
	if err := c.failed(); err != nil {
		fmt.Fprintln(os.Stderr, "claude-tee: the cassette:", err)
	}
	if ee, ok := errors.AsType[*exec.ExitError](err); ok {
		if ws, ok := ee.Sys().(syscall.WaitStatus); ok && ws.Signaled() {
			_ = f.Close()
			signal.Reset(ws.Signal())
			_ = syscall.Kill(os.Getpid(), ws.Signal()) // ends as claude did
			time.Sleep(time.Second)                    // the signal comes on a thread of its own; this is only the fallback
			return 128 + int(ws.Signal())
		}
	}
	return exitCode(err)
}

// streams says whether args run claude on the stream-JSON protocol, not
// as a command (--version, auth status).
func streams(args []string) bool {
	for i, a := range args {
		if a == "--input-format=stream-json" || a == "--input-format" && i+1 < len(args) && args[i+1] == "stream-json" {
			return true
		}
	}
	return false
}

// exitCode is the code a run's error says to exit with.
func exitCode(err error) int {
	var ee *exec.ExitError
	switch {
	case err == nil:
		return 0
	case errors.As(err, &ee):
		if code := ee.ExitCode(); code >= 0 {
			return code
		}
	default:
		fmt.Fprintln(os.Stderr, "claude-tee:", err)
	}
	return 1
}

// create makes the cassette file at path, or beside it with -2, -3…
// before its extension when there is one already.
func create(path string) (*os.File, error) {
	ext := filepath.Ext(path)
	stem := strings.TrimSuffix(path, ext)
	for n := 1; ; n++ {
		p := path
		if n > 1 {
			p = stem + "-" + strconv.Itoa(n) + ext
		}
		f, err := os.OpenFile(p, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600) //nolint:gosec // the cassette the caller names
		if !errors.Is(err, os.ErrExist) {
			return f, err
		}
	}
}

// version is what claude --version says first ("2.1.312"), or "" when it
// can't say.
func version(claude string, env []string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, claude, "--version") //nolint:gosec // the caller's claude
	cmd.Env = env
	out, err := cmd.Output()
	if f := strings.Fields(string(out)); err == nil && len(f) > 0 {
		return f[0]
	}
	return ""
}

// cassette writes a cassette a line at a time, so what was written stays
// readable whenever the tee is killed.
type cassette struct {
	w     io.Writer
	start time.Time
	mu    sync.Mutex
	err   error // the first write that failed
}

// header writes the header: env's names only.
func (c *cassette) header(args, env []string, cli string) error {
	keys := make([]string, 0, len(env))
	for _, kv := range env {
		k, _, _ := strings.Cut(kv, "=")
		keys = append(keys, k)
	}
	slices.Sort(keys)
	if args == nil {
		args = []string{}
	}
	b, _ := json.Marshal(claudetest.Header{Argv: args, EnvKeys: slices.Compact(keys), CLI: cli})
	_, err := c.w.Write(append(b, '\n'))
	return err
}

// copy copies src to dst a line at a time, recording each line first (so
// a line is in the cassette before anything it causes).
func (c *cassette) copy(dir string, dst io.Writer, src io.Reader) {
	r := bufio.NewReaderSize(src, 64<<10)
	for {
		line, err := r.ReadBytes('\n')
		if len(line) > 0 {
			c.record(dir, line)
			if _, werr := dst.Write(line); werr != nil {
				return
			}
		}
		if err != nil {
			return
		}
	}
}

// failed is the first write that failed, or nil.
func (c *cassette) failed() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.err
}

// record writes a frame of line, unless it is blank.
func (c *cassette) record(dir string, line []byte) {
	text := strings.TrimSpace(string(line))
	if text == "" {
		return
	}
	frame := json.RawMessage(text)
	if !json.Valid(frame) {
		frame, _ = json.Marshal(text)
	}
	b, err := json.Marshal(claudetest.Frame{Dir: dir, MS: time.Since(c.start).Milliseconds(), Frame: frame})
	c.mu.Lock()
	defer c.mu.Unlock()
	if err == nil {
		_, err = c.w.Write(append(b, '\n'))
	}
	if err != nil && c.err == nil {
		c.err = err
	}
}
