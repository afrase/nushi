// Package chats runs chats: one agent session each, with its transcript.
package chats

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
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
	Prompt(context.Context, acp.PromptRequest) (*acp.PromptResponse, error)
	SetConfigOption(context.Context, acp.SetSessionConfigOptionRequest) (*acp.SetSessionConfigOptionResponse, error)
	SetMode(context.Context, acp.SetSessionModeRequest) error
	Close() error
}

// Launch starts an agent; its session updates go to h.
type Launch func(h acp.Handler) (Agent, error)

// Sessions stores what Nushi keeps of each chat.
type Sessions interface {
	SaveSession(model.Session) error
	Sessions() ([]model.Session, error)
}

// Service holds the open chats, all with one agent.
type Service struct {
	agent    string // the agent's name, such as "claude"
	launch   Launch
	modes    Modes
	sessions Sessions
	publish  func(model.Event)

	mu    sync.Mutex
	chats map[string]*chat
}

func New(agent string, launch Launch, modes Modes, sessions Sessions, publish func(model.Event)) *Service {
	return &Service{agent: agent, launch: launch, modes: modes, sessions: sessions, publish: publish, chats: map[string]*chat{}}
}

type chat struct {
	id       string // the agent's session id
	agent    Agent
	publish  func(model.Event)
	sessions Sessions

	mu        sync.Mutex
	items     []model.Item
	busy      bool                            // running a turn, or reopening the session
	waiting   map[string]chan<- string        // permission prompts by item id, for the picked option
	questions map[string]chan<- []model.Field // questions by item id, for the answer (nil: declined)
	config    []model.ConfigOption
	session   model.Session
	lastError string // how the last turn failed
	seq       int64  // the last event's number
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
	c, err := s.chat(chatID)
	if err != nil {
		return model.Chat{}, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return model.Chat{
		Session: c.session,
		Items:   slices.Clone(c.items),
		Config:  slices.Clone(c.config),
		Status:  model.Status{Busy: c.busy, Error: c.lastError},
		Seq:     c.seq,
	}, nil
}

// Start launches an agent in folder and opens a session there.
func (s *Service) Start(ctx context.Context, folder string) (string, error) {
	if fi, err := os.Stat(folder); err != nil || !fi.IsDir() || !filepath.IsAbs(folder) {
		return "", fmt.Errorf("%q is not an absolute path to a folder", folder)
	}
	c := s.newChat()
	if _, err := c.connect(ctx, s.launch); err != nil {
		return "", err
	}
	sess, err := c.agent.NewSession(ctx, acp.NewSessionRequest{Cwd: folder, MCPServers: []acp.MCPServer{}})
	if err != nil {
		c.disconnect()
		return "", err
	}
	c.id = string(sess.SessionID)
	c.config = configFrom(sess.ConfigOptions, sess.Modes)
	c.session = model.Session{ID: c.id, Agent: s.agent, Folder: folder, Created: time.Now()}
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

func (s *Service) newChat() *chat {
	return &chat{publish: s.publish, sessions: s.sessions, waiting: map[string]chan<- string{}, questions: map[string]chan<- []model.Field{}}
}

// connect launches the chat's agent and initializes it.
func (c *chat) connect(ctx context.Context, launch Launch) (*acp.InitializeResponse, error) {
	agent, err := launch(c)
	if err != nil {
		return nil, fmt.Errorf("start agent: %w", err)
	}
	init, err := agent.Initialize(ctx, acp.InitializeRequest{
		ProtocolVersion:    acp.Version,
		ClientCapabilities: &acp.ClientCapabilities{Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}}},
		ClientInfo:         &acp.Implementation{Name: "nushi", Title: "Nushi"},
	})
	if err != nil {
		agent.Close()
		return nil, err
	}
	c.mu.Lock()
	c.agent = agent
	c.mu.Unlock()
	return init, nil
}

// disconnect stops the chat's agent.
func (c *chat) disconnect() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.agent != nil {
		c.agent.Close()
		c.agent = nil
	}
}

// Close stops every chat's agent.
func (s *Service) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, c := range s.chats {
		c.disconnect()
	}
}

// List returns every stored chat.
func (s *Service) List() ([]model.Session, error) { return s.sessions.Sessions() }

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
	if next != c.session {
		c.session = next
		c.storeLocked()
	}
}

func (c *chat) storeLocked() {
	if err := c.sessions.SaveSession(c.session); err != nil {
		log.Printf("chat %s: saving: %v", c.id, err)
	}
	sess := c.session
	c.emitLocked(model.Event{ChatID: c.id, Session: &sess})
}

// Prompt sends text to the chat's agent. The turn runs in the background;
// its progress arrives as events.
func (s *Service) Prompt(chatID, text string) error {
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.busy {
		return errors.New("the agent is still working on the last prompt")
	}
	c.busy = true
	c.addLocked(model.Item{Kind: model.UserMessage, Text: text})
	c.saveLocked(func(s *model.Session) {
		if s.Title == "" {
			s.Title = title(text)
		}
	})
	c.emitLocked(model.Event{ChatID: c.id, Status: &model.Status{Busy: true}})
	go c.run(text)
	return nil
}

// title makes a chat's title from its first prompt: the first line, cut short.
func title(prompt string) string {
	line, _, _ := strings.Cut(strings.TrimSpace(prompt), "\n")
	if r := []rune(line); len(r) > 80 {
		return string(r[:79]) + "…"
	}
	return line
}

func (c *chat) run(text string) {
	_, err := c.agent.Prompt(context.Background(), acp.PromptRequest{
		SessionID: acp.SessionID(c.id),
		Prompt:    []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}},
	})
	st := &model.Status{}
	if err != nil {
		st.Error = err.Error()
	}
	c.mu.Lock()
	c.busy = false
	c.lastError = st.Error
	c.emitLocked(model.Event{ChatID: c.id, Status: st})
	c.mu.Unlock()
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
	c.items = append(c.items, it)
	c.emitLocked(model.Event{ChatID: c.id, Item: &it})
	return it.ID
}
