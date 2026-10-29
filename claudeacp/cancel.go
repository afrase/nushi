package claudeacp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"maps"
	"slices"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// cancel stops the session's work. Prompts claude hasn't taken are
// answered cancelled at once and dropped from claude's queue, with the
// steers that joined them; claude is interrupted, and a running prompt
// answered cancelled at its result or idle, or after the backstop. Until a turn starts again, or claude asks
// the API anew, what the stopped work still writes at the top level is
// dropped; subagents' isn't, as background ones go on.
func (s *session) cancel() {
	s.mu.Lock()
	var drop []string
	for _, t := range slices.Clone(s.turns) {
		switch {
		case !t.active:
			// Its steers wait in claude's queue with it.
			drop = append(drop, slices.Sorted(maps.Keys(t.ids))...)
			s.settleLocked(t, cancelled(t))
		case t.held != nil:
			s.settleLocked(t, cancelled(t)) // its result came: nothing to wait for
		case !t.cancelled:
			t.cancelled = true
			go s.backstop(t)
		}
	}
	s.dropTop = true
	s.mu.Unlock()
	for _, id := range drop {
		go func() {
			if err := s.cs.CancelAsyncMessage(s.a.ctx, id); err != nil {
				s.log.Info("dropping a queued prompt", "err", err)
			}
		}()
	}
	// Claude is interrupted even when no prompt is known to run: it may
	// have taken one whose echo hasn't come yet, or be at work of its own.
	go func() {
		r, err := s.cs.Interrupt(s.a.ctx)
		if err != nil {
			s.log.Info("interrupting claude", "err", err)
		} else if r.Known && len(r.StillQueued) > 0 {
			s.log.Info("claude still has queued messages after the interrupt", "count", len(r.StillQueued))
		}
	}()
}

// backstop answers t cancelled if claude says nothing more of it.
func (s *session) backstop(t *turn) {
	select {
	case <-s.a.after(backstop):
		s.mu.Lock()
		s.settleLocked(t, cancelled(t))
		s.mu.Unlock()
	case <-t.ended:
	}
}

// steer is _session/steering: a message for the running turn.
func (a *agent) steer(ctx context.Context, params json.RawMessage) (*steering.Response, error) {
	var req steering.Request[acp.ContentBlock]
	if err := json.Unmarshal(params, &req); err != nil {
		return nil, invalidParams("steering: %v", err)
	}
	if len(req.Prompt) == 0 {
		return nil, invalidParams("steering: an empty prompt")
	}
	if sm, _ := req.Meta["steering"].(map[string]any); sm["idleBehavior"] != nil && !req.PromptRequired() {
		return nil, invalidParams("steering: no idle behaviour %v", sm["idleBehavior"])
	}
	s, err := a.session(acp.SessionID(req.SessionID))
	if err != nil {
		return nil, err
	}
	content, err := toClaude(req.Prompt)
	if err != nil {
		return nil, err
	}
	injected, err := s.inject(ctx, content)
	switch {
	case err != nil:
		return nil, err
	case injected:
		return &steering.Response{Outcome: steering.Injected}, nil
	case req.PromptRequired():
		return &steering.Response{Outcome: steering.PromptRequired, Reason: "noRunningTurn"}, nil
	}
	if _, err := s.send(ctx, content); err != nil { // a turn no one waits on
		return nil, err
	}
	return &steering.Response{Outcome: steering.StartedNewTurn}, nil
}

// inject hands content to the turn claude runs, or is about to, as a
// message claude takes now; while a permission or question is open, at
// the next point it may, so the open request isn't cancelled. The turn
// then ends at a result that names the message. false: no turn.
func (s *session) inject(ctx context.Context, content []claudeagent.Block) (bool, error) {
	s.wmu.Lock()
	defer s.wmu.Unlock()
	s.mu.Lock()
	t := s.active
	if t == nil && len(s.turns) > 0 {
		t = s.turns[0]
	}
	if t == nil || t.cancelled || s.closed {
		s.mu.Unlock()
		return false, nil
	}
	id := s.a.newID()
	t.ids[id], t.steers[id] = true, true
	priority := "now"
	if s.asks > 0 {
		priority = "later"
	}
	s.mu.Unlock()
	if _, err := s.cs.Send(ctx, claudeagent.UserInput{Content: content, UUID: id, Priority: priority}); err != nil {
		s.mu.Lock()
		delete(t.steers, id)
		s.mu.Unlock()
		if errors.Is(err, claudeagent.ErrClosed) {
			return false, errEnded
		}
		return false, fmt.Errorf("writing the steer to claude: %w", err)
	}
	return true, nil
}
