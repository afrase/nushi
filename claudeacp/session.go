package claudeacp

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"sync"
	"time"
	"uuid"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// session is an ACP session: one claude, its turns, and what its stream
// has shown so far. The turns are its own, under mu; each part below
// them keeps its state under a lock of its own and owns what changes it.
//
// The order its locks nest in: a lock may be taken while one to its left
// on a line is held, never the other way round.
//
//	wmu → mu → kids.mu
//	tools.mu → kids.mu
//	cfg.changing → cfg.mu
//	cfg.changing → win.mu → agent.windows.mu
//
// No other lock is taken while plan.mu, cmds.mu, title.mu, hmu, bg.mu
// or stderr's is held, nor while one at a line's end is, but for the
// client connection's: tools.mu, kids.mu, plan.mu, cmds.mu and win.mu
// send the client their updates while held, to keep the updates' order,
// so the connection's own lock is always taken last.
type session struct {
	a      *agent
	id     string // claude's session id too
	cs     *claudeagent.Session
	log    *slog.Logger
	stderr *stderrLog // claude's

	// wmu orders the user messages written with the turns they join: the
	// queue's order is claude's.
	wmu sync.Mutex

	mu       sync.Mutex
	turns    []*turn      // unsettled prompts, in the order written
	active   *turn        // the one claude runs, from its echo; nil between turns
	dropTop  bool         // after a cancel, until a turn starts: the stopped work's top-level text goes
	owedIdle int          // idles still to come after results that ended a turn
	asks     int          // permission and question requests open
	open     map[int]*ask // the requests open, by a number of their own
	lastAsk  int
	closed   bool // closed or gone: no more prompts

	tools tools     // the tool calls shown
	kids  subagents // its subagents, through which every update of a stream goes

	cwd   string
	cfg   config // its modes and options
	cmds  commands
	title titles
	plan  plan

	win  window        // the context window's size
	st   stream        // the reader's own
	read chan struct{} // closed once the reader is done
	bg   background    // its goroutines besides the reader's

	hmu     sync.Mutex
	handled uint64        // claude's messages the reader has handled
	tick    chan struct{} // closed, and made anew, at each
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
	a.out.after(s.id, s.cmds.sendAll)
	modes, opts := s.cfg.state()
	return &acp.NewSessionResponse{SessionID: acp.SessionID(s.id), Modes: modes, ConfigOptions: opts}, nil
}

// start runs claude for session id and opens the session once claude has
// answered initialize.
func (a *agent) start(ctx context.Context, id string, o claudeagent.Options) (*session, error) {
	s := &session{a: a, id: id, cwd: o.Cwd, log: a.log.With("session", id), read: make(chan struct{}), tick: make(chan struct{}), open: map[int]*ask{}}
	s.st.init()
	s.kids.init(id, a.clientCaps().subagents, a.update)
	s.tools.init(o.Cwd, &s.kids, a.newID)
	s.plan.init(s.update)
	s.cmds.send = s.update
	o.Hooks = map[claudeagent.HookEvent][]claudeagent.HookMatcher{
		claudeagent.HookPostToolUse: {{Fn: s.postToolUse}},
	}
	o.CanUseTool, o.OnElicitation = s.canUseTool, s.elicit
	s.stderr = newStderrLog(s.log, time.Now)
	o.Stderr = s.stderr.line
	cs, err := claudeagent.Start(ctx, o)
	if err != nil {
		return nil, a.startError(o.Resume, o.Cwd, err)
	}
	s.cs = cs
	s.cfg.send, s.cfg.log = s.update, s.log
	s.cfg.init(o, cs.Init(), a.clientCaps().booleans)
	if ir := cs.Init(); ir != nil {
		s.cmds.list = ir.Commands
	}
	s.win.send, s.win.provider = s.update, providerKey(o.Env)
	s.seedWindow(ctx, 0)
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
		s.hmu.Lock()
		s.handled++
		close(s.tick)
		s.tick = make(chan struct{})
		s.hmu.Unlock()
	}
	err := s.cs.Wait() // and its stderr read through
	s.stderr.flush()
	_ = s.cs.Close()
	s.tools.end(endedExit)
	s.kids.gone()
	s.mu.Lock()
	gone := !s.closed
	s.closed = true // no more turns join
	s.mu.Unlock()
	if gone {
		// claude died under the session: the session goes, then its
		// turns fail, so a prompt sent once they have is told there is
		// no session rather than, now and then, that it has ended.
		s.log.Warn("claude exited", "err", err)
		s.a.forget(s)
		s.mu.Lock()
		for _, t := range slices.Clone(s.turns) {
			s.settleLocked(t, outcome{err: died})
		}
		s.mu.Unlock()
	}
}

// caughtUp waits until the reader has handled the messages claude wrote
// before the request ctx is for, as claude handles requests beside its
// messages: so the request finds what they said, such as the start of
// the subagent it comes from. It waits no more once claude is gone or
// ctx ends.
func (s *session) caughtUp(ctx context.Context) {
	n, ok := claudeagent.MessagesBefore(ctx)
	for ok {
		s.hmu.Lock()
		done, tick := s.handled >= n, s.tick
		s.hmu.Unlock()
		if done {
			return
		}
		select {
		case <-tick:
		case <-ctx.Done():
			return
		case <-s.read:
			return
		}
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

// closeWait is how long close waits for claude to take an interrupt. With
// claudeagent's 2 s for claude to exit once its stdin ends, a close takes
// under the 5 s a client such as Nushi gives an agent before it kills its
// group, and claude with it (Main).
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
		s.bg.wait()
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
	s.bg.wait()
}

// background is a session's goroutines besides its reader: a cancel's
// requests and backstop, a subagent's stop, the context window's answer,
// a look for its title. close waits for them; once it has, no more
// start, as claude is gone and each would only fail.
type background struct {
	mu     sync.Mutex
	wg     sync.WaitGroup
	closed bool
}

// Go runs fn on a goroutine of the session's, unless it has closed.
func (b *background) Go(fn func()) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if !b.closed {
		b.wg.Go(fn)
	}
}

// wait waits for the goroutines running, and starts no more.
func (b *background) wait() {
	b.mu.Lock()
	b.closed = true
	b.mu.Unlock()
	b.wg.Wait()
}

// update sends the client an update of the session's own.
func (s *session) update(u acp.SessionUpdate) { s.a.update(s.id, u) }

// newUUID is a random (version 4) UUID: a new message's id.
func newUUID() string { return uuid.NewV4().String() }
