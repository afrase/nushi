package agentproc

import (
	"io"
	"os"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"time"
)

// waitDelay is how long Pipe's program's stderr is read after it exits,
// and how long its stdout is left to its reader after that. Both are read
// to EOF: a child that left the group (an MCP server Ante started that
// daemonized) holds them open, and without the cut Kill and Wait would
// wait for that child too, and the reader would never end.
const waitDelay = time.Second

// Piped is a program started by Pipe, which a bridge talks to over its
// stdin and stdout in the program's own protocol: its process group lives
// until Kill.
type Piped struct {
	In  io.WriteCloser
	Out io.Reader
	Pid int

	said   lastLine
	exited chan struct{}
	err    error // how it exited; set before exited closes
}

// Pipe starts bin with args in dir and env (nil: this process's), in a
// process group of its own, so what it starts goes with it on Kill. Its
// stderr goes to stderr (nil: dropped), its last line kept for Said.
func Pipe(bin string, args []string, dir string, env []string, stderr io.Writer) (*Piped, error) {
	cmd := exec.Command(bin, args...) //nolint:gosec,noctx // lives until Kill, not a context; the program its caller chose
	cmd.Dir, cmd.Env = dir, env
	p := &Piped{exited: make(chan struct{})}
	cmd.Stderr = &p.said
	if stderr != nil {
		cmd.Stderr = io.MultiWriter(stderr, &p.said)
	}
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
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
	err = cmd.Start()
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

// Kill kills its process group and waits for it to exit.
func (p *Piped) Kill() {
	_ = syscall.Kill(-p.Pid, syscall.SIGKILL) // the group may be gone already
	<-p.exited
}

// Wait waits for it to exit and says how: nil for status 0, else
// exec's "exit status 1" or "signal: killed" (or exec.ErrWaitDelay for
// status 0 with its stderr held open past waitDelay).
func (p *Piped) Wait() error {
	<-p.exited
	return p.err
}

// Said is the start of the last line it wrote to stderr that has anything
// in it ("Error: Failed to load extension …"), past a "Hint:" after it:
// what says why it stopped, when it did. It waits for the exit first (up
// to twice waitDelay), as a stopped program's stdout can end before the
// copy has its stderr's last line.
func (p *Piped) Said() string {
	select {
	case <-p.exited:
	case <-time.After(2 * waitDelay):
	}
	return p.said.String()
}

// lastLine keeps Said's line.
type lastLine struct {
	mu   sync.Mutex
	line []byte
	last string
}

func (l *lastLine) Write(b []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, c := range b {
		switch {
		case c == '\n':
			if s := strings.TrimSpace(string(l.line)); s != "" && !strings.HasPrefix(s, "Hint:") {
				l.last = s
			}
			l.line = l.line[:0]
		case len(l.line) < 500:
			l.line = append(l.line, c)
		}
	}
	return len(b), nil
}

func (l *lastLine) String() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.last
}
