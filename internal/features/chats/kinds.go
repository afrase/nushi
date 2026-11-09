package chats

import (
	"context"
	"fmt"

	"github.com/afrase/nushi/internal/model"
)

// Kind is an agent Nushi can run: its harness, and what main wires in to
// run it here.
type Kind struct {
	Harness
	Launch Launch
	// MCP says its MCP servers are the ones the mcp feature shows and
	// changes.
	MCP bool
	// Explain adds to why the agent failed to start what may help: that
	// its CLI is a version it wasn't tested with. nil: nothing to add.
	Explain func(error) error
	// Ready says, quickly, why the agent can't start now (it isn't
	// installed or set up); nil when it can. nil: it always can.
	Ready func() error
}

// kind is a Kind the service runs, with what its harness can do resolved
// once by newKind. A nil field means it can't.
type kind struct {
	Kind
	model.HarnessInfo
	launch  Launch // Launch, refused once the service closes
	tools   Tools  // Nushi's own tools for its chats' sessions; nil: none
	deletes *bool  // whether the agent deletes sessions, once known (under Service.mu)

	forker         Forker
	toolReader     ToolReader
	otherReader    OtherReader
	defaultReader  DefaultReader
	transcript     Transcript
	subagents      Subagents
	toSubagents    SubagentMessages
	background     BackgroundTasks
	contextCommand ContextCommander
	terminalCmds   TerminalCommands
	contextAsker   ContextAsker
	titleMaker     TitleMaker
	readOnly       ReadOnly
	goneReader     GoneReader
	openFinder     OpenFinder
	forkFinder     ForkFinder
	searcher       SessionSearcher
	historyChecker HistoryChecker
	messageDater   MessageDater
	worktreeFinder WorktreeFinder
}

// newKind asks k's harness what it can do, once: nothing else in this
// package asserts an interface of a harness.
func newKind(k Kind) *kind {
	h := k.Harness
	return &kind{Kind: k, HarnessInfo: h.Info(), forker: can[Forker](h), toolReader: can[ToolReader](h),
		otherReader: can[OtherReader](h), defaultReader: can[DefaultReader](h), transcript: can[Transcript](h), subagents: can[Subagents](h), toSubagents: can[SubagentMessages](h),
		background: can[BackgroundTasks](h), contextCommand: can[ContextCommander](h), terminalCmds: can[TerminalCommands](h), contextAsker: can[ContextAsker](h), titleMaker: can[TitleMaker](h), readOnly: can[ReadOnly](h), goneReader: can[GoneReader](h),
		openFinder: can[OpenFinder](h), forkFinder: can[ForkFinder](h), searcher: can[SessionSearcher](h), historyChecker: can[HistoryChecker](h),
		messageDater: can[MessageDater](h), worktreeFinder: can[WorktreeFinder](h)}
}

// can is h as a capability, a nil T when h hasn't it. Harnesses are values,
// so no nil pointer can pass for one that has it.
func can[T any](h Harness) T {
	t, _ := h.(T)
	return t
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
	Uploads    string            // the folder that holds chats' uploaded files ("": none taken, uploads.go)
	Publish    func(model.Event) // nil: events go nowhere
	Tools      Tools             // Nushi's own tools for chats' sessions
	Viewers    Viewers           // who shows chats, for chats done while nobody looked (seen.go)
	Processes  Processes         // nil: background commands are stopped only by asking the agent (background.go)
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
		scratch: o.Scratch, uploads: o.Uploads, publish: o.Publish, viewers: o.Viewers, procs: o.Processes, prefs: o.Sleep, copies: o.Copies, copiesOn: o.CopiesOn,
		chats: map[string]*chat{}, live: map[Agent]bool{}, opening: map[string]bool{}}
	s.ctx, s.cancel = context.WithCancel(ctx)
	if s.publish == nil {
		s.publish = func(model.Event) {}
	}
	if s.copiesOn == nil {
		s.copiesOn = func() bool { return true }
	}
	for _, k := range agents {
		kn := newKind(k)
		kn.launch, kn.tools = s.started(k.Launch), o.Tools
		s.kinds = append(s.kinds, kn)
	}
	if o.Sleep != nil {
		go s.autoSleep()
	}
	if o.Copies != nil && o.CopyDays != nil {
		go s.autoClearCopies(o.CopyDays)
	}
	if o.Copies != nil {
		go s.letGoUnseen()
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
