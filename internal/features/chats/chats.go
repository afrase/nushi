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
	names      func() string // a test's worktree names, in place of random ones
	scratch    string        // the folder that holds chats' scratch folders
	uploads    string        // the folder that holds chats' uploaded files (uploads.go)
	publish    func(model.Event)

	terminals Terminals   // set once at startup, if there are any
	servers   Servers     // set once at startup, if there are any
	gitHub    GitHub      // set once at startup
	viewers   Viewers     // Options', for chats done while nobody looked (seen.go)
	procs     Processes   // Options', for whether a command's shell runs and the crash record
	record    Record      // Options', if agents' processes are recorded (record.go)
	prefs     SleepPrefs  // Options', if chats sleep
	copies    Copies      // Options', if chats keep copies of their transcripts
	copiesOn  func() bool // whether they write them now
	timing    Timing      // Options'
	meter     Meter       // Options', if usage is kept (usage.go)
	begun     time.Time   // when it was made: the daemon's start (dormant)

	// ctx ends with Close, and with it what the service started on its own:
	// its loops, the background commands it follows, its timers.
	ctx    context.Context //nolint:containedctx // the service's life, which Close ends
	cancel context.CancelFunc
	loops  sync.WaitGroup // its loops (sleep, copies, letting go), which Close waits for
	// work is what a request left running when it ended (deleting thrown-away
	// sessions, a reopen, an expire it began), which Close waits for too: it
	// saves the chat's record, which must not be written once the daemon has
	// stopped (see later).
	work sync.WaitGroup

	// signInWaits, when set (a test), runs as a sign-in begins to wait for
	// an ended one's agent to stop (beginSignIn).
	signInWaits func()

	pinMu sync.Mutex // Pin's, one order at a time

	mu        sync.Mutex
	chats     map[string]*chat
	closing   bool        // Close began: no agent starts any more
	resting   atomic.Bool // Rest: no prompt is taken any more
	live      map[Agent]bool
	opening   map[string]bool     // sessions Open is making chats of
	signingIn map[string]*signIn  // the sign-in SignIn runs of each agent, by name
	removed   []model.RemovedChat // removed because their agent no longer had their sessions (gone.go)
	following int                 // apps following the events (Following)
	idle      *time.Timer         // closes the side chats once none has for Timing.SidesGrace
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

// GitHub is what the chats ask of GitHub (internal/features/github): the
// hosts Nushi gives a token to, as a pull request a chat's tool call
// opened on one is linked to the chat (ADR 0117); and what became of a
// pull request opened at or after since with a related worktree's branch
// as head: "merged", which a squash merge leaves git unable to see (issue
// 83), "open", or "".
type GitHub interface {
	Known(host string) bool
	BranchPull(ctx context.Context, folder, branch string, since time.Time) (string, error)
}

// UseGitHub tells the chats about GitHub.
func (s *Service) UseGitHub(g GitHub) { s.gitHub = g }

