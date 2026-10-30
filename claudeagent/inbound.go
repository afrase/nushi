package claudeagent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
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
		if err := s.write(ctx, responseLine(f.RequestID, payload, err)); err != nil {
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

// controlResponseLine is our answer to a request of claude's: a success
// or a failure.
type controlResponseLine struct {
	Type     string `json:"type"` // "control_response"
	Response any    `json:"response"`
}

// success is an answer's payload.
type success struct {
	Subtype   string          `json:"subtype"` // "success"
	RequestID string          `json:"request_id"`
	Response  json.RawMessage `json:"response"`
}

// failure is an error's message, for claude to show.
type failure struct {
	Subtype   string `json:"subtype"` // "error"
	RequestID string `json:"request_id"`
	Error     string `json:"error"`
}

// responseLine answers request id with a handler's payload, {} when nil,
// or its error.
func responseLine(id string, payload any, err error) controlResponseLine {
	line := controlResponseLine{Type: "control_response"}
	if payload == nil {
		payload = struct{}{}
	}
	var b []byte
	if err == nil {
		if b, err = json.Marshal(payload); err != nil {
			err = fmt.Errorf("claudeagent: encoding the answer: %w", err)
		}
	}
	if err != nil {
		line.Response = failure{Subtype: "error", RequestID: id, Error: err.Error()}
	} else {
		line.Response = success{Subtype: "success", RequestID: id, Response: b}
	}
	return line
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
