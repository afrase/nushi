// Package chats runs chats: one agent session each, with its transcript.
package chats

import (
	"context"
	"crypto/rand"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strconv"
	"sync"
	"time"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// Agent is a connection to a running agent (an *acp.Client).
type Agent interface {
	Initialize(context.Context, acp.InitializeRequest) (*acp.InitializeResponse, error)
	NewSession(context.Context, acp.NewSessionRequest) (*acp.NewSessionResponse, error)
	LoadSession(context.Context, acp.LoadSessionRequest) (*acp.LoadSessionResponse, error)
	Prompt(context.Context, acp.PromptRequest) (*acp.PromptResult, error)
	SetConfigOption(context.Context, acp.SetSessionConfigOptionRequest) (*acp.SetSessionConfigOptionResponse, error)
	SetMode(context.Context, acp.SetSessionModeRequest) error
	Cancel(acp.CancelNotification) error
	CanSteer() bool
	Steer(context.Context, acp.SessionID, []acp.ContentBlock) (bool, error)
	CanFork() bool
	ForkSession(context.Context, acp.ForkSessionRequest) (*acp.ForkSessionResponse, error)
	CloseSession(context.Context, acp.CloseSessionRequest) error
	DeleteSession(context.Context, acp.DeleteSessionRequest) error
	Close() error
}

// Launch starts an agent; its session updates go to h.
type Launch func(h acp.Handler) (Agent, error)

// Sessions stores what Nushi keeps of each chat.
type Sessions interface {
	SaveSession(model.Session) error
	Sessions() ([]model.Session, error)
	DeleteSession(id string) error
}

// Service holds the open chats, all with one agent.
type Service struct {
	agent     string // the agent's name, such as "claude"
	launch    Launch
	modes     Modes
	sessions  Sessions
	history   CopyHistory
	worktrees Worktrees
	scratch   string // the folder that holds chats' scratch folders
	publish   func(model.Event)

	mu      sync.Mutex
	chats   map[string]*chat
	deletes *bool // whether the agent deletes sessions, once known
}

// CopyHistory copies the agent's own record of a session from one folder's
// history into another's, where the agent can fork it with the other folder
// as its cwd, and returns a function that removes the copy again.
type CopyHistory func(sessionID, from, to string) (remove func() error, err error)

func New(agent string, launch Launch, modes Modes, sessions Sessions, history CopyHistory, worktrees Worktrees, scratch string, publish func(model.Event)) *Service {
	return &Service{agent: agent, launch: launch, modes: modes, sessions: sessions, history: history, worktrees: worktrees,
		scratch: scratch, publish: publish, chats: map[string]*chat{}}
}

type chat struct {
	id       string // Nushi's id for the chat
	sid      string // the agent's session id
	agent    Agent
	publish  func(model.Event)
	sessions Sessions

	mu        sync.Mutex
	items     []model.Item
	busy      bool                            // running a turn, or reopening or moving the session
	waiting   map[string]chan<- string        // permission prompts by item id, for the picked option
	questions map[string]chan<- []model.Field // questions by item id, for the answer (nil: declined)
	config    []model.ConfigOption
	commands  []model.Command
	usage     model.Usage
	session   model.Session
	canFork   bool             // the agent can fork the session into side chats
	canImage  bool             // the agent takes images in prompts
	sides     map[string]*chat // the chat's side chats, by session id
	parent    *chat            // a side chat's chat
	started   time.Time        // when the running turn started
	done      chan struct{}    // closed when the running turn ends
	seq       int64            // the last event's number
	silent    *silentRun       // a prompt Nushi sent on its own, running
	queue     []model.Message  // waiting for the agent's next chance
	steer     bool             // the agent takes messages into a running turn
	canRewind bool             // the agent forks a session at a message
}

// emitLocked numbers and publishes one of the chat's events. Holding the
// lock keeps events in order and in step with snapshots.
func (c *chat) emitLocked(e model.Event) {
	c.seq++
	e.Seq = c.seq
	c.publish(e)
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

// Start opens a chat in folder, or in a new scratch folder of its own when
// folder is "". With worktree, the chat gets a new git worktree of folder's
// repository and runs there.
func (s *Service) Start(ctx context.Context, folder string, worktree bool) (string, error) {
	c := s.newChat()
	c.id = rand.Text()
	scratch := folder == ""
	var wt *model.Worktree
	var err error
	switch {
	case scratch:
		folder = filepath.Join(s.scratch, c.id)
		err = os.MkdirAll(folder, 0o700)
	case worktree:
		if err = checkFolder(folder); err == nil {
			wt, folder, err = s.addWorktree(ctx, folder)
		}
	default:
		err = checkFolder(folder)
	}
	if err != nil {
		return "", err
	}
	o, err := c.openSession(ctx, s.launch, "", folder, false)
	if err != nil {
		if scratch {
			os.Remove(folder)
		}
		s.dropWorktree(wt)
		return "", err
	}
	c.mu.Lock()
	c.useLocked(o)
	c.session = model.Session{ID: c.id, SessionID: o.sid, Agent: s.agent, Folder: folder, Created: time.Now(), Worktree: wt}
	c.mu.Unlock()
	if err := c.startMode(ctx, s.modes.Mode(s.agent)); err != nil {
		log.Printf("chat %s: starting mode: %v", c.id, err) // the chat keeps the agent's default
	}
	c.mu.Lock()
	c.saveLocked(nil)
	c.storeLocked()
	c.mu.Unlock()
	s.mu.Lock()
	s.chats[c.id] = c
	s.mu.Unlock()
	return c.id, nil
}

func checkFolder(folder string) error {
	if fi, err := os.Stat(folder); err != nil || !fi.IsDir() || !filepath.IsAbs(folder) {
		return fmt.Errorf("%q is not an absolute path to a folder", folder)
	}
	return nil
}

func (s *Service) newChat() *chat {
	return &chat{publish: s.publish, sessions: s.sessions, waiting: map[string]chan<- string{},
		questions: map[string]chan<- []model.Field{}, sides: map[string]*chat{}}
}

// Close stops every chat's agent.
func (s *Service) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, c := range s.chats {
		if c.parent == nil { // a side chat shares its chat's agent
			c.disconnect()
		}
	}
}

// List returns every stored chat.
func (s *Service) List() ([]model.Session, error) { return s.sessions.Sessions() }

// Status returns whether a chat works or waits on the user, without
// reopening it.
func (s *Service) Status(chatID string) model.Status {
	s.mu.Lock()
	c := s.chats[chatID]
	s.mu.Unlock()
	if c == nil {
		return model.Status{}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.statusLocked()
}

// saveLocked applies change (if any) to the chat's session, keeps its mode
// in step with the chat's mode option, and stores it if anything changed.
func (c *chat) saveLocked(change func(*model.Session)) {
	next := c.session
	if change != nil {
		change(&next)
	}
	if i := modeIndex(c.config); i >= 0 {
		next.Mode = c.config[i].Current
	}
	if !reflect.DeepEqual(next, c.session) {
		c.session = next
		c.storeLocked()
	}
}

func (c *chat) storeLocked() {
	if c.parent == nil { // side chats aren't stored
		if err := c.sessions.SaveSession(c.session); err != nil {
			log.Printf("chat %s: saving: %v", c.id, err)
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
	return model.Status{Busy: c.busy, Started: c.started, Waiting: len(c.waiting)+len(c.questions) > 0, CanFork: c.canFork, Images: c.canImage,
		CanRewind: c.canRewind}
}

func (c *chat) statusChangedLocked() {
	st := c.statusLocked()
	c.emitLocked(model.Event{ChatID: c.id, Status: &st})
}

// cancel stops the chat's running turn: the agent is told to stop, and the
// prompts it waits on are cancelled, as ACP asks of a client.
func (c *chat) cancel() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.cancelLocked()
}

func (c *chat) cancelLocked() error {
	if c.started.IsZero() || c.agent == nil {
		return nil // no turn runs
	}
	for _, answer := range c.waiting {
		answer <- ""
	}
	for _, answer := range c.questions {
		close(answer)
	}
	clear(c.waiting)
	clear(c.questions)
	return c.agent.Cancel(acp.CancelNotification{SessionID: acp.SessionID(c.sid)})
}

// itemLocked returns the item with id, or nil.
func (c *chat) itemLocked(id string) *model.Item {
	for i := range c.items {
		if c.items[i].ID == id {
			return &c.items[i]
		}
	}
	return nil
}

// addLocked appends an item, giving it an id if it has none, and publishes it.
func (c *chat) addLocked(it model.Item) string {
	if it.ID == "" {
		it.ID = "item-" + strconv.Itoa(len(c.items)+1)
	}
	if it.Kind == model.UserMessage {
		it.ForkAt = c.forkPointLocked()
	}
	c.items = append(c.items, it)
	c.emitLocked(model.Event{ChatID: c.id, Item: &it})
	return it.ID
}
