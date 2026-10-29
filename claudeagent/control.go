package claudeagent

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"time"
)

// The control protocol: requests either side sends the other on the same
// streams as the messages, each answered by one control_response with the
// request's id. A control_cancel_request withdraws one and gets no answer.
// This file has ours; inbound.go claude's.

// ControlError is claude's error answer to a request.
type ControlError struct {
	Subtype string // the request's
	Message string
	// Code is claude's machine-readable reason, such as "not_found" or
	// "bypass_disabled", or "" when it gave none.
	Code string
}

func (e *ControlError) Error() string {
	return fmt.Sprintf("claude refused %s: %s", e.Subtype, e.Message)
}

// requestTimeout is how long a request waits for its answer, initialize's
// aside.
const requestTimeout = 60 * time.Second

// errorCode is the shape of a code worth keeping.
var errorCode = regexp.MustCompile(`^[a-z][a-z0-9_]{0,63}$`)

// reply is a request's answer: the response's payload, or why there is
// none.
type reply struct {
	payload json.RawMessage
	err     error
}

// controlResponse is a control_response's response.
type controlResponse struct {
	Subtype   string          `json:"subtype"` // "success" or "error"
	RequestID string          `json:"request_id"`
	Response  json.RawMessage `json:"response"`
	Error     string          `json:"error"`
	ErrorCode string          `json:"error_code"`
}

// newRequestID is an id for a request of ours: a count, which keeps them
// unique, and random hex, which keeps them from looking like another
// session's.
func (s *Session) newRequestID() string {
	var b [4]byte
	_, _ = rand.Read(b[:])
	return "req_" + strconv.FormatUint(s.nextID.Add(1), 10) + "_" + hex.EncodeToString(b[:])
}

// requestBody is body's fields with subtype among them. body is nil or
// encodes to a JSON object.
func requestBody(subtype string, body any) (map[string]json.RawMessage, error) {
	fields := map[string]json.RawMessage{}
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("claudeagent: encoding %s: %w", subtype, err)
		}
		if err := json.Unmarshal(b, &fields); err != nil || fields == nil {
			return nil, fmt.Errorf("claudeagent: %s's request isn't a JSON object", subtype)
		}
	}
	sub, _ := json.Marshal(subtype)
	fields["subtype"] = sub
	return fields, nil
}

// Request sends claude a request the package has no method for and
// decodes its answer into resp (when not nil). req is nil or encodes to a
// JSON object; its fields go beside the subtype. It waits at most 60 s,
// or less as ctx says; an error answer is a *ControlError.
func (s *Session) Request(ctx context.Context, subtype string, req, resp any) error {
	payload, err := s.request(ctx, subtype, req, true)
	if err != nil {
		return err
	}
	return decodeAnswer(subtype, payload, resp)
}

// decodeAnswer decodes a response's payload into v; a missing payload
// leaves v as it is.
func decodeAnswer(subtype string, payload json.RawMessage, v any) error {
	if v == nil || len(payload) == 0 || bytes.Equal(payload, []byte("null")) {
		return nil
	}
	if err := json.Unmarshal(payload, v); err != nil {
		return fmt.Errorf("claudeagent: claude's answer to %s: %w", subtype, err)
	}
	return nil
}

// request sends claude a request and waits for its answer, for ctx and,
// with timeout, at most requestTimeout. It returns the response's
// payload, a *ControlError for an error answer, or ErrClosed once the
// session has ended. A request ctx gives up on is withdrawn.
func (s *Session) request(ctx context.Context, subtype string, body any, timeout bool) (json.RawMessage, error) {
	fields, err := requestBody(subtype, body)
	if err != nil {
		return nil, err
	}
	id := s.newRequestID()
	ch := make(chan reply, 1)
	s.mu.Lock()
	if s.endErr != nil {
		s.mu.Unlock()
		return nil, s.endErr
	}
	s.pending[id] = ch
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		delete(s.pending, id)
		s.mu.Unlock()
	}()
	frame := map[string]any{"type": "control_request", "request_id": id, "request": fields}
	if subtype == "initialize" && !s.initWritten() {
		err = s.t.write(frame)
		s.initDone()
	} else {
		err = s.write(ctx, frame)
	}
	if err != nil {
		return nil, err
	}
	var expired <-chan time.Time
	if timeout {
		expired = s.after(requestTimeout)
	}
	select {
	case r := <-ch:
		if ce, ok := errors.AsType[*ControlError](r.err); ok {
			ce.Subtype = subtype
		}
		return r.payload, r.err
	case <-ctx.Done():
		s.withdraw(ctx, id)
		return nil, fmt.Errorf("claudeagent: %s: %w", subtype, ctx.Err())
	case <-expired:
		s.withdraw(ctx, id)
		return nil, fmt.Errorf("claudeagent: claude didn't answer %s in %s: %w", subtype, requestTimeout, context.DeadlineExceeded)
	}
}

// withdraw tells claude a request of ours is no longer wanted. It goes
// out whether or not ctx has ended.
func (s *Session) withdraw(ctx context.Context, id string) {
	_ = s.write(context.WithoutCancel(ctx), map[string]any{"type": "control_cancel_request", "request_id": id})
}

// answered hands a control_response to the request waiting for it. One
// for a request no one waits on (given up on, or never sent) is dropped.
func (s *Session) answered(raw json.RawMessage) {
	var f struct {
		Response controlResponse `json:"response"`
	}
	if err := json.Unmarshal(raw, &f); err != nil {
		s.log.Warn("claude wrote a control response that doesn't decode", "err", err)
		return
	}
	r := f.Response
	s.mu.Lock()
	ch, ok := s.pending[r.RequestID]
	delete(s.pending, r.RequestID)
	s.mu.Unlock()
	if !ok {
		s.log.Debug("claude answered a request no one waits on", "request_id", r.RequestID)
		return
	}
	if r.Subtype == "error" {
		e := &ControlError{Message: r.Error}
		if e.Message == "" {
			e.Message = "no reason given"
		}
		if errorCode.MatchString(r.ErrorCode) {
			e.Code = r.ErrorCode
		}
		ch <- reply{err: e}
		return
	}
	ch <- reply{payload: r.Response}
}

// failPending ends every request waiting for an answer with err.
func (s *Session) failPending(err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for id, ch := range s.pending {
		ch <- reply{err: err}
		delete(s.pending, id)
	}
}
