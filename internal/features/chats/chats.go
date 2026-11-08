// Package chats runs chats: one agent session each, with its transcript.
package chats

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// Sessions stores what Nushi keeps of each chat.
type Sessions interface {
	SaveSession(model.ChatRecord) error
	Sessions() ([]model.ChatRecord, error)
	DeleteSession(id string) error
}

// Service holds the open chats, each with one of the agents.
type Service struct {
	kinds      []*kind // the first is the default
	remembered Remembered
	sessions   Sessions
	worktrees  Worktrees
	scratch    string // the folder that holds chats' scratch folders
	uploads    string // the folder that holds chats' uploaded files (uploads.go)
	publish    func(model.Event)

	terminals Terminals   // set once at startup, if there are any
	servers   Servers     // set once at startup, if there are any
	viewers   Viewers     // Options', for chats done while nobody looked (seen.go)
	procs     Processes   // Options', for stopping background commands
	prefs     SleepPrefs  // Options', if chats sleep
	copies    Copies      // Options', if chats keep copies of their transcripts
	copiesOn  func() bool // whether they write them now

	// ctx ends with Close, and with it what the service started on its own:
	// its loops, the background commands it follows, its timers.
	ctx    context.Context //nolint:containedctx // the service's life, which Close ends
	cancel context.CancelFunc

	pinMu sync.Mutex // Pin's, one order at a time

	mu        sync.Mutex
	chats     map[string]*chat
	closing   bool        // Close began: no agent starts any more
	resting   atomic.Bool // Rest: no prompt is taken any more
	live      map[Agent]bool
	opening   map[string]bool     // sessions Open is making chats of
	removed   []model.RemovedChat // removed because their agent no longer had their sessions (gone.go)
	swept     time.Time           // the last Sweep
	sweeping  bool
	following int         // apps following the events (Following)
	idle      *time.Timer // closes the side chats once none has for SidesGrace
}

// Terminals are the shells beside chats (internal/features/terminals).
type Terminals interface {
	// Within says whether a terminal runs in dir or a folder in it.
	Within(dir string) bool
	// CloseChat ends a chat's terminals.
	CloseChat(chatID string)
}

// UseTerminals tells the chats about the terminals, which need the chats
// to be made first.
func (s *Service) UseTerminals(t Terminals) { s.terminals = t }

// Servers are the folders' dev servers (internal/features/servers, ADR
// 0098).
type Servers interface {
	// Within says whether a server runs in dir or a folder in it.
	Within(dir string) bool
	// StopWithin stops the servers in dir or a folder in it, and returns
	// once they ended.
	StopWithin(dir string)
	// Command is the command a chat's folder's entry of name runs, for
	// the card asking to run the agent's preview_start (ADR 0100); "" when
	// there's none. It keeps the ask, whose id goes to Answered. It reads
	// the chat (Session): never call it under a chat's lock.
	Command(chatID, name string) (command, askID string)
	// Answered takes the user's answer to an ask Command kept, before the
	// agent hears it: the start that follows runs only what the card
	// showed, and only if allowed.
	Answered(askID string, allowed bool)
}

// UseServers tells the chats about the dev servers, which need the chats
// to be made first.
func (s *Service) UseServers(sv Servers) { s.servers = sv }

// serverCommand is Servers.Command, "" where no servers run.
func (s *Service) serverCommand(chatID, name string) (command, askID string) {
	if s.servers == nil {
		return "", ""
	}
	return s.servers.Command(chatID, name)
}

// serverAnswered is Servers.Answered, for an ask serverCommand kept.
func (s *Service) serverAnswered(askID string, allowed bool) {
	if s.servers != nil && askID != "" {
		s.servers.Answered(askID, allowed)
	}
}

