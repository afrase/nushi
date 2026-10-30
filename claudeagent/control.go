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

// requestBody is a request of ours: a struct that embeds ask, or a
// rawRequest.
type requestBody interface{ subtype() string }

// ask is what every request of ours has: which request it is. Embedded
// first, it is the first field on the wire.
type ask struct {
	Subtype string `json:"subtype,omitempty"` // "" only in initRequest's, until Start names it
}

func (a ask) subtype() string { return a.Subtype }

// rawRequest is a request the package has no type for (Request's and
// Begin's): the caller's fields with the subtype among them.
type rawRequest struct {
	name   string
	fields map[string]json.RawMessage
}

func (r rawRequest) subtype() string { return r.name }

// MarshalJSON writes the fields.
func (r rawRequest) MarshalJSON() ([]byte, error) { return json.Marshal(r.fields) }

// newRawRequest is a request of subtype with body's fields beside it.
// body is nil or encodes to a JSON object; a subtype among its fields is
// replaced.
func newRawRequest(subtype string, body any) (rawRequest, error) {
	fields := map[string]json.RawMessage{}
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return rawRequest{}, fmt.Errorf("claudeagent: encoding %s: %w", subtype, err)
		}
		if err := json.Unmarshal(b, &fields); err != nil || fields == nil {
			return rawRequest{}, fmt.Errorf("claudeagent: %s's request isn't a JSON object", subtype)
		}
	}
	sub, _ := json.Marshal(subtype)
	fields["subtype"] = sub
	return rawRequest{name: subtype, fields: fields}, nil
}

// controlRequestLine is a request of ours as written.
type controlRequestLine struct {
	Type      string      `json:"type"` // "control_request"
	RequestID string      `json:"request_id"`
	Request   requestBody `json:"request"`
}

// cancelRequestLine withdraws a request of ours.
type cancelRequestLine struct {
	Type      string `json:"type"` // "control_cancel_request"
	RequestID string `json:"request_id"`
}

// Request sends claude a request the package has no method for and
// decodes its answer into resp (when not nil). req is nil or encodes to a
// JSON object; its fields go beside the subtype. It waits at most 60 s,
// or less as ctx says; an error answer is a *ControlError.
func (s *Session) Request(ctx context.Context, subtype string, req, resp any) error {
	body, err := newRawRequest(subtype, req)
	if err != nil {
		return err
	}
	return s.do(ctx, body, resp)
}

// do sends claude a request and decodes its answer into resp (when not
// nil), as Request does.
func (s *Session) do(ctx context.Context, body requestBody, resp any) error {
	payload, err := s.request(ctx, body, true)
	if err != nil {
		return err
	}
	return decodeAnswer(body.subtype(), payload, resp)
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
func (s *Session) request(ctx context.Context, body requestBody, timeout bool) (json.RawMessage, error) {
	c, err := s.begin(ctx, body, timeout)
	if err != nil {
		return nil, err
	}
	return c.answer()
}

// Call is a request of ours that has been written and waits for its
// answer: Begin's.
type Call struct {
	s       *Session
	ctx     context.Context //nolint:containedctx // the request's: Wait gives up, and withdraws it, when it ends
	id      string
	subtype string
	ch      chan reply
	timeout bool
}

// begin writes claude a request, as request does, and returns once it is
// written; the Call's answer must then be waited for, once.
func (s *Session) begin(ctx context.Context, body requestBody, timeout bool) (*Call, error) {
	c := &Call{s: s, ctx: ctx, id: s.newRequestID(), subtype: body.subtype(), ch: make(chan reply, 1), timeout: timeout}
	s.mu.Lock()
	if s.endErr != nil {
		s.mu.Unlock()
		return nil, s.endErr
	}
	s.pending[c.id] = c.ch
	s.mu.Unlock()
	frame := controlRequestLine{Type: "control_request", RequestID: c.id, Request: body}
	var err error
	if c.subtype == "initialize" && !s.initWritten() {
		err = s.t.write(frame)
		s.initDone()
	} else {
		err = s.write(ctx, frame)
	}
	if err != nil {
		c.forget()
		return nil, err
	}
	return c, nil
}

// forget stops waiting for c's answer: one that comes now is dropped.
func (c *Call) forget() {
	c.s.mu.Lock()
	delete(c.s.pending, c.id)
	c.s.mu.Unlock()
}

// answer waits for c's answer and returns its payload, as request does.
func (c *Call) answer() (json.RawMessage, error) {
	defer c.forget()
	var expired <-chan time.Time
	if c.timeout {
		expired = c.s.after(requestTimeout)
	}
	select {
	case r := <-c.ch:
		if ce, ok := errors.AsType[*ControlError](r.err); ok {
			ce.Subtype = c.subtype
		}
		return r.payload, r.err
	case <-c.ctx.Done():
		c.s.withdraw(c.ctx, c.id)
		return nil, fmt.Errorf("claudeagent: %s: %w", c.subtype, c.ctx.Err())
	case <-expired:
		c.s.withdraw(c.ctx, c.id)
		return nil, fmt.Errorf("claudeagent: claude didn't answer %s in %s: %w", c.subtype, requestTimeout, context.DeadlineExceeded)
	}
}

// Wait waits for the answer as Request does and decodes it into resp
// (when not nil). Call it once.
func (c *Call) Wait(resp any) error {
	payload, err := c.answer()
	if err != nil {
		return err
	}
	return decodeAnswer(c.subtype, payload, resp)
}

// Begin sends claude a request as Request does, but returns once it is
// written; the Call's Wait waits for the answer. Requests begun one after
// another reach claude in that order, which requests made on goroutines
// of their own don't.
func (s *Session) Begin(ctx context.Context, subtype string, req any) (*Call, error) {
	body, err := newRawRequest(subtype, req)
	if err != nil {
		return nil, err
	}
	return s.begin(ctx, body, true)
}

// withdraw tells claude a request of ours is no longer wanted. It goes
// out whether or not ctx has ended.
func (s *Session) withdraw(ctx context.Context, id string) {
	_ = s.write(context.WithoutCancel(ctx), cancelRequestLine{Type: "control_cancel_request", RequestID: id})
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
