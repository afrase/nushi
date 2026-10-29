package claudeagent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"sync/atomic"
	"time"
)

// Session is a running claude: its messages, the requests it answers and
// the ones it sends us. Its methods are safe to call from any goroutine.
type Session struct {
	o     Options
	hooks map[string]HookFunc // Options.Hooks, by the ids initialize gave them
	t     *transport
	log   *slog.Logger
	after func(time.Duration) <-chan time.Time // requests' clock; tests give a fake one

	ctx      context.Context //nolint:containedctx // the parent of claude's requests' contexts; ends with the session
	cancel   context.CancelFunc
	nextID   atomic.Uint64
	initResp *InitResponse

	mu       sync.Mutex
	pending  map[string]chan reply         // our requests, by id
	inbound  map[string]context.CancelFunc // claude's, by id, while handled
	caps     map[string]bool
	endErr   error          // set once the session has ended: what requests get
	handlers sync.WaitGroup // claude's requests being handled

	initOnce  sync.Once
	initCh    chan struct{} // closed once initialize is written
	closing   chan struct{}
	closeOnce sync.Once

	queued uint64 // messages joined the queue so far; read's own

	qmu   sync.Mutex
	queue []Message
	qdone bool          // stdout has ended: nothing more joins the queue
	qwake chan struct{} // signalled when the queue changes
	out   chan Message
}

// Start starts claude, sends it the initialize request and returns once
// claude has answered it, which can take a while: MCP servers start
// first. ctx bounds the start only. If claude exits before it answers,
// the error says how, with an *ExitError.
func Start(ctx context.Context, o Options) (*Session, error) {
	body, err := initRequest(o.Init)
	if err != nil {
		return nil, err
	}
	hooks, byID, err := registerHooks(o.Hooks)
	if err != nil {
		return nil, err
	}
	if len(hooks) > 0 {
		body["hooks"] = hooks
	}
	t, err := startTransport(ctx, o)
	if err != nil {
		return nil, err
	}
	s := newSession(ctx, t, o, byID)
	raw, err := s.request(ctx, "initialize", body, false)
	if err != nil {
		_ = s.Close()
		if !errors.Is(err, ErrClosed) {
			return nil, err // claude's refusal, or ctx's end, which say initialize
		}
		if werr := s.Wait(); werr != nil {
			return nil, fmt.Errorf("claudeagent: claude ended before answering initialize: %w", werr)
		}
		return nil, errors.New("claudeagent: claude ended before answering initialize")
	}
	r := new(InitResponse)
	if len(raw) > 0 && string(raw) != "null" {
		if err := json.Unmarshal(raw, r); err != nil {
			_ = s.Close()
			return nil, fmt.Errorf("claudeagent: claude's answer to initialize: %w", err)
		}
	}
	s.initResp = r
	s.addCapabilities(r.Capabilities)
	return s, nil
}

// newSession reads t's messages and starts handing them on; hooks are
// o's by their ids. The session outlives ctx, which lends it only its
// values.
//
//nolint:contextcheck // claude's requests get the session's context, made from ctx, which they outlive
func newSession(ctx context.Context, t *transport, o Options, hooks map[string]HookFunc) *Session {
	s := &Session{
		o: o, hooks: hooks, t: t, log: t.log, after: time.After,
		pending: map[string]chan reply{}, inbound: map[string]context.CancelFunc{}, caps: map[string]bool{},
		initCh: make(chan struct{}), closing: make(chan struct{}),
		qwake: make(chan struct{}, 1), out: make(chan Message),
	}
	s.ctx, s.cancel = context.WithCancel(context.WithoutCancel(ctx))
	go s.read()
	go s.pump()
	return s
}

// Messages are claude's messages, in order, without the control
// protocol's. The channel is closed when claude's stdout ends or the
// session is closed; Wait then says how claude ended. It has one reader,
// which should read it to the end: nothing is dropped, so messages no
// one reads pile up in memory.
func (s *Session) Messages() <-chan Message { return s.out }