// gitHubHost is GitHubHosts.Known, false where there's none.
func (s *Service) gitHubHost(host string) bool {
	return s.gitHub != nil && s.gitHub.Known(host)
}

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
	// svc is the service the chat is one of, for what New gave it, which
	// never changes after (never its lock, nor what that covers).
	svc *Service
	// worktrees are the service's, for naming the chat's branch (branch.go).
	worktrees Worktrees
	copies    Copies      // the service's; nil for a side chat (copies.go)
	copiesOn  func() bool // and whether it writes them
	// gitHubHost is the service's, for a pull request a tool call opened.
	gitHubHost func(host string) bool

	mu           sync.Mutex
	items        []model.Item
	following    map[string]*follow              // workflows followed, by their call (workflows.go)
	op           chatOp                          // what it is busy with: a turn or a step on its session (ops.go)
	halting      bool                            // being deleted: never reopens
	historyStays bool                            // the last PlanDelete said the agent's history stays (delete.go)
	stopping     bool                            // its agent is being stopped: nothing more goes to it
	folder       string                          // what a git step does to its folder ("worktree is being removed"; holdFolder): it takes no prompts and doesn't reopen
	held         bool                            // the last turn was stopped or failed: the queue waits for the next
	steering     bool                            // a steering worker hands the queue to the running turn
	steerFailed  bool                            // a steer failed in the running turn: the rest waits for the next (queue.go)
	sendingNow   int                             // SendNow prompts waiting on the turn they stop: the queue waits too
	ownTurn      bool                            // the agent works on its own, outside a turn of Nushi's
	ownNoted     bool                            // the transcript says so, since the last user message or usage report
	turnFrom     int                             // the running turn's first item, about (items may go)
	stopped      bool                            // the running turn was told to stop: it ends with the agent's answer
	outlived     bool                            // the transcript outlived its agent: reopening doesn't replay into it
	reopenFailed bool                            // the last reopen failed: see failedLocked
	sessionGone  bool                            // and its agent no longer has its session: see goneLocked
	failure      string                          // the notice saying why it failed (item id)
	waiting      map[string]chan<- string        // permission prompts by item id, for the picked option
	drops        int                             // dropPromptsLocked's calls, for an ask that let go the lock (permissions.go)
	asking       map[string]int                  // the tool calls a permission prompt is pending for, by id: untimed meanwhile (call_times.go)
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
	background   int                   // subagents, background commands and workflows running, as last said
	workflows    int                   // workflows running, as last said
	tasks        map[string]taskWord   // the agent's word on its background commands' tasks, by its id (background.go)
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
	asleep     bool             // its agent was stopped to sleep, or it was left asleep at the daemon's start (dormant): opening the chat doesn't reopen it
	reapplying bool             // its session just opened: its picks aren't back on it yet (reapply)
	retiring   Agent            // the agent that last left it (disconnectLocked), until a reopen has seen it end
	woke       chan struct{}    // closed when the reopen or reload under way ends (endOpLocked)
	active     time.Time        // its last event
	unsaved    map[string]bool  // items changed since the copy of the transcript last had them (copies.go)
	tails      map[string]bool  // rows whose running command's output alone changed since: only a turn's or the agent's end writes them (copies.go)
	titling    map[string]bool  // pins whose title the agent is making, by item (pin_titles.go)
	titleSlots chan struct{}    // and how many it makes at once
	replaying  bool             // a session/load's replay goes to replay, not the transcript (restore.go)
	replay     []model.Item
	// replaySent is when the replay's messages were sent, as its chunks
	// tell it (SentReader), by message id: gathered with the replay,
	// cleared with it, for restoreLocked's date pass.
	replaySent map[string]time.Time
	muted      bool // a replayed update is being taken: its events aren't the app's

	// mirrored says the items, but for those unsaved and those that only
	// show, are the copy's as it stands; inCopy that they were let go, the
	// copy holding them, but for those set aside (letgo.go).
	mirrored bool
	inCopy   bool
	aside    []asideItem
	// unread says the copy couldn't be read when the transcript was made
	// from it: nothing is written to it then, as new items would go at
	// its start, before the history it holds (letgo.go).
	unread bool

	// One look at the related worktrees at a time (related.go): looking
	// holds it across git's runs; relating says a look of the chat's own
	// runs, relateAgain that another was asked for since, and relatedAt is
	// when one last started; pullsAfter is when a look may next ask GitHub
	// after it failed, lookedTips the default branch's commits the last look
	// saw, and pullsOpen the related worktrees (by path) whose pull request
	// GitHub said was open, with when each is asked again (all held by
	// looking).
	looking     sync.Mutex
	relating    bool
	relateAgain bool
	relatedAt   time.Time
	pullsAfter  time.Time
	lookedTips  []string
	pullsOpen   map[string]pullOpen
	// titled says the agent titled the session while the daemon ran, and
	// waitedTitle that a turn ended without that title, for naming the
	// chat's branch (branch.go).
	titled, waitedTitle bool

	// What its turns' usage needs (usage.go): costed says the agent has
	// reported the session's cost (usage.Cost); usageModel is the model
	// its usage reports last named (UsageReader); costFrom is the chat a
	// fork's session forked from, whose cost its first figure may carry;
	// project is the project folder of a side chat's chat, its turns'.
	costed                        bool
	usageModel, costFrom, project string
}

