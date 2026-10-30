package claudeagent_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// A request's body must be a JSON object.
func TestRequestBody(t *testing.T) {
	s, f := start(t, claudeagent.Options{})
	for _, body := range []any{"x", []int{1}, func() {}} {
		if err := s.Request(context.Background(), "x", body, nil); err == nil {
			t.Errorf("%v sent", body)
		}
	}
	finish(t, s, f)
}

// An error answer is a *ControlError; its code is kept only when it
// looks like one.
func TestControlError(t *testing.T) {
	for _, tc := range []struct {
		name, response string
		want           claudeagent.ControlError
	}{
		{"code", `"error":"no such model","error_code":"not_found"`, claudeagent.ControlError{Subtype: "set_model", Message: "no such model", Code: "not_found"}},
		{"bad code", `"error":"x","error_code":"Not Found"`, claudeagent.ControlError{Subtype: "set_model", Message: "x"}},
		{"long code", `"error":"x","error_code":"a2345678901234567890123456789012345678901234567890123456789012345"`, claudeagent.ControlError{Subtype: "set_model", Message: "x"}},
		{"no message", ``, claudeagent.ControlError{Subtype: "set_model", Message: "no reason given"}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			resp := `{"subtype":"error","request_id":"$req"`
			if tc.response != "" {
				resp += "," + tc.response
			}
			s, f := start(t, claudeagent.Options{},
				claudetest.Expect(`{"type":"control_request","request":{"subtype":"set_model"}}`),
				claudetest.Send(`{"type":"control_response","response":`+resp+`}}`),
			)
			var ce *claudeagent.ControlError
			if err := s.Request(context.Background(), "set_model", nil, nil); !errors.As(err, &ce) || *ce != tc.want {
				t.Fatalf("%v", err)
			}
			finish(t, s, f)
		})
	}
}

// clock is a fake clock: each wait a request asks for is a timer the
// test fires.
type clock chan chan time.Time

func (c clock) after(time.Duration) <-chan time.Time {
	fire := make(chan time.Time, 1)
	c <- fire
	return fire
}

// Begun requests reach claude in the order begun, before any is
// answered, and each wait gets its own answer.
func TestBegin(t *testing.T) {
	s, f := start(t, claudeagent.Options{},
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"cancel_async_message","message_uuid":"u1"}}`),
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"interrupt"}}`),
		answer(`{"still_queued":[]}`),
		claudetest.Expect(`{"type":"control_cancel_request"}`),
		claudetest.Send(`{"type":"system","subtype":"status","status":"idle"}`),
	)
	ctx, cancel := context.WithCancel(context.Background())
	drop, err := s.Begin(ctx, "cancel_async_message", map[string]any{"message_uuid": "u1"})
	if err != nil {
		t.Fatal(err)
	}
	stop, err := s.Begin(context.Background(), "interrupt", nil)
	if err != nil {
		t.Fatal(err)
	}
	var r struct {
		StillQueued []string `json:"still_queued"`
	}
	if err := stop.Wait(&r); err != nil || r.StillQueued == nil {
		t.Fatalf("%v %+v", err, r)
	}
	cancel() // the first is never answered: it gives up, withdrawn
	if err := drop.Wait(nil); !errors.Is(err, context.Canceled) {
		t.Fatalf("%v", err)
	}
	if m, ok := next(t, s).(*claudeagent.Status); !ok || m.Status != "idle" {
		t.Errorf("%+v", m)
	}
	finish(t, s, f)
}

// A request with no answer gives up after its timeout, or when its ctx
// ends, and is withdrawn; an answer that comes later is dropped, as is
// one for a request never sent, and keep_alive is no message.
func TestRequestGivesUp(t *testing.T) {
	s, f := start(t, claudeagent.Options{},
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"set_model"}}`),
		claudetest.Expect(`{"type":"control_cancel_request"}`),
		answer(`{}`),
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"stop_task"}}`),
		claudetest.Expect(`{"type":"control_cancel_request"}`),
		claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"req_never","response":{}}}`),
		claudetest.Send(`{"type":"keep_alive"}`),
		claudetest.Send(`{"type":"system","subtype":"status","status":"idle"}`),
	)
	c := make(clock, 1)
	claudeagent.SetClock(s, c.after)
	errs := make(chan error)
	go func() { errs <- s.Request(context.Background(), "set_model", nil, nil) }()
	(<-c) <- time.Time{}
	if err := <-errs; !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("%v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	go func() { errs <- s.Request(ctx, "stop_task", nil, nil) }()
	<-c // waiting for its answer
	cancel()
	if err := <-errs; !errors.Is(err, context.Canceled) {
		t.Fatalf("%v", err)
	}
	if m, ok := next(t, s).(*claudeagent.Status); !ok || m.Status != "idle" {
		t.Errorf("%+v", m)
	}
	finish(t, s, f)
}

// Close fails the requests waiting for an answer with ErrClosed; once
// claude's output ends, new requests fail at once.
func TestRequestEnds(t *testing.T) {
	s, f := start(t, claudeagent.Options{}, claudetest.Expect(`{"type":"control_request","request":{"subtype":"set_model"}}`))
	c := make(clock, 1)
	claudeagent.SetClock(s, c.after)
	errs := make(chan error)
	go func() { errs <- s.Request(context.Background(), "set_model", nil, nil) }()
	<-c
	_ = s.Close()
	if err := <-errs; !errors.Is(err, claudeagent.ErrClosed) {
		t.Errorf("%v", err)
	}
	if err := s.Request(context.Background(), "stop_task", nil, nil); !errors.Is(err, claudeagent.ErrClosed) {
		t.Errorf("%v", err)
	}
	finish(t, s, f)

	s, f = start(t, claudeagent.Options{}, claudetest.Exit(0, ""))
	for range s.Messages() {
		t.Error("a message")
	}
	if err := s.Request(context.Background(), "set_model", nil, nil); !errors.Is(err, claudeagent.ErrClosed) {
		t.Errorf("%v", err)
	}
	finish(t, s, f)
}
