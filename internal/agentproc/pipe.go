package agentproc

import (
	"io"
	"os"
	"os/exec"
	"sync"
	"time"

	"github.com/afrase/acp-go/process"

	"github.com/afrase/nushi/internal/batchfile"
)

// waitDelay is how long Pipe's program's stderr is read after it exits,
// and how long a read of its stdout may then wait with nothing to read
// (a reader still handling what it read isn't cut off). Both are read to
// EOF: a child that left the group (an MCP server Ante started that
// daemonized) holds them open, and without the cut Kill and Wait would
// wait for that child too, and the reader would never end.
const waitDelay = time.Second

// Program is a program a bridge talks to (Ante's host, pi): its stdin and
// stdout, a way to kill it, and the last of what it wrote to stderr (nil:
// nothing kept), which says why it stopped when it did. A Piped's, or a
// test's fake.
type Program struct {
	In   io.WriteCloser
	Out  io.Reader
	Kill func()
	Said func() string
}

// Program is p as a Program.
func (p *Piped) Program() Program {
	return Program{In: p.In, Out: p.Out, Kill: p.Kill, Said: p.Said}
}

// Piped is a program started by Pipe, which a bridge talks to over its
// stdin and stdout in the program's own protocol.
type Piped struct {
	In  io.WriteCloser
	Out io.Reader
	Pid int

	group  group
	said   tail
	exited chan struct{}
	err    error // how it exited; set before exited closes
}

// drainAfter is the clock of the wait for a reader of an exited
// program's stdout (nil: time.After); a test's own.
var drainAfter func(time.Duration) <-chan time.Time

// Pipe starts bin with args in dir and env (nil: this process's), as
// acp-go starts an agent (process.Start's lifecycle; on Windows an npm
// shim runs as node and its script, batchfile.Guard). With own it runs in
// a group of its own (acp-go's process.Group: a process group on Unix, a
// job object on Windows), so what it starts goes with it, and what it
// left in the group ends as it exits: for a program the daemon runs
// itself. Without, it stays in this process's group, as a bridge's CLI
// does (a bridge runs in a group of its own, which the daemon's stop of
// it ends whole, the CLI and what it started included, as Claude's agent
// keeps claude, docs/facts/claude.md), and Kill kills the program alone.
// Its stderr goes to stderr (nil: dropped), its last line kept for Said.
func Pipe(bin string, args []string, dir string, env []string, stderr io.Writer, own bool) (*Piped, error) {
	cmd := exec.Command(bin, args...) //nolint:gosec,noctx // lives until Kill, not a context; the program its caller chose
	cmd.Dir, cmd.Env = dir, env
	p := &Piped{exited: make(chan struct{})}
	cmd.Stderr = &p.said
	if stderr != nil {
		cmd.Stderr = io.MultiWriter(stderr, &p.said)
	}
	cmd.WaitDelay = waitDelay
	batchfile.Guard(cmd)
	if own {
		process.OwnGroup(cmd)
	}
	pipes, err := process.Start(cmd, false)
	if err != nil {
		return nil, err
	}
	p.group = alone{cmd.Process}
	if own {
		p.group = process.NewGroup(cmd)
	}
	out := &stdout{ReadCloser: pipes.Stdout, ended: make(chan struct{})}
	p.In, p.Out, p.Pid = pipes.Stdin, out, cmd.Process.Pid
	after := drainAfter // read here, not by the goroutine: a test sets it
	go func() {
		p.err = cmd.Wait()
		close(p.exited)
		_ = p.group.Sweep() // what it left in its own group, which may hold its stdout
		// What it wrote last is still read, unless a read waits idle: a
		// process that left its group holds the pipe open.
		out.Drain(out.ended, waitDelay, after)
		_ = pipes.Stdout.Close()
		_ = pipes.Stdin.Close() // its bridge leaves it open
		p.group.Release()
	}()
	return p, nil
}

// stdout is Pipe's program's stdout, which says when its reader has come
// to the end (ended), for the wait after the exit.
type stdout struct {
	process.Watched
	once  sync.Once
	ended chan struct{}
}

func (s *stdout) Read(b []byte) (int, error) {
	n, err := s.Watched.Read(b)
	if err != nil {
		s.once.Do(func() { close(s.ended) })
	}
	return n, err
}

// group is how a Piped is killed: its own group (*process.Group), or the
// program alone.
type group interface {
	Kill() error
	Sweep() error
	Release()
}

// alone is a program in its caller's group, killed through its
// os.Process (never a raw pid: once the program was waited for, Kill does
// nothing). What it left goes when its caller's group does.
type alone struct{ p *os.Process }

func (a alone) Kill() error { return a.p.Kill() }
func (alone) Sweep() error  { return nil }
func (alone) Release()      {}

// Kill kills it, its own group with it, and waits for it to exit. A
// bridge calls it on every stop, often after the program has exited: an
// own group was swept then, and the program alone is signalled, which
// does nothing once it was waited for, so no group that took its id since
// is reached.
func (p *Piped) Kill() {
	_ = p.group.Kill() // the program may be gone already
	<-p.exited
}

// Wait waits for it to exit and says how: nil for status 0, else
// exec's "exit status 1" or "signal: killed" (or exec.ErrWaitDelay for
// status 0 with its stderr held open past waitDelay).
func (p *Piped) Wait() error {
	<-p.exited
	return p.err
}

// Said is the line of its stderr that says why it stopped, when it did
// ("Error: Failed to load extension …"): the last error-like line among
// its last lines, else its last, masked and cut (tail). It waits for the exit first (up
// to twice waitDelay), as a stopped program's stdout can end before the
// copy has its stderr's last line.
func (p *Piped) Said() string {
	select {
	case <-p.exited:
	case <-time.After(2 * waitDelay):
	}
	return p.said.String()
}
