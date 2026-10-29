package claudeagent_test

import (
	"context"
	"encoding/json"
	"errors"
	"sync/atomic"
	"testing"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// sendRequest is claude sending a request with id c1.
func sendRequest(request string) claudetest.Step {
	return claudetest.Send(`{"type":"control_request","request_id":"c1","request":` + request + `}`)
}

// expectAnswer expects the answer to c1: a success with payload, or an
// error with message.
func expectAnswer(payload, message string) claudetest.Step {
	if message != "" {
		m, _ := json.Marshal(message)
		return claudetest.Expect(`{"type":"control_response","response":{"subtype":"error","request_id":"c1","error":` + string(m) + `}}`)
	}
	return claudetest.Expect(`{"type":"control_response","response":{"subtype":"success","request_id":"c1","response":` + payload + `}}`)
}

// Each request of claude's gets its answer from the matching callback,
// or a default; credentials are never handed out.
func TestInbound(t *testing.T) {
	onControl := func(_ context.Context, subtype string, req json.RawMessage) (any, error) {
		switch subtype {
		case "echo":
			return req, nil
		case "fail":
			return nil, errors.New("no way")
		case "empty":
			return nil, nil //nolint:nilnil // no payload is what the case tests
		}
		return map[string]string{"token": "secret"}, nil // what no credential request may reach
	}
	for _, tc := range []struct {
		name       string
		o          claudeagent.Options
		request    string
		payload    string
		errMessage string
	}{
		{"unknown", claudeagent.Options{}, `{"subtype":"mcp_message"}`, "", "Unsupported control request subtype: mcp_message"},
		{"OnControl", claudeagent.Options{OnControl: onControl}, `{"subtype":"echo","n":1}`, `{"subtype":"echo","n":1}`, ""},
		{"OnControl nil", claudeagent.Options{OnControl: onControl}, `{"subtype":"empty"}`, `{}`, ""},
		{"OnControl fails", claudeagent.Options{OnControl: onControl}, `{"subtype":"fail"}`, "", "no way"},
		{"OnControl unsupported", claudeagent.Options{OnControl: func(context.Context, string, json.RawMessage) (any, error) {
			return nil, claudeagent.ErrUnsupported
		}}, `{"subtype":"x"}`, "", "Unsupported control request subtype: x"},
		{"oauth", claudeagent.Options{OnControl: onControl}, `{"subtype":"oauth_token_refresh"}`, "", "Unsupported control request subtype: oauth_token_refresh"},
		{"host auth", claudeagent.Options{OnControl: onControl}, `{"subtype":"host_auth_token_refresh"}`, "", "Unsupported control request subtype: host_auth_token_refresh"},
		{"remote control", claudeagent.Options{OnControl: onControl}, `{"subtype":"remote_control_work_secret"}`, "", "Unsupported control request subtype: remote_control_work_secret"},
		{"hook_callback", claudeagent.Options{}, `{"subtype":"hook_callback","callback_id":"hook_9"}`, "", `claudeagent: no hook "hook_9"`},
		{"elicitation", claudeagent.Options{}, `{"subtype":"elicitation","mcp_server_name":"s","message":"m"}`, `{"action":"decline"}`, ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, f := start(t, tc.o, sendRequest(tc.request), expectAnswer(tc.payload, tc.errMessage))
			finish(t, s, f)
		})
	}
}

// A user dialog is never answered: the session declares no dialog kinds,
// and an answer would leave the dialog open.
func TestDialogUnanswered(t *testing.T) {
	s, f := start(t, claudeagent.Options{},
		claudetest.Send(`{"type":"control_request","request_id":"d1","request":{"subtype":"request_user_dialog","dialog_kind":"k"}}`),
		sendRequest(`{"subtype":"x"}`),
		expectAnswer("", "Unsupported control request subtype: x"),
	)
	finish(t, s, f)
}

// A request claude withdraws ends its callback's context, and what the
// callback returns then isn't sent; so for one the session closes under.
func TestWithdrawn(t *testing.T) {
	asked := make(chan struct{}, 2)
	returned := make(chan struct{}, 2)
	wait := func(ctx context.Context, _ string, _ json.RawMessage) (any, error) {
		asked <- struct{}{}
		<-ctx.Done()
		returned <- struct{}{}
		return map[string]bool{"late": true}, nil
	}
	s, f := start(t, claudeagent.Options{OnControl: wait},
		sendRequest(`{"subtype":"x"}`),
		claudetest.Send(`{"type":"control_cancel_request","request_id":"c1"}`),
		claudetest.Send(`{"type":"control_cancel_request","request_id":"unknown"}`),
	)
	<-asked
	<-returned
	finish(t, s, f) // the fake fails on a line after the script

	s, f = start(t, claudeagent.Options{OnControl: wait}, sendRequest(`{"subtype":"x"}`))
	<-asked
	_ = s.Close()
	<-returned
	finish(t, s, f)
}

// A request whose id is still being handled is a duplicate: dropped.
func TestDuplicate(t *testing.T) {
	var calls atomic.Int32
	release := make(chan struct{})
	slow := func(context.Context, string, json.RawMessage) (any, error) {
		calls.Add(1)
		<-release
		return map[string]int{"n": 1}, nil
	}
	s, f := start(t, claudeagent.Options{OnControl: slow},
		sendRequest(`{"subtype":"x"}`),
		sendRequest(`{"subtype":"x"}`),
		claudetest.Send(`{"type":"system","subtype":"status","status":"requesting"}`),
		expectAnswer(`{"n":1}`, ""),
		// Once answered the id is free again.
		sendRequest(`{"subtype":"x"}`),
		expectAnswer(`{"n":1}`, ""),
	)
	next(t, s) // both requests read
	close(release)
	finish(t, s, f)
	if n := calls.Load(); n != 2 {
		t.Errorf("asked %d times", n)
	}
}