// emitLocked numbers and publishes one of the chat's events. Holding the
// lock keeps events in order and in step with snapshots.
func (c *chat) emitLocked(e model.Event) {
	if c.muted {
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
	// A subagent, background command or workflow started or ended: the
	// status says how many run.
	if e.Item != nil && (e.Item.BackgroundCommand != nil || e.Item.Subagent != nil || e.Item.Workflow != nil) {
		c.recountLocked()
	}
}

// recountLocked tells the status when the number of subagents, background
// commands or workflows that run changed.
func (c *chat) recountLocked() {
	if n, w := c.runningLocked(), c.workflowsLocked(); n != c.background || w != c.workflows {
		c.background, c.workflows = n, w
		c.statusChangedLocked()
	}
}

// Get returns a snapshot of a chat; one whose items were let go is read
// from its copy, without holding them (letgo.go).
func (s *Service) Get(chatID string) (model.Chat, error) {
	c, err := s.open(chatID)
	if err != nil {
		return model.Chat{}, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.inCopy {
		items, err := c.copyItemsLocked()
		if err != nil {
			return model.Chat{}, err
		}
		return c.snapshotLocked(items), nil
	}
	return c.snapshotLocked(slices.Clone(c.items)), nil
}

// snapshotLocked is the chat as it is, with items (the caller's copy) as
// its items.
func (c *chat) snapshotLocked(items []model.Item) model.Chat {
	return model.Chat{
		Record:   c.record,
		Items:    items,
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
// the commands Nushi runs in its place either way. A list remembered
// before its kind hid a command (CommandHider) is offered without it.
func (c *chat) commandsLocked() []model.Command {
	if len(c.commands) == 0 {
		return c.kind.withTerminalCommands(c.kind.offered(c.svc.remembered.Commands(c.kind.Name)))
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
	return &chat{kind: k, svc: s, publish: s.publish, worktrees: s.worktrees, copies: s.copies, copiesOn: s.copiesOn, gitHubHost: s.gitHubHost, waiting: map[string]chan<- string{},
		questions: map[string]chan<- []model.Field{}, sides: map[string]*chat{}, children: map[string]*child{}, probes: map[string]*silentRun{}, unsaved: map[string]bool{},
		mirrored: true} // a new chat's copy is as empty as its transcript
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

// storeLocked stores the chat's record and tells the app, unless the chat
// is being deleted (halting): once its file is gone a save would bring it
// back at the next start, so nothing is written then, and a delete that
// fails stores the record as it then is (unhaltLocked).
func (c *chat) storeLocked() {
	if c.halting {
		return
	}
	if c.parent == nil { // side chats aren't stored
		if err := c.svc.sessions.SaveSession(c.record); err != nil {
			c.logLocked().Error("saving the chat", "err", err)
		}
	}
	sess := c.record
	c.emitLocked(model.Event{ChatID: c.id, Record: &sess})
}

// unhaltLocked keeps a chat whose delete failed: what changed while it was
// going (storeLocked, copyLocked) is written now. The halt stopped the
// agent, and a turn it stopped skipped its copy: with no agent, what's left
// has settled, and all of it is written, as at a turn's end.
func (c *chat) unhaltLocked() {
	c.halting = false
	c.storeLocked()
	c.copyLocked(c.agent == nil)
}

func (c *chat) usageChangedLocked() {
	u := c.usage
	c.emitLocked(model.Event{ChatID: c.id, Usage: &u})
}

func (c *chat) noticeLocked(reason, text string) {
	c.addLocked(model.Item{Kind: model.Notice, Status: reason, Text: text})
}

func (c *chat) statusLocked() model.Status {
	idle := c.agent == nil && !c.busyLocked() && c.parent == nil && !c.record.Archived
	return model.Status{Busy: c.busyLocked(), Started: c.started, Waiting: c.waitsLocked(), CanFork: c.canFork, Images: c.canImage,
		CanRewind: c.forkAt != nil, MCPChanged: c.mcpChanged, CanAskContext: !idle && c.canAskContextLocked() == nil, CanWriteCommit: !idle && c.canWriteCommitLocked() == nil,
		Asleep: idle && !c.reopenFailed, ReopenFailed: idle && c.reopenFailed, SessionGone: idle && c.reopenFailed && c.sessionGone, CanSleep: c.parent == nil && c.canSleepLocked() == nil,
		Background: c.runningLocked(), Workflows: c.workflowsLocked(), OwnTurn: c.ownTurn}
}

// runningLocked counts the subagents, background commands and workflows
// that run.
func (c *chat) runningLocked() int {
	n := 0
	for i := range c.items {
		if running(c.items[i]) {
			n++
		}
	}
	return n
}

// workflowsLocked counts the workflows that run.
func (c *chat) workflowsLocked() int {
	n := 0
	for i := range c.items {
		if c.items[i].Workflow.Runs() {
			n++
		}
	}
	return n
}

// running says whether it is a subagent, background command or workflow
// that runs (a stalled workflow doesn't).
func running(it model.Item) bool {
	return it.BackgroundCommand != nil && it.BackgroundCommand.State == model.RunRunning || it.Subagent != nil && it.Subagent.State == model.RunRunning ||
		it.Workflow.Runs()
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
		if c.ownTurn {
			c.endOwnTurnLocked(model.TurnStopped, "")
		} else {
			c.statusChangedLocked() // a prompt it waited on alone
		}
		return cancelTurn(agent, cancel, c.svc.timing.stopGrace())
	}
	select {
	case <-c.sent:
		return cancelTurn(agent, cancel, c.svc.timing.stopGrace())
	default: // the cancel must not reach the agent before the prompt
		sent := c.sent
		go func() {
			<-sent
			if err := cancelTurn(agent, cancel, c.svc.timing.stopGrace()); err != nil {
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

// addLocked appends an item, giving it an id if it has none, and publishes
// it; the items come back first if they were let go.
func (c *chat) addLocked(it model.Item) string {
	c.itemsBackLocked()
	if it.ID == "" {
		c.lastItem++
		it.ID = "item-" + strconv.Itoa(c.lastItem)
	}
	if it.Kind == model.UserMessage {
		c.ownNoted = false
		it.ForkAt = c.forkPointLocked()
		it.Rewindable = it.ForkAt != "" || !slices.ContainsFunc(c.items, func(it model.Item) bool { return it.Kind == model.UserMessage })
	}
	if it.Kind == model.AgentMessage && !c.muted {
		it.Sent = time.Now() // a replay's say nothing of when; the copy's keep theirs
	}
	c.items = append(c.items, it)
	c.emitLocked(model.Event{ChatID: c.id, Item: &it})
	c.copyLocked(false) // the items before it have settled
	return it.ID
}
