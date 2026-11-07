// Package servers runs a folder's dev servers, the entries of its launch
// files (internal/launchfile, ADR 0095), on the user's Run (ADR 0098): each
// on a terminal of the daemon's, on a free port, watched until it answers.
// A server belongs to its folder: the chats in that folder share it, and
// it stops once none of them is left.
package servers

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log/slog"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/launchfile"
	"github.com/afrase/nushi/internal/listeners"
	"github.com/afrase/nushi/internal/model"
)

// Chats are the chats (internal/features/chats): whose folder a server
// runs in.
type Chats interface {
	Session(chatID string) (model.ChatRecord, error)
	List() ([]model.ChatRecord, error)
}

// Process is a server's program on a terminal (an *terminal.Terminal).
type Process interface {
	Pid() int
	Done() <-chan struct{}
	Exit() (exited bool, code int)
	// Terminate sends SIGTERM to the terminal's foreground group.
	Terminate() error
	Attach(stop <-chan struct{}, fn func([]byte) bool)
	// Close hangs the terminal up, and kills what's left on it.
	Close()
}

// Spawn starts argv in dir with env on a terminal; exited is called when
// the program ends.
type Spawn func(argv []string, dir string, env []string, exited func()) (Process, error)

// Procs reads and stops processes (proctree.Tree).
type Procs interface {
	Get(pid int) (model.Process, error)
	Under(root int) ([]model.Process, error)
	Args(pid int) []string
	Stop(ps []model.Process)
}

// Env is the login shell's environment (shellenv.Env).
type Env interface {
	Environ() []string
}

// Options are what New needs.
type Options struct {
	Chats   Chats
	Spawn   Spawn
	Procs   Procs
	Env     Env
	Publish func(model.Event)
	// Listeners lists localhost's listeners (listeners.List); one that
	// answers errors.ErrUnsupported skips the check that the port is the
	// server's own.
	Listeners func() ([]listeners.Listener, error)
	// Record is the file where running servers' processes are kept, for
	// the next daemon to stop after a crash (Sweep).
	Record string
}

// State is where a server is.
type State string

// A server's states.
const (
	Stopped      State = "stopped"
	Starting     State = "starting"
	Running      State = "running"
	NotAnswering State = "not_answering" // runs, but hasn't answered within ReadyWithin
	Failed       State = "failed"
)

// Who ended a server.
const (
	ByUser  = "user"
	ByNushi = "nushi"
)

// PerFolder is how many servers may run in one folder at once, and how
// many ended ones it keeps.
const PerFolder = 5

// Service runs the servers.
type Service struct {
	Options

	// ReadyWithin is how long a server has to answer before it shows as
	// running but not answering; StopGrace how long it has to end on
	// SIGTERM before its terminal hangs up.
	ReadyWithin, StopGrace time.Duration

	recordMu sync.Mutex // one write of the record at a time
	mu       sync.Mutex
	alive    []*server
	ended    []*server // the last PerFolder of each folder
	reserved map[int]string
	closed   bool // the daemon stops: no more starts
}

// New returns the service, with no server running.
func New(o Options) *Service {
	return &Service{Options: o, ReadyWithin: 180 * time.Second, StopGrace: 2 * time.Second, reserved: map[int]string{}}
}

// server is one run of a launch file's entry.
type server struct {
	id, folder, key string
	entry           launchfile.Entry
	port            int
	url             string
	chatID          string // the chat it was started from
	proc            Process
	leader          model.Process
	ended           chan struct{} // closed once it ended and is listed so

	// Under the service's lock.
	state    State
	err      string
	output   string          // its last lines, once it ended
	tree     []model.Process // its processes, as last seen
	stopping string          // who stops it
	exit     int
	by       string
}

// key is what makes two starts the same server: the folder and the
// entry's written name, without case; a derived name (which may repeat)
// with its place in its file.
func key(folder string, e launchfile.Entry) string {
	if e.NameDerived {
		return fmt.Sprintf("%s\x00%s\x00%d", folder, e.Source.Path, e.Source.Index)
	}
	return folder + "\x00" + strings.ToLower(e.Name)
}

