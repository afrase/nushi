package servers

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"net/netip"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/ansi"
	"github.com/afrase/nushi/internal/launchfile"
	"github.com/afrase/nushi/internal/listeners"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/shellenv"
)

// launch finds the server a port and starts its program, directly (no
// shell), as resolve has it, with PORT. Its errors are StartErrors.
func (s *Service) launch(ctx context.Context, sv *server) error {
	e := sv.entry
	if err := launchfile.CheckCwd(sv.folder, e.Cwd); err != nil { // again: the folder may have changed since it was read
		return refuse("its folder", err)
	}
	port, err := s.pickPort(ctx, sv)
	if err != nil {
		return refuse("its port", err)
	}
	args := e.Args
	if port != e.Port {
		args = withPort(e.Args, port)
	}
	program, env := resolve(e, s.Env.Environ())
	env = shellenv.Merge(env, []string{"PORT=" + strconv.Itoa(port)})
	if program == "" {
		return refuse("its program isn't found", fmt.Errorf("%s isn't a program on the login shell's PATH", e.Command))
	}
	proc, err := s.Spawn(append([]string{program}, args...), e.Cwd, env, func() {})
	if err != nil {
		return refuse("its program didn't start", fmt.Errorf("starting it: %w", err))
	}
	leader, err := s.Procs.Get(proc.Pid())
	if err != nil {
		leader = model.Process{Pid: proc.Pid(), Pgid: proc.Pid()}
	}
	scheme := "http"
	if strings.HasPrefix(e.URL, "https:") {
		scheme = "https"
	}
	s.mu.Lock()
	sv.proc, sv.leader, sv.port = proc, leader, port
	sv.url = scheme + "://localhost:" + strconv.Itoa(port)
	sv.tree = []model.Process{leader}
	stopping := sv.stopping != "" // stopped while it started
	s.mu.Unlock()
	s.keep()
	go s.reap(sv)
	if stopping {
		go s.halt(sv)
	}
	return nil
}

// await waits for the server to answer on its port, dialing it with a
// backoff from 100 ms to a second: then it's running, unless its port is
// another program's. Past ReadyWithin it's running but not answering, and
// still looked at, so a late answer counts.
func (s *Service) await(sv *server) {
	wait := 100 * time.Millisecond
	late := time.After(s.ReadyWithin)
	for {
		select {
		case <-sv.ended:
			return
		case <-late:
			s.set(sv, NotAnswering, "")
		case <-time.After(wait):
			s.look(sv)
			if s.answers(sv.port, strings.HasPrefix(sv.url, "https:")) {
				s.ready(sv)
				return
			}
			wait = min(wait*2, time.Second)
		}
	}
}

// ready marks the server running, once the port it answers on is its
// own: a listener there outside its processes means another program
// answers, and the server is stopped.
func (s *Service) ready(sv *server) {
	s.look(sv)
	if s.foreign(sv) {
		s.mu.Lock()
		sv.err = fmt.Sprintf("another program answers on port %d", sv.port)
		s.mu.Unlock()
		slog.Info("dev server's port answered by another program", "server", sv.id)
		s.stop(sv, ByNushi)
		return
	}
	s.set(sv, Running, "")
	s.unreserve(sv)
	slog.Info("dev server answers", "server", sv.id)
	s.mu.Lock()
	to, url := sv.showTo, sv.url
	s.mu.Unlock()
	s.showAsked(to, url)
	tick := time.NewTicker(5 * time.Second)
	defer tick.Stop()
	for {
		select {
		case <-sv.ended:
			return
		case <-tick.C:
			s.look(sv)
		}
	}
}

// set moves a live server to state.
func (s *Service) set(sv *server, state State, why string) {
	s.mu.Lock()
	moved := sv.stopping == "" && sv.state != state && slices.Contains(s.alive, sv)
	if moved {
		sv.state, sv.err = state, why
	}
	s.mu.Unlock()
	if moved {
		s.changed(sv.folder)
	}
}