type chat struct {
	acp.UnimplementedClient // what the agent asks of a chat, beyond sides.go's

	id      string // Nushi's id for the chat
	sid     string // the agent's session id
	kind    *kind  // the agent it runs, for good
	agent   Agent
	publish func(model.Event)
	// remembered is the service's, for the commands the agent listed.
	remembered Remembered
	sessions   Sessions
	// worktrees are the service's, for naming the chat's branch (branch.go).
	worktrees Worktrees
	// owned lists the worktrees and folders that are a chat's own, for
	// related.go.
	owned    func(chatID string) ([]string, error)
	copies   Copies          // the service's; nil for a side chat (copies.go)
	copiesOn func() bool     // and whether it writes them
	viewers  Viewers         // the service's
	ctx      context.Context //nolint:containedctx // the service's life, which ends what the chat follows on its own
	// serverCommand and serverAnswered are the service's, for a
	// preview_start ask's card.
	serverCommand  func(chatID, name string) (command, askID string)
	serverAnswered func(askID string, allowed bool)

	mu           sync.Mutex
	items        []model.Item
	busy         bool                            // running a turn, or reopening or moving the session
	halting      bool                            // being deleted: never reopens
	stopping     bool                            // its agent is being stopped: nothing more goes to it
	removing     bool                            // its worktree is being removed (RemoveWorktree): it takes no prompts and doesn't reopen
	held         bool                            // the last turn was stopped or failed: the queue waits for the next
	steering     bool                            // a steering worker hands the queue to the running turn
	sendingNow   int                             // SendNow prompts waiting on the turn they stop: the queue waits too
	ownTurn      bool                            // the agent works on its own, outside a turn of Nushi's
	ownNoted     bool                            // the transcript says so, since the last user message or usage report
	released     bool                            // the running turn's work ended, but the agent holds its prompt (Transcript.TurnDone)
	steered      int                             // messages steered into the running turn since the agent's last result
	turnFrom     int                             // the running turn's first item, about (items may go)
	stopped      bool                            // the running turn was told to stop: it ends with the agent's answer
	kept         bool                            // the transcript outlived its agent: reopening doesn't replay into it
	reopenFailed bool                            // the last reopen failed: see failedLocked
	sessionGone  bool                            // and its agent no longer has its session: see goneLocked
	failure      string                          // the notice saying why it failed (item id)
	waiting      map[string]chan<- string        // permission prompts by item id, for the picked option
	questions    map[string]chan<- []model.Field // questions by item id, for the answer (nil: declined)
	config       []model.ConfigOption
	commands     []model.Command
	opening      bool                       // a session is being opened; its id isn't known yet
	early        []*acp.SessionNotification // what came before its id did (SessionUpdate)
	usage        model.Usage
	record       model.ChatRecord
	ultracode    atomic.Bool           // record.Ultracode, read where mu isn't held
	canFork      bool                  // the agent can fork the session into side chats
	canImage     bool                  // the agent takes images in prompts
	sides        map[string]*chat      // the chat's side chats, by session id
	children     map[string]*child     // its agent's subagents' sessions, by session id (children.go)
	parent       *chat                 // a side chat's chat
	base         []model.Item          // a side chat's: the chat's transcript as it forked, which a kept one starts with (forks.go)
	started      time.Time             // when the running turn started
	background   int                   // subagents and background commands running, as last said
	killed       []string              // background commands Nushi stopped since the last prompt, by the agent's id: told with the next (stopNote)
	edited       []string              // files the user saved in the preview since the last prompt: told with the next (editNote)
	done         chan struct{}         // closed when the running turn ends
	sent         chan struct{}         // closed once the running turn's prompt is written
	seq          int64                 // the last event's number
	lastItem     int                   // the last item id given (item-N), never reused
	probes       map[string]*silentRun // throwaway forks' runs, by session id
	queue        []model.Message       // waiting for the agent's next chance
	steer        bool                  // the agent takes messages into a running turn
	// forkAt is session/fork's meta to fork at a message, when the agent
	// can (see Forker).
	forkAt func(messageID string) map[string]any
	// mcpChanged says the MCP servers changed since the agent started.
	mcpChanged bool
	issue      *model.ChatIssue // the Jira issue it was started from; its tools are for it
	canLoad    bool             // the agent can reopen the session, so it can sleep
	asleep     bool             // its agent was stopped to sleep: opening the chat doesn't reopen it
	reapplying bool             // its session just opened: its picks aren't back on it yet (reapply)
	retired    <-chan struct{}  // closed once the agent it fell asleep from has ended
	woke       chan struct{}    // closed when the reopen under way ends
	active     time.Time        // its last event
	unsaved    map[string]bool  // items changed since the copy of the transcript last had them (copies.go)
	titling    map[string]bool  // pins whose title the agent is making, by item (pin_titles.go)
	titleSlots chan struct{}    // and how many it makes at once
	replaying  bool             // a session/load's replay goes to replay, not the transcript (restore.go)
	replay     []model.Item
	quiet      bool // a replayed update is being taken: its events aren't the app's

	// One look at the related worktrees at a time (related.go): looking
	// holds it across git's runs; relating says a look of the chat's own
	// runs, relateAgain that another was asked for since, and relatedAt is
	// when one last started.
	looking     sync.Mutex
	relating    bool
	relateAgain bool
	relatedAt   time.Time
	// titled says the agent titled the session while the daemon ran, and
	// waitedTitle that a turn ended without that title, for naming the
	// chat's branch (branch.go).
	titled, waitedTitle bool
}