// place is a chat's folder, and the main checkout's matching folder when
// the chat runs in a worktree (launchfile.Read's main).
func (s *Service) place(chatID string) (folder, main string, err error) {
	sess, err := s.Chats.Session(chatID)
	if err != nil {
		return "", "", err
	}
	if sess.Archived {
		return "", "", errors.New("the chat is archived")
	}
	if wt := sess.Worktree; wt != nil && wt.Repo != "" && wt.Repo != wt.Path {
		if rel, err := filepath.Rel(wt.Path, sess.Folder); err == nil && filepath.IsLocal(rel) {
			main = filepath.Join(wt.Repo, rel)
		}
	}
	return sess.Folder, main, nil
}

// changed tells the app a folder's servers changed.
func (s *Service) changed(folder string) {
	if s.Publish != nil {
		s.Publish(model.Event{Servers: folder})
	}
}

// find returns the live server of id.
func (s *Service) find(id string) *server {
	s.mu.Lock()
	defer s.mu.Unlock()
	if i := slices.IndexFunc(s.alive, func(sv *server) bool { return sv.id == id }); i >= 0 {
		return s.alive[i]
	}
	return nil
}

// Pick says which entry Start starts: by Name (without case, the first
// of it) or, with Name "", by Index (List's). With Hash, only while the
// entry is the one listed with it (Row.Hash): the user runs what the menu
// showed, never what the file says since (docs/security.md).
type Pick struct {
	Name  string
	Index int
	Hash  string
}

// StartError is why Start refused or couldn't start a server: Kind in
// fixed words, for the log; Err in full, for the user, as it may quote the
// launch file (its command, its problem) or name another program.
type StartError struct {
	Kind string
	Err  error
}

func (e *StartError) Error() string { return e.Err.Error() }
func (e *StartError) Unwrap() error { return e.Err }

// refuse is err as a StartError of kind.
func refuse(kind string, err error) error {
	return &StartError{Kind: kind, Err: err}
}

// Start starts a chat's folder's entry, picked by pick, unless it runs
// already: then it is the one returned. It returns once the server's
// program started; it answers later (List's state).
func (s *Service) Start(ctx context.Context, chatID string, pick Pick) (Row, error) {
	folder, main, err := s.place(chatID)
	if err != nil {
		return Row{}, err
	}
	l, err := launchfile.Read(folder, main)
	if err != nil {
		return Row{}, refuse("the launch files can't be read", err)
	}
	i := pick.Index
	if pick.Name != "" {
		i = slices.IndexFunc(l.Entries, func(e launchfile.Entry) bool { return strings.EqualFold(e.Name, pick.Name) })
	}
	if i < 0 || i >= len(l.Entries) {
		return Row{}, refuse("no such entry", errors.New("no such server in the launch files"))
	}
	e := l.Entries[i]
	switch {
	case e.Problem != "":
		return Row{}, refuse("the entry can't run", errors.New(e.Problem))
	case pick.Hash != "" && pick.Hash != e.Hash:
		return Row{}, refuse("the entry changed", errors.New("the launch file changed since it was shown: look at it again"))
	case e.Command == "":
		return Row{}, refuse("the entry runs nothing", errors.New("this entry opens a server already running: it has nothing to run"))
	}
	sv := &server{id: rand.Text()[:12], folder: folder, key: key(folder, e), entry: e, chatID: chatID, state: Starting, ended: make(chan struct{})}
	s.mu.Lock()
	switch {
	case s.closed:
		s.mu.Unlock()
		return Row{}, refuse("the daemon is stopping", errors.New("the daemon is stopping"))
	case slices.ContainsFunc(s.alive, func(o *server) bool { return o.key == sv.key }):
		o := s.alive[slices.IndexFunc(s.alive, func(o *server) bool { return o.key == sv.key })]
		row := o.row()
		s.mu.Unlock()
		row.Index = i
		return row, nil // a start of one that runs: the same server
	case s.count(folder) >= PerFolder:
		s.mu.Unlock()
		return Row{}, refuse("the folder runs its most", fmt.Errorf("%d servers already run in this folder: stop one first", PerFolder))
	}
	s.alive = append(s.alive, sv)
	s.mu.Unlock()
	s.changed(folder)
	if err := s.launch(ctx, sv); err != nil {
		s.fail(sv, err.Error(), "")
		return Row{}, err
	}
	slog.Info("dev server started", "server", sv.id, "chat", chatID, "pid", sv.leader.Pid)
	go s.await(sv) //nolint:contextcheck // the server outlives the call that started it
	s.mu.Lock()
	row := sv.row()
	s.mu.Unlock()
	row.Index = i
	return row, nil
}

