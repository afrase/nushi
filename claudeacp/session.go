package claudeacp

import (
	"context"
	"crypto/rand"
	"fmt"
	"log/slog"
	"sync"

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

	mu     sync.Mutex
	closed bool // closed or gone: no more prompts

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
	return &acp.NewSessionResponse{SessionID: acp.SessionID(s.id)}, nil
}

// start runs claude for session id and opens the session once claude has
// answered initialize.
func (a *agent) start(ctx context.Context, id string, o claudeagent.Options) (*session, error) {
	s := &session{a: a, id: id, log: a.log.With("session", id), read: make(chan struct{})}
	cs, err := claudeagent.Start(ctx, o)
	if err != nil {
		return nil, &acp.Error{Code: acp.ErrorCodeInternalError, Message: fmt.Sprintf("Claude didn't start: %v", err)}
	}
	s.cs = cs
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
	for range s.cs.Messages() {
		// Read through: nothing is mapped yet.
	}
	err := s.cs.Wait()
	_ = s.cs.Close()
	s.mu.Lock()
	gone := !s.closed
	s.closed = true
	s.mu.Unlock()
	if gone {
		// claude died under the session, which goes, so later
		// requests are told so.
		s.log.Warn("claude exited", "err", err)
		s.a.forget(s)
	}
}

// close ends the session: claude is closed. It returns once claude has
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
	s.mu.Unlock()
	_ = s.cs.Close()
	<-s.read
}

// newUUID is a random (version 4) UUID.
func newUUID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}