// emitLocked numbers and publishes one of the chat's events. Holding the
// lock keeps events in order and in step with snapshots.
func (c *chat) emitLocked(e model.Event) {
	if c.quiet {
		return
	}
	c.seq++
	e.Seq = c.seq
	if e.Item != nil && !e.Append {
		e.Index = c.indexLocked(e.Item.ID)
	}
	c.active = time.Now()
	if e.Item != nil && c.copies != nil {
		c.unsaved[e.Item.ID] = true
	}
	c.publish(e)
	// A subagent or background command started or ended: the status says
	// how many run.
	if e.Item != nil && (e.Item.BackgroundCommand != nil || e.Item.Subagent != nil) {
		if n := c.runningLocked(); n != c.background {
			c.background = n
			c.statusChangedLocked()
		}
	}
}

// Get returns a snapshot of a chat.
func (s *Service) Get(chatID string) (model.Chat, error) {
	c, err := s.open(chatID)
	if err != nil {
		return model.Chat{}, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.snapshotLocked(0), nil
}

// snapshotLocked is the chat as it is, with its items from start on.
func (c *chat) snapshotLocked(start int) model.Chat {
	return model.Chat{
		Record:   c.record,
		Items:    slices.Clone(c.items[start:]),
		Config:   slices.Clone(c.config),
		Commands: c.commandsLocked(),
		Usage:    c.usage,
		Status:   c.statusLocked(),
		Queue:    slices.Clone(c.queue),
		Seq:      c.seq,
	}
}

// commandsLocked is what a chat's agent can be asked: what it listed, or
// until it has (a reopen can take a while, and its commands come last)
// what its kind listed last, so a chat offers them from the start; with
// the commands Nushi runs in its place either way.
func (c *chat) commandsLocked() []model.Command {
	if len(c.commands) == 0 {
		return c.kind.withTerminalCommands(c.remembered.Commands(c.kind.Name))
	}
	return slices.Clone(c.commands)
}

// checkFolder refuses a folder that isn't an absolute path to an existing
// folder.
func checkFolder(folder string) error {
	if fi, err := os.Stat(folder); err != nil || !fi.IsDir() || !filepath.IsAbs(folder) {
		return fmt.Errorf("%q is not an absolute path to a folder", folder)
	}
	return nil
}

func (s *Service) newChat(k *kind) *chat {
	return &chat{kind: k, remembered: s.remembered, publish: s.publish, sessions: s.sessions, worktrees: s.worktrees, owned: s.ownedWorktrees, copies: s.copies, copiesOn: s.copiesOn, viewers: s.viewers, ctx: s.ctx, serverCommand: s.serverCommand, serverAnswered: s.serverAnswered, waiting: map[string]chan<- string{},
		questions: map[string]chan<- []model.Field{}, sides: map[string]*chat{}, children: map[string]*child{}, probes: map[string]*silentRun{}, unsaved: map[string]bool{}}
}

// List returns every stored chat.
func (s *Service) List() ([]model.ChatRecord, error) {
	list, err := s.sessions.Sessions()
	for i := range list {
		list[i].Scratch = s.isScratch(list[i].Folder)
	}
	return list, err
}

// isScratch says whether folder is a chat's scratch folder.
func (s *Service) isScratch(folder string) bool { return filepath.Dir(folder) == s.scratch }

// Status returns whether a chat works or waits on the user, without
// reopening it. One not opened since the daemon started sleeps, unless it
// is archived.
func (s *Service) Status(sess model.ChatRecord) model.Status {
	s.mu.Lock()
	c := s.chats[sess.ID]
	s.mu.Unlock()
	if c == nil {
		return model.Status{Asleep: !sess.Archived}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.statusLocked()
}

// saveLocked applies change (if any) to the chat's session, and stores it
// if anything changed.
func (c *chat) saveLocked(change func(*model.ChatRecord)) {
	next := c.record
	if change != nil {
		change(&next)
	}
	if !reflect.DeepEqual(next, c.record) {
		c.record = next
		c.storeLocked()
	}
}

func (c *chat) storeLocked() {
	if c.parent == nil { // side chats aren't stored
		if err := c.sessions.SaveSession(c.record); err != nil {
			c.logLocked().Error("saving the chat", "err", err)
		}
	}
	sess := c.record
	c.emitLocked(model.Event{ChatID: c.id, Record: &sess})
}

func (c *chat) usageChangedLocked() {
	u := c.usage
	c.emitLocked(model.Event{ChatID: c.id, Usage: &u})
}

func (c *chat) noticeLocked(reason, text string) {
	c.addLocked(model.Item{Kind: model.Notice, Status: reason, Text: text})
}

func (c *chat) statusLocked() model.Status {
	idle := c.agent == nil && !c.busy && c.parent == nil && !c.record.Archived
	return model.Status{Busy: c.busy, Started: c.started, Waiting: c.waitsLocked(), CanFork: c.canFork, Images: c.canImage,
		CanRewind: c.forkAt != nil, MCPChanged: c.mcpChanged, CanAskContext: !idle && c.canAskContextLocked() == nil, CanWriteCommit: !idle && c.canWriteCommitLocked() == nil,
		Asleep: idle && !c.reopenFailed, ReopenFailed: idle && c.reopenFailed, SessionGone: idle && c.reopenFailed && c.sessionGone, CanSleep: c.parent == nil && c.canSleepLocked() == nil,
		Background: c.runningLocked()}
}

// runningLocked counts the subagents and background commands that run.
func (c *chat) runningLocked() int {
	n := 0
	for i := range c.items {
		if running(c.items[i]) {
			n++
		}
	}
	return n
}

// running says whether it is a subagent or background command that runs.
func running(it model.Item) bool {
	return it.BackgroundCommand != nil && it.BackgroundCommand.State == "running" || it.Subagent != nil && it.Subagent.State == "running"
}

func (c *chat) statusChangedLocked() {
	st := c.statusLocked()
	c.emitLocked(model.Event{ChatID: c.id, Status: &st})
}

// cancelLocked stops the chat's running turn, Nushi's or the agent's own
// (after a background task): the agent is told to stop, and the prompts it
// waits on are cancelled, as ACP asks of a client.
func (c *chat) cancelLocked() error {
	if c.agent == nil {
		return nil
	}
	own := c.started.IsZero() && (c.ownTurn || c.waitsLocked())
	if c.started.IsZero() && !own {
		return nil // no turn runs
	}
	c.stopped = !own
	c.dropPromptsLocked()
	agent, cancel := c.agent, &acp.CancelNotification{SessionID: acp.SessionID(c.sid)}
	if own {
		c.ownTurn = false
		c.statusChangedLocked()
		return cancelTurn(agent, cancel)
	}
	select {
	case <-c.sent:
		return cancelTurn(agent, cancel)
	default: // the cancel must not reach the agent before the prompt
		sent := c.sent
		go func() {
			<-sent
			if err := cancelTurn(agent, cancel); err != nil {
				c.log().Warn("cancelling the turn", "err", err)
			}
		}()
		return nil
	}
}

// itemLocked returns the item with id, or nil; nil for "" (every item
// has an id), without a look.
func (c *chat) itemLocked(id string) *model.Item {
	if id == "" {
		return nil
	}
	if i := c.indexLocked(id); i >= 0 {
		return &c.items[i]
	}
	return nil
}

// addLocked appends an item, giving it an id if it has none, and publishes it.
func (c *chat) addLocked(it model.Item) string {
	if it.ID == "" {
		c.lastItem++
		it.ID = "item-" + strconv.Itoa(c.lastItem)
	}
	if it.Kind == model.UserMessage {
		c.ownNoted = false
		it.ForkAt = c.forkPointLocked()
		it.Rewindable = it.ForkAt != "" || !slices.ContainsFunc(c.items, func(it model.Item) bool { return it.Kind == model.UserMessage })
	}
	if it.Kind == model.AgentMessage && !c.quiet {
		it.Sent = time.Now() // a replay's say nothing of when; the copy's keep theirs
	}
	c.items = append(c.items, it)
	c.emitLocked(model.Event{ChatID: c.id, Item: &it})
	c.copyLocked(false) // the items before it have settled
	return it.ID
}