// count is how many servers live in folder.
func (s *Service) count(folder string) int {
	n := 0
	for _, sv := range s.alive {
		if sv.folder == folder {
			n++
		}
	}
	return n
}

// Stop stops a server of a chat's folder, the user's doing.
func (s *Service) Stop(chatID, serverID string) error {
	folder, _, err := s.place(chatID)
	if err != nil {
		return err
	}
	sv := s.find(serverID)
	if sv == nil || sv.folder != folder {
		return errors.New("no such server runs in this chat's folder")
	}
	s.stop(sv, ByUser)
	return nil
}

// StopAll stops every server of a chat's folder, the user's doing.
func (s *Service) StopAll(chatID string) error {
	folder, _, err := s.place(chatID)
	if err != nil {
		return err
	}
	s.stopWhere(func(sv *server) bool { return sv.folder == folder }, ByUser)
	return nil
}

// stopWhere stops the live servers which says yes to, together.
func (s *Service) stopWhere(which func(*server) bool, by string) {
	s.mu.Lock()
	gone := slices.DeleteFunc(slices.Clone(s.alive), func(sv *server) bool { return !which(sv) })
	s.mu.Unlock()
	var wg sync.WaitGroup
	for _, sv := range gone {
		wg.Go(func() { s.stop(sv, by) })
	}
	wg.Wait()
}

// Within says whether a server lives in dir or a folder in it: a worktree
// with one isn't removed by a move (chats' inUse).
func (s *Service) Within(dir string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.ContainsFunc(s.alive, func(sv *server) bool { return within(sv.folder, dir) })
}

// StopWithin stops the servers in dir or a folder in it, before dir is
// removed.
func (s *Service) StopWithin(dir string) {
	s.stopWhere(func(sv *server) bool { return within(sv.folder, dir) }, ByNushi)
}

func within(folder, dir string) bool {
	rel, err := filepath.Rel(dir, folder)
	return err == nil && filepath.IsLocal(rel)
}

// Follow takes every event: a chat archived, moved or deleted may leave a
// folder without chats, whose servers then stop.
func (s *Service) Follow(e model.Event) {
	if !e.Removed && e.Record == nil {
		return
	}
	s.mu.Lock()
	none := len(s.alive) == 0
	s.mu.Unlock()
	if !none {
		go s.release()
	}
}

// release stops the servers of folders no unarchived chat has.
func (s *Service) release() {
	list, err := s.Chats.List()
	if err != nil {
		return
	}
	used := map[string]bool{}
	for _, c := range list {
		if !c.Archived {
			used[c.Folder] = true
		}
	}
	s.stopWhere(func(sv *server) bool { return !used[sv.folder] }, ByNushi)
}

// Busy says whether a server runs: it holds the daemon's restart, as a
// terminal running a command does (ADR 0056, ADR 0098).
func (s *Service) Busy() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.alive) > 0
}

// Running says which servers run, for the restart's wait to show: each
// with a chat in its folder, the one it was started from while that is
// still there (a server outlives it when another chat shares the folder).
func (s *Service) Running() []model.Hold {
	s.mu.Lock()
	alive := slices.Clone(s.alive)
	s.mu.Unlock()
	if len(alive) == 0 {
		return nil
	}
	in := map[string][]string{} // folder: its unarchived chats
	if list, err := s.Chats.List(); err == nil {
		for _, c := range list {
			if !c.Archived {
				in[c.Folder] = append(in[c.Folder], c.ID)
			}
		}
	}
	out := make([]model.Hold, 0, len(alive))
	for _, sv := range alive {
		chat := sv.chatID
		if here := in[sv.folder]; len(here) > 0 && !slices.Contains(here, chat) {
			slices.Sort(here)
			chat = here[0]
		}
		out = append(out, model.Hold{ChatID: chat, Why: "a dev server runs"})
	}
	return out
}

// CloseAll stops every server and starts none after (the daemon stops).
func (s *Service) CloseAll() {
	s.mu.Lock()
	s.closed = true
	s.mu.Unlock()
	s.stopWhere(func(*server) bool { return true }, ByNushi)
}
