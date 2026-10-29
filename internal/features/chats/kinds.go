package chats

import (
	"context"
	"fmt"

	"github.com/afrase/nushi/internal/model"
)

// Kind is an agent Nushi can run: how to start it, and what it does beyond
// ACP.
type Kind struct {
	Name    string // as chats keep it, such as "claude"
	Title   string // as people read it, such as "Claude"
	Launch  Launch
	Dialect Dialect
	// History copies a session to another folder's history for a move; nil
	// when the agent's sessions can't move.
	History CopyHistory
	// Resume is the terminal command that opens one of its sessions, given
	// the session id.
	Resume string
	// MCP says its MCP servers are the ones the mcp feature shows and
	// changes.
	MCP bool
	// DeleteArchives says its session/delete archives a session rather
	// than deleting it.
	DeleteArchives bool
	// OpenElsewhere says which of sessions ids a process of the agent's
	// holds open now, one this daemon didn't start (a terminal's): by
	// session id, where ("a terminal", "another app"). nil when that can't
	// be told.
	OpenElsewhere func(ids []string) map[string]string
	// Forked says which of sessions ids are forks of another session, so
	// Find leaves them out (only top-level sessions are listed; subagents'
	// the agents leave out themselves). nil when that can't be told.
	Forked func(ids []string) map[string]bool
	// OneWriter says the agent lets one process at a time write to a
	// session, so one open elsewhere isn't offered: Codex refuses a second
	// one, omp moves it to a new session.
	OneWriter bool
	// Explain adds to why the agent failed to start what may help: that
	// its CLI is a version it wasn't tested with. nil: nothing to add.
	Explain func(error) error
	// Ready says, quickly, why the agent can't start now (it isn't
	// installed or set up); nil when it can. nil: it always can.
	Ready func() error
	// Gone says a session/load error means the agent no longer has the
	// session (it deleted it). nil: never said.
	Gone func(error) bool
	// HistoryGone says, from the agent's own files alone, that it no
	// longer has session sid of folder, for certain: false whenever that
	// can't be told (its files for the folder missing or unreadable). nil:
	// its files aren't read; a chat's sessions are then found gone only by
	// reopening them (Gone).
	HistoryGone func(sid, folder string) bool
	// Expires says what deletes the agent's sessions on its own, such as
	// "Claude Code deletes sessions after 30 days by default"; "" if
	// nothing does.
	Expires string
}

// kind is a Kind the service runs.
type kind struct {
	Kind
	launch  Launch // Launch, refused once the service closes
	tools   Tools  // Nushi's own tools for its chats' sessions; nil: none
	deletes *bool  // whether the agent deletes sessions, once known (under Service.mu)
}

// explain is Explain's, for a failed start.
func (k *kind) explain(err error) error {
	if k.Explain == nil {
		return err
	}
	return k.Explain(err)
}

func (k *kind) ready() error {
	if k.Ready == nil {
		return nil
	}
	return k.Ready()
}

// Options are what the service works with besides its agents, all known
// at startup. Remembered and Sessions are needed; any other left zero is
// off.
type Options struct {
	Remembered Remembered
	Sessions   Sessions
	Worktrees  Worktrees         // nil: no chat in a new worktree
	Scratch    string            // the folder that holds chats' scratch folders
	Publish    func(model.Event) // nil: events go nowhere
	Tools      Tools             // Nushi's own tools for chats' sessions
	Viewers    Viewers           // who shows chats, for unseen turns' ends (seen.go)
	// Copies keeps copies of chats' transcripts while CopiesOn says so
	// (nil: always); CopyDays says after how many days unwritten one is
	// deleted (0: never), looked at now and each hour (copies.go).
	Copies   Copies
	CopiesOn func() bool
	CopyDays func() int
	// Sleep says how long a chat idles before its agent sleeps; nil: chats
	// sleep only when asked (sleep.go).
	Sleep SleepPrefs
}

// New makes the service for agents, the first of them the default. What
// it starts on its own (chats sleeping, old copies cleared, background
// commands followed) runs until Close or until ctx ends.
func New(ctx context.Context, agents []Kind, o Options) *Service {
	s := &Service{remembered: o.Remembered, sessions: o.Sessions, worktrees: o.Worktrees,
		scratch: o.Scratch, publish: o.Publish, viewers: o.Viewers, prefs: o.Sleep, copies: o.Copies, copiesOn: o.CopiesOn,
		chats: map[string]*chat{}, live: map[Agent]bool{}, opening: map[string]bool{}}
	s.ctx, s.cancel = context.WithCancel(ctx)
	if s.publish == nil {
		s.publish = func(model.Event) {}
	}
	if s.copiesOn == nil {
		s.copiesOn = func() bool { return true }
	}
	for _, k := range agents {
		s.kinds = append(s.kinds, &kind{Kind: k, launch: s.started(k.Launch), tools: o.Tools})
	}
	if o.Sleep != nil {
		go s.autoSleep()
	}
	if o.Copies != nil && o.CopyDays != nil {
		go s.autoClearCopies(o.CopyDays)
	}
	return s
}

// Agents returns the agents chats can run, the default first.
func (s *Service) Agents() []Kind {
	var out []Kind
	for _, k := range s.kinds {
		out = append(out, k.Kind)
	}
	return out
}

// kindOf returns the agent named name; "" is the default.
func (s *Service) kindOf(name string) (*kind, error) {
	for _, k := range s.kinds {
		if k.Name == name || name == "" {
			return k, nil
		}
	}
	return nil, fmt.Errorf("Nushi doesn't know the agent %q", name)
}
