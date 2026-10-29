package claudeagent

import (
	"context"
	"encoding/json"
	"errors"
)

// claude's requests: each is handled in a goroutine of its own and
// answered once, unless claude withdraws it first.

// ErrUnsupported is what Options.OnControl returns for a request it
// doesn't handle: claude is told the subtype is unsupported, which it
// takes for a missing feature rather than a failure.
var ErrUnsupported = errors.New("claudeagent: unsupported control request")

// errNoReply is a handler's result for a request that must go unanswered.
var errNoReply = errors.New("no reply")

// controlRequest is a control_request as read: its id and its request.
type controlRequest struct {
	RequestID string          `json:"request_id"`
	Request   json.RawMessage `json:"request"`
}

// received handles a control_request from claude in a goroutine of its
// own, with a context that ends when claude withdraws the request or the
// session ends. A request whose id is still being handled is a duplicate
// and is dropped.
func (s *Session) received(raw json.RawMessage) {
	var f controlRequest
	if err := json.Unmarshal(raw, &f); err != nil || f.RequestID == "" {
		s.log.Warn("claude wrote a control request that doesn't decode", "err", err)
		return
	}
	var head struct {
		Subtype string `json:"subtype"`
	}
	_ = json.Unmarshal(f.Request, &head)
	s.mu.Lock()
	if _, dup := s.inbound[f.RequestID]; dup || s.endErr != nil {
		s.mu.Unlock()
		return
	}
	ctx, cancel := context.WithCancel(context.WithValue(s.ctx, beforeKey{}, s.queued))
	s.inbound[f.RequestID] = cancel
	s.handlers.Add(1)
	s.mu.Unlock()
	go func() {
		defer s.handlers.Done()
		defer cancel()
		payload, err := s.handle(ctx, head.Subtype, f.Request)
		s.mu.Lock()
		delete(s.inbound, f.RequestID)
		withdrawn := ctx.Err() != nil
		s.mu.Unlock()
		if withdrawn || errors.Is(err, errNoReply) {
			return // claude no longer waits, or mustn't be answered
		}
		r := controlResponse{Subtype: "success", RequestID: f.RequestID}
		if payload == nil {
			payload = struct{}{}
		}
		if err != nil {
			r.Subtype, r.Error = "error", err.Error()
		} else if r.Response, err = json.Marshal(payload); err != nil {
			r.Subtype, r.Error, r.Response = "error", "claudeagent: encoding the answer: "+err.Error(), nil
		}
		if err := s.write(ctx, map[string]any{"type": "control_response", "response": wireResponse(r)}); err != nil {
			s.log.Debug("answering claude", "subtype", head.Subtype, "err", err)
		}
	}()
}

// beforeKey is the context key of the number of messages before a
// request of claude's.
type beforeKey struct{}

// MessagesBefore is how many of claude's messages, of those Messages
// yields, came before the request a callback's ctx is for. Claude's
// requests are handled beside its messages, not after them: a reader of
// Messages that has taken this many has seen all claude wrote before it
// asked, such as the start of the task a subagent's request comes from.
// ok is false for a ctx that isn't a callback's.
func MessagesBefore(ctx context.Context) (n uint64, ok bool) {
	n, ok = ctx.Value(beforeKey{}).(uint64)
	return n, ok
}

// wireResponse is r as claude reads it: a success's payload or an
// error's message, not both.
func wireResponse(r controlResponse) map[string]any {
	w := map[string]any{"subtype": r.Subtype, "request_id": r.RequestID}
	if r.Subtype == "error" {
		w["error"] = r.Error
	} else {
		w["response"] = r.Response
	}
	return w
}

// withdrawn ends the handling of a request claude no longer wants; what
// its handler returns isn't sent.
func (s *Session) withdrawn(raw json.RawMessage) {
	var f struct {
		RequestID string `json:"request_id"`
	}
	_ = json.Unmarshal(raw, &f)
	s.mu.Lock()
	cancel, ok := s.inbound[f.RequestID]
	s.mu.Unlock()
	if ok {
		cancel()
	}
}

// unsupported is the answer to a request the session doesn't handle.
// claude reads this prefix as a missing feature rather than a failure.
func unsupported(subtype string) error {
	return errors.New("Unsupported control request subtype: " + subtype)
}

// handle answers one request from claude.
func (s *Session) handle(ctx context.Context, subtype string, req json.RawMessage) (any, error) {
	switch subtype {
	case "can_use_tool":
		if s.o.CanUseTool == nil {
			return nil, errors.New("claudeagent: no CanUseTool to ask")
		}
		return s.canUseTool(ctx, req)
	case "hook_callback":
		return s.hookCallback(ctx, req)
	case "elicitation":
		return s.elicitation(ctx, req)
	case "request_user_dialog":
		// The session declares no dialog kinds, so claude shouldn't ask;
		// an answer would be dropped and leave the dialog open.
		return nil, errNoReply
	case "oauth_token_refresh", "host_auth_token_refresh", "remote_control_work_secret":
		return nil, unsupported(subtype) // never a token, whatever OnControl does
	}
	if s.o.OnControl == nil {
		return nil, unsupported(subtype)
	}
	payload, err := s.o.OnControl(ctx, subtype, req)
	if errors.Is(err, ErrUnsupported) {
		return nil, unsupported(subtype)
	}
	return payload, err
}
