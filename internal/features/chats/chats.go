// Package chats runs chats: one agent session each, with its transcript.
package chats

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"sync"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// Agent is a connection to a running agent (an *acp.Client).
type Agent interface {
	Initialize(context.Context, acp.InitializeRequest) (*acp.InitializeResponse, error)
	NewSession(context.Context, acp.NewSessionRequest) (*acp.NewSessionResponse, error)
	Prompt(context.Context, acp.PromptRequest) (*acp.PromptResponse, error)
	Close() error
}

// Launch starts an agent; its session updates go to h.
type Launch func(h acp.Handler) (Agent, error)

// Service holds the open chats.
type Service struct {
	launch  Launch
	publish func(model.Event)

	mu    sync.Mutex
	chats map[string]*chat
}

func New(launch Launch, publish func(model.Event)) *Service {
	return &Service{launch: launch, publish: publish, chats: map[string]*chat{}}
}

type chat struct {
	id      string // the agent's session id
	agent   Agent
	publish func(model.Event)

	mu      sync.Mutex
	items   []model.Item
	busy    bool
	lastID  string                   // the agent message that chunks without an id continue
	waiting map[string]chan<- string // permission prompts by item id, for the picked option
}

// Start launches an agent in folder and opens a session there.
func (s *Service) Start(ctx context.Context, folder string) (string, error) {
	if fi, err := os.Stat(folder); err != nil || !fi.IsDir() || !filepath.IsAbs(folder) {
		return "", fmt.Errorf("%q is not an absolute path to a folder", folder)
	}
	c := &chat{publish: s.publish, waiting: map[string]chan<- string{}}
	agent, err := s.launch(c)
	if err != nil {
		return "", fmt.Errorf("start agent: %w", err)
	}
	c.agent = agent
	if _, err := agent.Initialize(ctx, acp.InitializeRequest{
		ProtocolVersion:    acp.Version,
		ClientCapabilities: &acp.ClientCapabilities{},
		ClientInfo:         &acp.Implementation{Name: "nushi", Title: "Nushi"},
	}); err != nil {
		agent.Close()
		return "", err
	}
	sess, err := agent.NewSession(ctx, acp.NewSessionRequest{Cwd: folder, MCPServers: []acp.MCPServer{}})
	if err != nil {
		agent.Close()
		return "", err
	}
	c.id = string(sess.SessionID)
	s.mu.Lock()
	s.chats[c.id] = c
	s.mu.Unlock()
	return c.id, nil
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
	c.publish(model.Event{ChatID: c.id, Status: &model.Status{Busy: true}})
	go c.run(text)
	return nil
}

func (s *Service) chat(id string) (*chat, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if c := s.chats[id]; c != nil {
		return c, nil
	}
	return nil, fmt.Errorf("no chat %q", id)
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
	c.lastID = ""
	c.publish(model.Event{ChatID: c.id, Status: st})
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
	c.publish(model.Event{ChatID: c.id, Item: &it})
	return it.ID
}
