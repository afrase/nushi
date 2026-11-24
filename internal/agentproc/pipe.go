package agentproc

import (
	"io"
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
// stdin and stdout in the program's own protocol, in a group of its own
// (acp-go's process.Group: a process group on Unix, a job object on
// Windows), as an agent runs: what it left in its group ends as it exits.
type Piped struct {
	In  io.WriteCloser
	Out io.Reader
	Pid int

	group  *process.Group
	said   tail
	exited chan struct{}
	err    error // how it exited; set before exited closes
}

// drainAfter is the clock of the wait for a reader of an exited
// program's stdout (nil: time.After); a test's own.
var drainAfter func(time.Duration) <-chan time.Time

// Pipe starts bin with args in dir and env (nil: this process's), in a
// group of its own, so what it starts goes with it, as acp-go starts an
// agent (process.Start's lifecycle; on Windows an npm shim runs as node
// and its script, batchfile.Guard). Its stderr goes to stderr (nil:
// dropped), its last line kept for Said.
func Pipe(bin string, args []string, dir string, env []string, stderr io.Writer) (*Piped, error) {
	cmd := exec.Command(bin, args...) //nolint:gosec,noctx // lives until Kill, not a context; the program its caller chose
	cmd.Dir, cmd.Env = dir, env
	p := &Piped{exited: make(chan struct{})}
	cmd.Stderr = &p.said
	if stderr != nil {
		cmd.Stderr = io.MultiWriter(stderr, &p.said)
	}
	cmd.WaitDelay = waitDelay
	batchfile.Guard(cmd)
	process.OwnGroup(cmd)
	pipes, err := process.Start(cmd, false)
	if err != nil {
		return nil, err
	}
	p.group = process.NewGroup(cmd)
	out := &stdout{ReadCloser: pipes.Stdout, ended: make(chan struct{})}
	p.In, p.Out, p.Pid = pipes.Stdin, out, cmd.Process.Pid
	after := drainAfter // read here, not by the goroutine: a test sets it
	go func() {
		p.err = cmd.Wait()
		close(p.exited)
		_ = p.group.Sweep() // what it left in its group, which may hold its stdout
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

// Kill kills its group and waits for it to exit. Pi and Ante call it on
// every stop, often after the program has exited: its group was swept
// then, and the program alone is signalled, which does nothing once it
// was waited for, so no group that took its id since is reached.
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
