// Package chats runs chats: one agent session each, with its transcript.
package chats

import (
	"context"
	"crypto/rand"
	"fmt"
	"log/slog"
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

// Agent is a connection to a running agent (an *agentproc.Agent).
type Agent interface { //nolint:interfacebloat // the ACP calls a chat makes of its agent, which each Kind fills
	Initialize(context.Context, *acp.InitializeRequest) (*acp.InitializeResponse, error)
	NewSession(context.Context, *acp.NewSessionRequest) (*acp.NewSessionResponse, error)
	LoadSession(context.Context, *acp.LoadSessionRequest) (*acp.LoadSessionResponse, error)
	// StartPrompt returns once the prompt is written; wait returns its result.
	StartPrompt(context.Context, *acp.PromptRequest) (wait func(context.Context) (*acp.PromptResponse, error), err error)
	SetSessionConfigOption(context.Context, *acp.SetSessionConfigOptionRequest) (*acp.SetSessionConfigOptionResponse, error)
	SetSessionMode(context.Context, *acp.SetSessionModeRequest) (*acp.SetSessionModeResponse, error)
	ListSessions(context.Context, *acp.ListSessionsRequest) (*acp.ListSessionsResponse, error)
	Cancel(context.Context, *acp.CancelNotification) error
	CanSteer() bool
	Steer(context.Context, acp.SessionID, []acp.ContentBlock) (bool, error)
	CanFork() bool
	ForkSession(context.Context, *acp.ForkSessionRequest) (*acp.ForkSessionResponse, error)
	CloseSession(context.Context, *acp.CloseSessionRequest) (*acp.CloseSessionResponse, error)
	DeleteSession(context.Context, *acp.DeleteSessionRequest) (*acp.DeleteSessionResponse, error)
	Close() error // kills it
	// Stop ends it gently: it gets up to grace to end its sessions, then
	// is killed.
	Stop(grace time.Duration) error
	Done() <-chan struct{} // closed when the agent's process ends
	Pid() int              // its process, the root of the processes it runs; 0 when unknown
	// Call sends a request for one of the agent's extensions.
	Call(ctx context.Context, method string, params, result any) error
}

// stopGrace is how long a stopping agent gets to end a turn, and then its
// sessions.
var stopGrace = 5 * time.Second

// cancelTurn sends session/cancel, waiting at most stopGrace for the agent
// to read it.
//
//nolint:contextcheck // a cancel goes out on its own, as its turn ran: a stop outlives the request that asked for it
func cancelTurn(agent Agent, n *acp.CancelNotification) error {
	ctx, done := context.WithTimeout(context.Background(), stopGrace)
	defer done()
	return agent.Cancel(ctx, n)
}

// Launch starts an agent; what it sends goes to client, and what happens
// to it to log.
type Launch func(client acp.Client, log *slog.Logger) (Agent, error)

// Sessions stores what Nushi keeps of each chat.
type Sessions interface {
	SaveSession(model.Session) error
	Sessions() ([]model.Session, error)
	DeleteSession(id string) error
}

// Service holds the open chats, each with one of the agents.
type Service struct {
	kinds      []*kind // the first is the default
	remembered Remembered
	sessions   Sessions
	worktrees  Worktrees
	scratch    string // the folder that holds chats' scratch folders
	publish    func(model.Event)

	terminals Terminals   // set once at startup, if there are any
	viewers   Viewers     // set once at startup, for unseen turns' ends (seen.go)
	prefs     SleepPrefs  // set once at startup, if chats sleep
	copies    Copies      // set once at startup, if chats keep copies of their transcripts
	copiesOn  func() bool // whether they write them now

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

// CopyHistory copies the agent's own record of a session from one folder's
// history into another's, where the agent can fork it with the other folder
// as its cwd, and returns a function that removes the copy again.
type CopyHistory func(sessionID, from, to string) (remove func() error, err error)

type chat struct {
	acp.UnimplementedClient // what the agent asks of a chat, beyond sides.go's

	id       string // Nushi's id for the chat
	sid      string // the agent's session id
	kind     *kind  // the agent it runs, for good
	agent    Agent
	dialect  Dialect // kind's
	publish  func(model.Event)
	sessions Sessions
	// worktrees are the service's, for naming the chat's branch (branch.go).
	worktrees Worktrees
	copies    Copies      // the service's
	copiesOn  func() bool // and whether it writes them
	viewers   Viewers     // the service's

	mu           sync.Mutex
	items        []model.Item
	busy         bool                            // running a turn, or reopening or moving the session
	halting      bool                            // being deleted: never reopens
	stopping     bool                            // its agent is being stopped: nothing more goes to it
	held         bool                            // the last turn was stopped or failed: the queue waits for the next
	steering     bool                            // a steering worker hands the queue to the running turn
	sendingNow   int                             // SendNow prompts waiting on the turn they stop: the queue waits too
	ownTurn      bool                            // the agent works on its own, outside a turn of Nushi's
	ownNoted     bool                            // the transcript says so, since the last user message or usage report
	released     bool                            // the running turn's work ended, but the agent holds its prompt (Dialect.TurnDone)
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
	usage        model.Usage
	session      model.Session
	ultracode    atomic.Bool           // session.Ultracode, read where mu isn't held
	canFork      bool                  // the agent can fork the session into side chats
	canImage     bool                  // the agent takes images in prompts
	sides        map[string]*chat      // the chat's side chats, by session id
	children     map[string]*child     // its agent's subagents' sessions, by session id (children.go)
	parent       *chat                 // a side chat's chat
	started      time.Time             // when the running turn started
	background   int                   // subagents and background commands running, as last said
	done         chan struct{}         // closed when the running turn ends
	sent         chan struct{}         // closed once the running turn's prompt is written
	seq          int64                 // the last event's number
	lastItem     int                   // the last item id given (item-N), never reused
	probes       map[string]*silentRun // throwaway forks' runs, by session id
	queue        []model.Message       // waiting for the agent's next chance
	steer        bool                  // the agent takes messages into a running turn
	// forkAt is session/fork's meta to fork at a message, when the agent
	// can (see Dialect).
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
	replaying  bool             // a session/load's replay goes to replay, not the transcript (restore.go)
	replay     []model.Item
	quiet      bool // a replayed update is being taken: its events aren't the app's
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
	if e.Item != nil && c.copies != nil && c.parent == nil {
		c.unsaved[e.Item.ID] = true
	}
	c.publish(e)
	// A subagent or background command started or ended: the status says
	// how many run.
	if e.Item != nil && (e.Item.Shell != nil || e.Item.Subagent != nil) {
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
	return model.Chat{
		Session:  c.session,
		Items:    slices.Clone(c.items),
		Config:   slices.Clone(c.config),
		Commands: slices.Clone(c.commands),
		Usage:    c.usage,
		Status:   c.statusLocked(),
		Queue:    slices.Clone(c.queue),
		Seq:      c.seq,
	}, nil
}

// Start opens a chat with agent ("" for the default) in folder, or in a new
// scratch folder of its own when folder is "". With worktree, the chat gets
// a new git worktree of folder's repository and runs there.
func (s *Service) Start(ctx context.Context, agent, folder string, worktree bool) (string, error) {
	return s.StartOn(ctx, agent, folder, StartOptions{Worktree: worktree})
}

// StartOptions are a new chat's: a worktree of its own (on Branch, else
// a name of Nushi's; from From, a commit or ref, else the folder's HEAD),
// and the Jira issue or GitHub pull request or issue it's on, which it
// remembers.
type StartOptions struct {
	Worktree     bool
	Branch, From string
	Issue        *model.ChatIssue
	GitHub       *model.ChatGitHub
}

// StartOn is Start with options.
func (s *Service) StartOn(ctx context.Context, agent, folder string, opts StartOptions) (string, error) {
	k, err := s.kindOf(agent)
	if err != nil {
		return "", err
	}
	c := s.newChat(k)
	c.id, c.issue = rand.Text(), opts.Issue
	scratch := folder == ""
	var wt *model.Worktree
	switch {
	case scratch:
		folder = filepath.Join(s.scratch, c.id)
		err = os.MkdirAll(folder, 0o700)
	case opts.Worktree:
		if err = CheckFolder(folder); err == nil {
			wt, folder, err = s.addWorktree(ctx, folder, opts.Branch, opts.From)
		}
	default:
		if err = CheckFolder(folder); err == nil && s.worktrees != nil {
			wt = s.worktrees.Found(ctx, folder) // a worktree that was there: listed under its repository
		}
	}
	if err != nil {
		return "", err
	}
	o, err := c.openSession(ctx, "", folder, false)
	if err != nil {
		err = fmt.Errorf("couldn't start %s: %w", k.Title, err)
		if scratch {
			_ = os.Remove(folder) // a scratch folder: empty, or left for the user
		}
		s.dropWorktree(wt)
		return "", err
	}
	c.mu.Lock()
	s.useLocked(c, o)
	c.session = model.Session{ID: c.id, SessionID: o.sid, Agent: k.Name, Folder: folder, Created: time.Now(), Worktree: wt, Scratch: scratch, Issue: opts.Issue, GitHub: opts.GitHub}
	c.mu.Unlock()
	if err := c.reapply(ctx, o.agent, o.sid, s.remembered.Mode(k.Name), s.remembered.Picks(k.Name)); err != nil {
		c.log().Warn("starting mode", "err", err) // the chat keeps the agent's default
	}
	c.mu.Lock()
	c.saveLocked(c.modeLocked)
	c.storeLocked()
	c.mu.Unlock()
	s.mu.Lock()
	s.chats[c.id] = c
	s.mu.Unlock()
	c.log().Info("chat created", "scratch", scratch, "worktree", wt != nil)
	return c.id, nil
}

// CheckFolder refuses a folder that isn't an absolute path to an existing
// folder.
func CheckFolder(folder string) error {
	if fi, err := os.Stat(folder); err != nil || !fi.IsDir() || !filepath.IsAbs(folder) {
		return fmt.Errorf("%q is not an absolute path to a folder", folder)
	}
	return nil
}

func (s *Service) newChat(k *kind) *chat {
	return &chat{kind: k, dialect: k.Dialect, publish: s.publish, sessions: s.sessions, worktrees: s.worktrees, copies: s.copies, copiesOn: s.copiesOn, viewers: s.viewers, waiting: map[string]chan<- string{},
		questions: map[string]chan<- []model.Field{}, sides: map[string]*chat{}, children: map[string]*child{}, probes: map[string]*silentRun{}, unsaved: map[string]bool{}}
}

// List returns every stored chat.
func (s *Service) List() ([]model.Session, error) {
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
func (s *Service) Status(sess model.Session) model.Status {
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
func (c *chat) saveLocked(change func(*model.Session)) {
	next := c.session
	if change != nil {
		change(&next)
	}
	if !reflect.DeepEqual(next, c.session) {
		c.session = next
		c.storeLocked()
	}
}

func (c *chat) storeLocked() {
	if c.parent == nil { // side chats aren't stored
		if err := c.sessions.SaveSession(c.session); err != nil {
			c.logLocked().Error("saving the chat", "err", err)
		}
	}
	sess := c.session
	c.emitLocked(model.Event{ChatID: c.id, Session: &sess})
}

func (c *chat) usageChangedLocked() {
	u := c.usage
	c.emitLocked(model.Event{ChatID: c.id, Usage: &u})
}

func (c *chat) noticeLocked(reason, text string) {
	c.addLocked(model.Item{Kind: model.Notice, Status: reason, Text: text})
}

func (c *chat) statusLocked() model.Status {
	idle := c.agent == nil && !c.busy && c.parent == nil && !c.session.Archived
	return model.Status{Busy: c.busy, Started: c.started, Waiting: len(c.waiting)+len(c.questions) > 0, CanFork: c.canFork, Images: c.canImage,
		CanRewind: c.forkAt != nil, MCPChanged: c.mcpChanged, CanAskContext: !idle && c.canAskContextLocked() == nil,
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
	return it.Shell != nil && it.Shell.State == "running" || it.Subagent != nil && it.Subagent.State == "running"
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
	own := c.started.IsZero() && (c.ownTurn || len(c.waiting)+len(c.questions) > 0)
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
	c.items = append(c.items, it)
	c.emitLocked(model.Event{ChatID: c.id, Item: &it})
	c.copyLocked(false) // the items before it have settled
	return it.ID
}