// answers says whether something answers HTTP on localhost's port: a
// connection on 127.0.0.1 or ::1, then a HEAD within 2 s, any response
// (or a TLS error: it speaks HTTPS) counting.
func (s *Service) answers(port int, https bool) bool {
	addr := ""
	for _, host := range []string{"127.0.0.1", "::1"} {
		at := net.JoinHostPort(host, strconv.Itoa(port))
		if dials(context.Background(), at) {
			addr = at
			break
		}
	}
	if addr == "" {
		return false
	}
	scheme := "http"
	if https {
		scheme = "https"
	}
	client := &http.Client{
		Timeout: 2 * time.Second,
		Transport: &http.Transport{DialContext: func(ctx context.Context, network, _ string) (net.Conn, error) {
			return (&net.Dialer{}).DialContext(ctx, network, addr)
		}},
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	defer client.CloseIdleConnections()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodHead, scheme+"://localhost:"+strconv.Itoa(port)+"/", http.NoBody)
	resp, err := client.Do(req)
	if err == nil {
		_ = resp.Body.Close()
		return true
	}
	return tlsError(err)
}

// tlsError says whether err is TLS's: the server speaks it, so it answers.
func tlsError(err error) bool {
	var header tls.RecordHeaderError
	var alert tls.AlertError
	var authority x509.UnknownAuthorityError
	var invalid x509.CertificateInvalidError
	var host x509.HostnameError
	return errors.As(err, &header) || errors.As(err, &alert) || errors.As(err, &authority) ||
		errors.As(err, &invalid) || errors.As(err, &host) || strings.Contains(err.Error(), "malformed HTTP response")
}

// dials says whether a connection to addr is taken.
func dials(ctx context.Context, addr string) bool {
	c, err := (&net.Dialer{Timeout: 300 * time.Millisecond}).DialContext(ctx, "tcp", addr)
	if err != nil {
		return false
	}
	_ = c.Close()
	return true
}

// foreign says whether a connection to localhost's port may reach another
// program than the server: a listener there outside its processes, or
// none of its own. Where listeners can't be read (another OS) it can't
// tell, and says no.
func (s *Service) foreign(sv *server) bool {
	if s.Listeners == nil {
		return false
	}
	ls, err := s.Listeners()
	if err != nil {
		return false
	}
	below, _ := s.Procs.Under(sv.leader.Pid)
	tree := listeners.Procs{Root: sv.leader.Pid, Below: below}
	port := uint16(sv.port) //nolint:gosec // a port, 1 to 65535
	mine := false
	for _, a := range []netip.Addr{netip.AddrFrom4([4]byte{127, 0, 0, 1}), netip.IPv6Loopback()} {
		in, out := tree.Split(listeners.Reaching(ls, netip.AddrPortFrom(a, port)))
		if len(out) > 0 {
			return true
		}
		mine = mine || len(in) > 0
	}
	return !mine
}

// look notes the server's processes as they are now, for its stop and
// the record (a child that left its terminal is still among them).
func (s *Service) look(sv *server) {
	below, err := s.Procs.Under(sv.leader.Pid)
	if err != nil {
		return
	}
	tree := append([]model.Process{sv.leader}, below...)
	for i := range tree {
		tree[i].Args = nil
	}
	s.mu.Lock()
	was := slices.Clone(sv.tree)
	s.mu.Unlock()
	tree = s.mergeTree(was, tree) // reads the processes: not under the lock
	s.mu.Lock()
	same := slices.EqualFunc(tree, sv.tree, func(a, b model.Process) bool { return a.Pid == b.Pid && a.Started.Equal(b.Started) })
	if !same {
		sv.tree = tree
	}
	s.mu.Unlock()
	if !same {
		s.keep()
	}
}

// mergeTree is the processes of was and now, each once: one seen before
// that has since left the tree (a setsid child whose parent ended) is
// still the server's while it runs; one that ended is dropped, so the list
// doesn't grow with each short-lived child.
func (s *Service) mergeTree(was, now []model.Process) []model.Process {
	out := slices.Clone(now)
	for _, p := range was {
		if slices.ContainsFunc(out, func(q model.Process) bool { return q.Pid == p.Pid && q.Started.Equal(p.Started) }) {
			continue
		}
		if q, err := s.Procs.Get(p.Pid); err == nil && q.Started.Equal(p.Started) {
			out = append(out, p)
		}
	}
	return out
}

// stop ends a server, by who: SIGTERM to its terminal's foreground group,
// then after StopGrace the terminal's hang-up (which kills what's left on
// it), then whatever of its processes is still there (a child that setsid
// out of the terminal). It returns once the server has ended.
func (s *Service) stop(sv *server, by string) {
	s.mu.Lock()
	first := sv.stopping == ""
	if first {
		sv.stopping = by
	}
	started := sv.proc != nil // else launch halts it once it has
	s.mu.Unlock()
	if first && started {
		s.halt(sv)
	}
	<-sv.ended
}

