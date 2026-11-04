package agentproc

import (
	"io"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"time"
)

// waitDelay is how long Pipe's program's stderr is read after it exits.
// Its stderr goes through a copy, which reads to EOF: a child that left
// the group (an MCP server Ante started that daemonized) holds it open,
// and without the cut Kill and Wait would wait for that child too.
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
	if p.Out, err = cmd.StdoutPipe(); err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	p.Pid = cmd.Process.Pid
	go func() {
		p.err = cmd.Wait()
		close(p.exited)
	}()
	return p, nil
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
