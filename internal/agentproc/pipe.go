package agentproc

import (
	"io"
	"os"
	"os/exec"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/procgroup"
)

// waitDelay is how long Pipe's program's stderr is read after it exits,
// and how long its stdout is left to its reader after that. Both are read
// to EOF: a child that left the group (an MCP server Ante started that
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
// stdin and stdout in the program's own protocol: its process group lives
// until Kill.
type Piped struct {
	In  io.WriteCloser
	Out io.Reader
	Pid int

	group  *procgroup.Group
	said   tail
	exited chan struct{}
	err    error // how it exited; set before exited closes
}

// Pipe starts bin with args in dir and env (nil: this process's), in a
// group of its own (procgroup.Start: a process group on Unix, a job
// object on Windows), so what it starts goes with it on Kill. Its stderr goes to stderr (nil: dropped), its last line kept for
// Said.
func Pipe(bin string, args []string, dir string, env []string, stderr io.Writer) (*Piped, error) {
	cmd := exec.Command(bin, args...) //nolint:gosec,noctx // lives until Kill, not a context; the program its caller chose
	cmd.Dir, cmd.Env = dir, env
	p := &Piped{exited: make(chan struct{})}
	cmd.Stderr = &p.said
	if stderr != nil {
		cmd.Stderr = io.MultiWriter(stderr, &p.said)
	}
	cmd.WaitDelay = waitDelay
	var err error
	if p.In, err = cmd.StdinPipe(); err != nil {
		return nil, err
	}
	// Our own pipe, not cmd's: Wait closes that one as the program exits,
	// under a reader that hasn't yet read what it wrote last.
	r, w, err := os.Pipe()
	if err != nil {
		return nil, err
	}
	cmd.Stdout = w
	p.group, err = procgroup.Start(cmd)
	_ = w.Close() // the program has its own copy
	if err != nil {
		_ = r.Close()
		return nil, err
	}
	out := &stdout{f: r, ended: make(chan struct{})}
	p.Out, p.Pid = out, cmd.Process.Pid
	go func() {
		p.err = cmd.Wait()
		close(p.exited)
		select {
		case <-out.ended:
		case <-time.After(waitDelay):
		}
		_ = r.Close() // ends a read that a child holding stdout keeps waiting
	}()
	return p, nil
}

// stdout is the read end of Pipe's program's stdout, which says when its
// reader has come to the end.
type stdout struct {
	f     *os.File
	once  sync.Once
	ended chan struct{}
}

func (s *stdout) Read(b []byte) (int, error) {
	n, err := s.f.Read(b)
	if err != nil {
		s.once.Do(func() { close(s.ended) })
	}
	return n, err
}

// Kill kills its group (procgroup.Group's Kill) and waits for it to
// exit. Pi and Ante call it on every stop, often after the program has
// exited: what it left in its group goes then, and on Windows nothing is
// killed by a pid that may be another's by now.
func (p *Piped) Kill() {
	_ = p.group.Kill() // the group may be gone already
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