// Init is claude's answer to initialize.
func (s *Session) Init() *InitResponse { return s.initResp }

// Has says whether claude supports a protocol capability, such as
// "interrupt_receipt_v1": one its initialize answer named, or any
// system/init message so far.
func (s *Session) Has(capability string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.caps[capability]
}

func (s *Session) addCapabilities(caps []string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, c := range caps {
		s.caps[c] = true
	}
}

// read sorts claude's messages: the control protocol's are handled here,
// the rest join the queue Messages reads.
func (s *Session) read() {
	for m := range s.t.messages() {
		e := m.Frame()
		switch e.Type {
		case "control_response":
			s.answered(e.Raw)
			continue
		case "control_request":
			s.received(e.Raw)
			continue
		case "control_cancel_request":
			s.withdrawn(e.Raw)
			continue
		}
		if si, ok := m.(*SystemInit); ok {
			s.addCapabilities(si.Capabilities) // before the message is seen, so Has agrees with it
		}
		s.queued++
		s.qmu.Lock()
		s.queue = append(s.queue, m)
		s.qmu.Unlock()
		s.wake()
	}
	s.end(fmt.Errorf("%w: claude's output ended", ErrClosed))
	s.qmu.Lock()
	s.qdone = true
	s.qmu.Unlock()
	s.wake()
}

func (s *Session) wake() {
	select {
	case s.qwake <- struct{}{}:
	default:
	}
}

// pump hands the queue to Messages' reader. The queue has no bound, so
// the reading of claude's stdout never waits for that reader: a control
// response gets through while the reader is busy, perhaps waiting for it.
func (s *Session) pump() {
	defer close(s.out)
	for {
		s.qmu.Lock()
		if len(s.queue) == 0 {
			done := s.qdone
			s.qmu.Unlock()
			if done {
				return
			}
			select {
			case <-s.qwake:
				continue
			case <-s.closing:
				return
			}
		}
		m := s.queue[0]
		s.queue[0] = nil
		s.queue = s.queue[1:]
		s.qmu.Unlock()
		select {
		case s.out <- m:
		case <-s.closing:
			return
		}
	}
}

// end ends the session for requests: ours fail with err, claude's are
// withdrawn, and new ones of either side's fail or are dropped.
func (s *Session) end(err error) {
	s.mu.Lock()
	if s.endErr == nil {
		s.endErr = err
	}
	s.mu.Unlock()
	s.cancel()
	s.failPending(err)
}

func (s *Session) initWritten() bool {
	select {
	case <-s.initCh:
		return true
	default:
		return false
	}
}

func (s *Session) initDone() { s.initOnce.Do(func() { close(s.initCh) }) }

// write writes v to claude's stdin once initialize has been written:
// claude takes its first line for the start of the session.
func (s *Session) write(ctx context.Context, v any) error {
	select {
	case <-s.initCh:
	case <-ctx.Done():
		return ctx.Err()
	case <-s.closing:
		return ErrClosed
	}
	return s.t.write(v)
}

// Close ends the session: callbacks' contexts end, requests waiting for
// an answer fail with ErrClosed, and claude's stdin is closed, which
// tells it to finish and exit. If it hasn't exited 2 s later its process
// group (claude alone, with SharedGroup) gets SIGTERM, and SIGKILL 5 s
// after that. Close returns once claude has exited; Wait says how. It
// doesn't interrupt a turn under way: claude finishes it first, unless
// the signals come before.
func (s *Session) Close() error {
	s.closeOnce.Do(func() {
		close(s.closing)
		s.end(ErrClosed)
		s.t.close()
	})
	return nil
}

// Wait waits for claude to exit and says how: nil for exit code 0, else
// an *ExitError with the end of its stderr.
func (s *Session) Wait() error { return s.t.wait() }
