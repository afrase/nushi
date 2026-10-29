package claudeacp

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"sync"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// session is an ACP session: one claude, its turns, and what its stream
// has shown so far.
type session struct {
	a   *agent
	id  string // claude's session id too
	cs  *claudeagent.Session
	log *slog.Logger

	// wmu orders the user messages written with the turns they join: the
	// queue's order is claude's.
	wmu sync.Mutex

	mu       sync.Mutex
	turns    []*turn                    // unsettled prompts, in the order written
	active   *turn                      // the one claude runs, from its echo; nil between turns
	dropTop  bool                       // after a cancel, until a turn starts: the stopped work's top-level text goes
	owedIdle int                        // idles still to come after results that ended a turn
	asks     int                        // permission and question requests open
	open     map[int]context.CancelFunc // withdraws each, by a number of its own
	lastAsk  int
	closed   bool // closed or gone: no more prompts

	tools tools // the tool calls shown

	cwd   string
	cmds  commands
	title titles

	st   stream        // the reader's own
	read chan struct{} // closed once the reader is done
}

func (a *agent) NewSession(ctx context.Context, req *acp.NewSessionRequest) (*acp.NewSessionResponse, error) {
	o, err := a.options(setup{cwd: req.Cwd, dirs: req.AdditionalDirectories, mcpServers: req.MCPServers, systemPrompt: req.SystemPrompt, meta: req.Meta})
	if err != nil {
		return nil, err
	}
	o.SessionID = a.newID() // so the ACP session's id is claude's
	s, err := a.start(ctx, o.SessionID, o)
	if err != nil {
		return nil, err
	}
	a.out.after(s.id, s.sendCommands)
	return &acp.NewSessionResponse{SessionID: acp.SessionID(s.id)}, nil
}

// start runs claude for session id and opens the session once claude has
// answered initialize.
func (a *agent) start(ctx context.Context, id string, o claudeagent.Options) (*session, error) {
	s := &session{a: a, id: id, cwd: o.Cwd, log: a.log.With("session", id), read: make(chan struct{}), open: map[int]context.CancelFunc{}}
	s.st.init()
	s.tools.init(o.Cwd)
	o.Hooks = map[claudeagent.HookEvent][]claudeagent.HookMatcher{
		claudeagent.HookPostToolUse: {{Fn: s.postToolUse}},
	}
	o.CanUseTool, o.OnElicitation = s.canUseTool, s.elicit
	cs, err := claudeagent.Start(ctx, o)
	if err != nil {
		return nil, &acp.Error{Code: acp.ErrorCodeInternalError, Message: fmt.Sprintf("Claude didn't start: %v", err)}
	}
	s.cs = cs
	if ir := cs.Init(); ir != nil {
		s.cmds.list = ir.Commands
	}
	a.mu.Lock()
	a.sessions[id] = s
	a.mu.Unlock()
	go s.reader()
	return s, nil
}

// reader maps claude's messages to the client's updates and turns' ends
// until claude's output ends.
func (s *session) reader() {
	defer close(s.read)
	for m := range s.cs.Messages() {
		s.handle(m)
	}
	err := s.cs.Wait()
	_ = s.cs.Close()
	s.endTools(endedExit)
	s.mu.Lock()
	gone := !s.closed
	s.closed = true
	if gone {
		// claude died under the session: its turns fail, and the
		// session goes, so later prompts are told so.
		for _, t := range slices.Clone(s.turns) {
			s.settleLocked(t, outcome{err: died})
		}
	}
	s.mu.Unlock()
	if gone {
		s.log.Warn("claude exited", "err", err)
		s.a.forget(s)
	}
}

// died is what a turn gets when claude exits under it.
var died = &acp.Error{Code: acp.ErrorCodeInternalError, Message: "The Claude process exited unexpectedly. Please start a new session.",
	Data: []byte(`{"errorKind":"transport_lost"}`)}

// errEnded is what a prompt for a session closing gets.
var errEnded = &acp.Error{Code: acp.ErrorCodeInternalError, Message: "The Claude session has ended. Please start a new session."}

// send writes a prompt's user message and queues its turn.
func (s *session) send(ctx context.Context, content []claudeagent.Block) (*turn, error) {
	s.wmu.Lock()
	defer s.wmu.Unlock()
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return nil, errEnded
	}
	t := newTurn(s.a.newID())
	s.turns = append(s.turns, t)
	s.mu.Unlock()
	if _, err := s.cs.Send(ctx, claudeagent.UserInput{Content: content, UUID: t.id}); err != nil {
		s.mu.Lock()
		s.settleLocked(t, outcome{err: err})
		s.mu.Unlock()
		if errors.Is(err, claudeagent.ErrClosed) {
			return nil, errEnded
		}
		return nil, fmt.Errorf("writing the prompt to claude: %w", err)
	}
	return t, nil
}

// closeWait is how long close waits for claude to take an interrupt.
const closeWait = 2 * time.Second

// close ends the session: a running turn is interrupted, every turn
// answered cancelled, and claude closed. It returns once claude has
// exited and the reader is done, and does nothing the second time.
func (s *session) close() {
	s.a.forget(s)
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		<-s.read
		return
	}
	s.closed = true
	running := len(s.turns) > 0
	if s.active != nil {
		s.active.cancelled = true // its result, if the interrupt brings one, ends it cancelled
	}
	s.mu.Unlock()
	if running {
		// claude would finish the turn before it took stdin's end.
		ctx, cancel := context.WithCancel(s.a.ctx)
		go func() {
			select {
			case <-s.a.after(closeWait):
				cancel()
			case <-ctx.Done():
			}
		}()
		if _, err := s.cs.Interrupt(ctx); err != nil {
			s.log.Info("interrupting claude to close", "err", err)
		}
		cancel()
	}
	s.mu.Lock()
	for _, t := range slices.Clone(s.turns) {
		s.settleLocked(t, cancelled(t))
	}
	s.mu.Unlock()
	_ = s.cs.Close()
	<-s.read
	s.title.looked.Wait()
}

// newUUID is a random (version 4) UUID.
func newUUID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}
