package claudeacp

import (
	"bytes"
	"io"
	"slices"
	"strings"
	"sync"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// A session's slash commands are claude's, from its answer to initialize
// and each commands_changed after: the client offers them, and a prompt
// that starts with one runs it.

// hiddenCommands are claude's commands a client has no use for: signing
// in and out, its terminal's screens and keys, clearing (a client starts
// a new session instead), and /mcp, whose changes need claude's terminal.
var hiddenCommands = []string{"clear", "cost", "keybindings-help", "login", "logout", "mcp", "output-style:new", "release-notes", "todos"}

// commands are the slash commands the client was told of.
type commands struct {
	mu       sync.Mutex
	list     []claudeagent.Command
	terminal []string // the ones claude runs only in its terminal, from system/init
}

// sendCommands tells the client of the session's commands, all of them.
// It holds the lock while it sends, so the client's last list is the
// last one claude gave.
func (s *session) sendCommands() {
	c := &s.cmds
	c.mu.Lock()
	defer c.mu.Unlock()
	out := []acp.AvailableCommand{}
	for _, cmd := range c.list {
		if slices.Contains(hiddenCommands, cmd.Name) || slices.Contains(c.terminal, cmd.Name) {
			continue
		}
		ac := acp.AvailableCommand{Name: cmd.Name, Description: cmd.Description}
		if cmd.ArgumentHint != "" {
			ac.Input = &acp.AvailableCommandInput{Unstructured: &acp.UnstructuredCommandInput{Hint: cmd.ArgumentHint}}
		}
		out = append(out, ac)
	}
	s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "available_commands_update",
		AvailableCommandsUpdate: &acp.AvailableCommandsUpdate{AvailableCommands: out}})
}

// commandsChanged is claude's new list of commands.
func (s *session) commandsChanged(list []claudeagent.Command) {
	s.cmds.mu.Lock()
	s.cmds.list = list
	s.cmds.mu.Unlock()
	s.sendCommands()
}

// terminalCommands follows system/init's list of the commands only
// claude's terminal runs: when it changes, so does the client's.
func (s *session) terminalCommands(names []string) {
	names = slices.Clone(names)
	for i, n := range names {
		names[i] = strings.TrimPrefix(n, "/")
	}
	s.cmds.mu.Lock()
	news := names != nil && !slices.Equal(names, s.cmds.terminal)
	if news {
		s.cmds.terminal = names
	}
	s.cmds.mu.Unlock()
	if news {
		s.sendCommands()
	}
}

// afterAnswer is the agent's writer to the client, which watches for
// the answers that open sessions: a client takes a session's updates
// once it knows its id, so what the session sends first (its commands)
// waits for its answer to be written.
type afterAnswer struct {
	w    io.Writer
	mu   sync.Mutex
	then map[string]func() // by session id
}

// after has fn run once the answer naming session sid is written.
func (aa *afterAnswer) after(sid string, fn func()) {
	aa.mu.Lock()
	defer aa.mu.Unlock()
	if aa.then == nil {
		aa.then = map[string]func(){}
	}
	aa.then[sid] = fn
}

func (aa *afterAnswer) Write(p []byte) (int, error) {
	n, err := aa.w.Write(p)
	if err == nil {
		if fn := aa.answered(p); fn != nil {
			go fn() // on its own: the writer that runs this writes what it sends
		}
	}
	return n, err
}

// An answer is written as answerHead, its id, then sessionResult and the
// session's id when it opens one (session/new's, session/fork's).
var (
	answerHead    = []byte(`{"jsonrpc":"2.0","id":`)
	resultKey     = []byte(`,"result":`)
	sessionResult = []byte(`,"result":{"sessionId":"`)
)

// answered is what waits for p, if p is an answer opening a session.
func (aa *afterAnswer) answered(p []byte) func() {
	aa.mu.Lock()
	defer aa.mu.Unlock()
	if len(aa.then) == 0 {
		return nil
	}
	rest, ok := bytes.CutPrefix(p, answerHead)
	i := bytes.Index(rest, resultKey)
	if !ok || i < 0 || bytes.Contains(rest[:i], []byte(`"method"`)) || !bytes.HasPrefix(rest[i:], sessionResult) {
		return nil
	}
	sid, _, _ := bytes.Cut(rest[i+len(sessionResult):], []byte(`"`))
	fn := aa.then[string(sid)]
	delete(aa.then, string(sid))
	return fn
}
