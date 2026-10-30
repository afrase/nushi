package claudeagent

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"sync/atomic"
)

// Spec is how to start claude: the program, its arguments after its name,
// its environment and its folder, and whether it shares this process's
// group (Options.SharedGroup).
type Spec struct {
	Path        string
	Args        []string
	Env         []string
	Dir         string
	SharedGroup bool
}

// Proc is a started claude: its pipes, and the Process to wait for and
// signal. Stdout and Stderr are read until they end, and closed early
// only to give up on them.
type Proc struct {
	Stdin  io.WriteCloser
	Stdout io.ReadCloser
	Stderr io.ReadCloser
	Process
}

// Process is a started claude's process.
type Process interface {
	// Wait waits for it to exit, once: nil when it exits with 0, an
	// *ExitError when it exits with another code or is killed.
	Wait() error
	// Signal sends it a signal: to its process group, where there is one.
	// After it has exited Signal returns os.ErrProcessDone.
	Signal(sig os.Signal) error
}

// Spawner starts claude. ctx bounds the start only, not the process's
// life. Exec is the real one; claudetest.Fake runs a script instead.
type Spawner func(ctx context.Context, s Spec) (*Proc, error)

// ExitError is how claude ended when it didn't exit with 0.
type ExitError struct {
	Code   int       // its exit code; -1 when a signal killed it
	Signal os.Signal // the signal that killed it, or nil
	Stderr string    // the end of what it wrote on stderr
	// Result is the text of the last result claude reported as an error,
	// which says more than the exit code.
	Result string
}

func (e *ExitError) Error() string {
	switch {
	case e.Result != "":
		return "claude returned an error result: " + e.Result
	case e.Signal != nil:
		return fmt.Sprintf("claude ended on a signal (%v)%s", e.Signal, stderrSuffix(e.Stderr))
	default:
		return fmt.Sprintf("claude exited with code %d%s", e.Code, stderrSuffix(e.Stderr))
	}
}

func stderrSuffix(s string) string {
	if s == "" {
		return ""
	}
	return ": " + s
}

// Exec starts s as a process in a group of its own, so a signal reaches
// what claude started in that group too (its stdio MCP servers, its
// hooks). Claude Code runs each Bash command detached, leading a group of
// its own, so no signal to claude's group reaches those. Once claude has
// exited, Wait kills what it left in the group.
//
// With s.SharedGroup claude stays in this process's group instead: what
// kills that group kills claude and what stays in its group too, even
// when this process is killed first, but not claude's Bash commands.
// Signal then reaches claude alone, and what claude leaves running is
// left to that kill.
func Exec(ctx context.Context, s Spec) (*Proc, error) {
	// The process outlives the start, so ctx's end mustn't kill it.
	cmd := exec.CommandContext(context.WithoutCancel(ctx), s.Path, s.Args...) //nolint:gosec // running the user's claude is the point
	cmd.Env, cmd.Dir = s.Env, s.Dir
	if !s.SharedGroup {
		ownGroup(cmd)
	}
	// Our own pipes, not cmd's: Wait would close those under the readers.
	var files []*os.File
	var pipeErr error
	pipe := func() (r, w *os.File) {
		r, w, err := os.Pipe()
		if err != nil {
			pipeErr = cmp.Or(pipeErr, err)
			return nil, nil
		}
		files = append(files, r, w)
		return r, w
	}
	inR, inW := pipe()
	outR, outW := pipe()
	errR, errW := pipe()
	closeAll := func() {
		for _, f := range files {
			_ = f.Close()
		}
	}
	if pipeErr != nil {
		closeAll()
		return nil, fmt.Errorf("claudeagent: pipes for claude: %w", pipeErr)
	}
	cmd.Stdin, cmd.Stdout, cmd.Stderr = inR, outW, errW
	if err := cmd.Start(); err != nil {
		closeAll()
		return nil, fmt.Errorf("claudeagent: start %s: %w", s.Path, err)
	}
	for _, f := range []*os.File{inR, outW, errW} {
		_ = f.Close() // claude's ends
	}
	return &Proc{Stdin: inW, Stdout: outR, Stderr: errR, Process: &process{cmd: cmd, shared: s.SharedGroup}}, nil
}

// process is a claude Exec started.
type process struct {
	cmd    *exec.Cmd
	shared bool // in this process's group, not one of its own
	exited atomic.Bool
}

// Wait waits for claude, then kills what it left in its group.
func (p *process) Wait() error {
	err := p.cmd.Wait()
	p.exited.Store(true)
	if !p.shared {
		_ = killGroup(p.cmd) // what it left running
	}
	return exitError(err)
}

// Signal signals claude's group, or claude alone when the group is ours
// too.
func (p *process) Signal(sig os.Signal) error {
	if p.exited.Load() {
		return os.ErrProcessDone
	}
	if p.shared {
		return p.cmd.Process.Signal(sig)
	}
	return signalGroup(p.cmd, sig)
}

// exitError turns exec's error into an *ExitError.
func exitError(err error) error {
	var ee *exec.ExitError
	if !errors.As(err, &ee) {
		return err
	}
	e := &ExitError{Code: ee.ExitCode()}
	if sig := exitSignal(ee); sig != nil {
		e.Signal = sig
	}
	return e
}