// halt is stop's work on a server whose program started, unless it ended
// since (end lets go of its terminal).
func (s *Service) halt(sv *server) {
	s.mu.Lock()
	proc := sv.proc
	s.mu.Unlock()
	if proc == nil {
		return
	}
	s.look(sv)
	_ = proc.Terminate()
	select {
	case <-proc.Done():
	case <-time.After(s.StopGrace):
	}
	proc.Close()
}

// reap waits for the server's program to end, then ends what it left,
// and lists the server as ended: stopped by whoever stopped it, else
// failed, with its last lines.
func (s *Service) reap(sv *server) {
	<-sv.proc.Done()
	sv.proc.Close()
	s.mu.Lock()
	tree := slices.Clone(sv.tree)
	s.mu.Unlock()
	s.Procs.Stop(tree)
	_, code := sv.proc.Exit()
	raw := written(sv.proc)
	s.mu.Lock()
	why, by := sv.err, sv.stopping
	switch {
	case why != "":
	case by != "":
	case sv.state == Starting:
		why = fmt.Sprintf("it ended (exit code %d) before answering on port %d", code, sv.port)
	default:
		why = fmt.Sprintf("it ended (exit code %d)", code)
	}
	s.mu.Unlock()
	s.end(sv, why, raw, code)
}

// fail ends a server that never started.
func (s *Service) fail(sv *server, why string) {
	s.end(sv, why, nil, 0)
}

// end lists a server as ended: failed with why, or stopped; raw is what
// it wrote, as its terminal kept it, nil when its program never started.
// It lets go of the terminal, whose scrollback (up to 2 MB) would stay
// with each ended server the folder keeps: its log has what's shown.
func (s *Service) end(sv *server, why string, raw []byte, code int) {
	var log []byte // no log: nothing ran
	if raw != nil {
		log = logTail(raw)
	}
	out := lastLines(log, keptLines, keptBytes)
	s.mu.Lock()
	s.alive = slices.DeleteFunc(s.alive, func(o *server) bool { return o == sv })
	for p, id := range s.reserved {
		if id == sv.id {
			delete(s.reserved, p)
		}
	}
	sv.state, sv.err, sv.output, sv.log, sv.exit, sv.proc = Stopped, why, out, log, code, nil
	if why != "" {
		sv.state = Failed
	}
	sv.by = sv.stopping
	if sv.by == "" && why == "" {
		sv.by = ByNushi
	}
	s.ended = slices.DeleteFunc(s.ended, func(o *server) bool { return o.key == sv.key })
	s.ended = append(s.ended, sv)
	if n := s.endedIn(sv.folder); n > PerFolder {
		i := slices.IndexFunc(s.ended, func(o *server) bool { return o.folder == sv.folder })
		s.ended = slices.Delete(s.ended, i, i+1)
	}
	s.mu.Unlock()
	s.keep()
	close(sv.ended)
	slog.Info("dev server ended", "server", sv.id, "by", sv.by, "failed", why != "", "exit", code)
	s.changed(sv.folder)
}

// endedIn is how many ended servers folder keeps.
func (s *Service) endedIn(folder string) int {
	n := 0
	for _, sv := range s.ended {
		if sv.folder == folder {
			n++
		}
	}
	return n
}

// Output kept of an ended server for its row: its last lines, without
// the terminal's escapes, at most so many and so long.
const (
	keptLines = 200
	keptBytes = 32 << 10
)

// written is what a program wrote so far, as its terminal keeps it;
// never nil.
func written(p Process) []byte {
	raw := []byte{}
	done := make(chan struct{})
	close(done)
	p.Attach(done, func(b []byte) bool { raw = append(raw, b...); return false })
	return raw
}

// lastLines is the last of a program's output as plain text: at most so
// many lines and size bytes, the line that size cuts left out.
func lastLines(raw []byte, lines, size int) string {
	text := strings.ReplaceAll(ansi.Strip(string(raw)), "\r\n", "\n")
	text = strings.ReplaceAll(text, "\r", "\n")
	all := strings.Split(strings.TrimRight(text, "\n"), "\n")
	if len(all) > lines {
		all = all[len(all)-lines:]
	}
	text = strings.Join(all, "\n")
	if len(text) > size {
		text = text[len(text)-size:]
		if i := strings.IndexByte(text, '\n'); i >= 0 {
			text = text[i+1:]
		}
	}
	return strings.ToValidUTF8(text, "")
}
