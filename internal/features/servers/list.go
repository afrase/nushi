package servers

import (
	"path/filepath"
	"slices"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/launchfile"
	"github.com/afrase/nushi/internal/shellenv"
)

// Row is one row of a folder's Servers menu: a launch file's entry, with
// its server's state when it runs or last ended, or a server whose entry
// has since gone from the files.
type Row struct {
	Name string
	// NameOK says the name is fit for a note or a tool's text
	// (launchfile.ValidName); one that isn't is shown marked.
	NameOK bool
	// Index is the entry's place in List's rows, Start's index; -1 for a
	// server whose entry is gone.
	Index  int
	Source launchfile.Source
	// Command and Args are the command as it will run (Program is the
	// program Start runs, resolve's, "" when there is none), in Cwd.
	Command, Program string
	Args             []string
	Cwd              string
	Env              map[string]string
	// Flagged are the keys of Env that change what a command runs
	// (flagged), sorted.
	Flagged []string
	URL     string
	Port    int
	// Attach is an entry with a url alone: a server already running,
	// nothing to run.
	Attach  bool
	Problem string // why the entry can't run, in launchfile's words
	// Hash is the entry's (launchfile's): Start's Pick names it, so what
	// runs is what was listed.
	Hash  string
	State State
	// Error is why it failed; Output its last lines, once it ended.
	Error, Output string
	ServerID      string // its live server's
	// LogID is the server whose output Watch gives: the live one's once
	// its program started, else the last one's that ran, while the folder
	// keeps it.
	LogID string
	// Changed says its entry changed (or went) since its server started:
	// a restart applies it.
	Changed bool
}

// Listing is a chat's folder's servers.
type Listing struct {
	Folder string
	Rows   []Row
	Files  []launchfile.File
}

// List reads a chat's folder's launch files afresh and lists their
// entries, merged with the folder's servers.
func (s *Service) List(chatID string) (Listing, error) {
	folder, main, err := s.place(chatID)
	if err != nil {
		return Listing{}, err
	}
	l, err := launchfile.Read(folder, main)
	if err != nil {
		return Listing{}, err
	}
	env := s.Env.Environ()
	out := Listing{Folder: folder, Files: l.Files}
	s.mu.Lock()
	defer s.mu.Unlock()
	seen := map[*server]bool{}
	for i, e := range l.Entries {
		r := entryRow(e, i, env)
		k := key(folder, e)
		if j := slices.IndexFunc(s.alive, func(sv *server) bool { return sv.key == k }); j >= 0 {
			sv := s.alive[j]
			seen[sv] = true
			sv.into(&r)
			r.Changed = sv.entry.Hash != e.Hash
		} else if j := slices.IndexFunc(s.ended, func(sv *server) bool { return sv.key == k }); j >= 0 {
			sv := s.ended[j]
			if sv.state == Failed {
				r.State, r.Error, r.Output = Failed, sv.err, sv.output
			}
			if sv.log != nil {
				r.LogID = sv.id
			}
		}
		out.Rows = append(out.Rows, r)
	}
	for _, sv := range s.alive {
		if sv.folder == folder && !seen[sv] {
			r := entryRow(sv.entry, -1, env)
			sv.into(&r)
			r.Changed = true
			out.Rows = append(out.Rows, r)
		}
	}
	return out, nil
}

// resolve is how an entry's command runs on base, the login shell's
// environment: the environment it gets (FORCE_COLOR, TERM, then the
// entry's env over base; launch adds PORT) and the program it names, found
// as the shell would on that environment's PATH (a relative path with a
// slash in Cwd), "" when none is. List shows the program Start runs: both
// take it from here.
func resolve(e launchfile.Entry, base []string) (program string, env []string) {
	env = shellenv.Merge(base, []string{"FORCE_COLOR=1", "TERM=xterm-256color"})
	own := make([]string, 0, len(e.Env))
	for k, v := range e.Env {
		own = append(own, k+"="+v)
	}
	slices.Sort(own)
	env = shellenv.Merge(env, own)
	command := e.Command
	if strings.Contains(command, "/") && !filepath.IsAbs(command) {
		command = filepath.Join(e.Cwd, command)
	}
	return shellenv.LookPath(command, env), env
}

// entryRow is an entry's row, its server not running.
func entryRow(e launchfile.Entry, index int, env []string) Row {
	r := Row{Name: e.Name, NameOK: launchfile.ValidName(e.Name), Index: index, Source: e.Source, Command: e.Command,
		Args: e.Args, Cwd: e.Cwd, Env: e.Env, Flagged: flagged(e.Env), URL: e.URL, Port: e.Port,
		Attach: e.Problem == "" && e.Command == "", Problem: e.Problem, Hash: e.Hash, State: Stopped}
	if e.Command != "" {
		r.Program, _ = resolve(e, env)
	}
	if r.URL == "" && e.Command != "" && e.Port > 0 {
		r.URL = "http://localhost:" + strconv.Itoa(e.Port)
	}
	return r
}

// into sets a live server's part of its row; under the service's lock.
func (sv *server) into(r *Row) {
	r.State, r.Error, r.ServerID = sv.state, sv.err, sv.id
	if sv.proc != nil {
		r.LogID = sv.id
	}
	if sv.port != 0 {
		r.Port, r.URL = sv.port, sv.url
	}
}

// row is a live server's row alone, Start's answer; under the service's
// lock.
func (sv *server) row() Row {
	r := entryRow(sv.entry, -1, nil)
	sv.into(&r)
	return r
}

// flagged is the keys of env that change what a command runs, whatever
// it says (docs/security.md): NODE_OPTIONS, PATH, DYLD_* and LD_*.
func flagged(env map[string]string) []string {
	var out []string
	for k := range env {
		if k == "NODE_OPTIONS" || k == "PATH" || strings.HasPrefix(k, "DYLD_") || strings.HasPrefix(k, "LD_") {
			out = append(out, k)
		}
	}
	slices.Sort(out)
	return out
}
