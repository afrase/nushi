package claudeagent

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"maps"
	"slices"
	"strconv"
	"time"
)

// Hooks: functions of the caller's that claude runs at points in a turn,
// as it runs the hooks in its settings. Each is registered in initialize
// under an id of the package's, and claude calls it back by that id
// (hook_callback).

// HookEvent is when a hook runs, named as in claude's settings. These are
// the common ones; claude knows more, and any of its names works.
type HookEvent string

// Hook events.
const (
	HookPreToolUse         HookEvent = "PreToolUse"
	HookPostToolUse        HookEvent = "PostToolUse"
	HookPostToolUseFailure HookEvent = "PostToolUseFailure"
	HookUserPromptSubmit   HookEvent = "UserPromptSubmit"
	HookStop               HookEvent = "Stop"
	HookSubagentStart      HookEvent = "SubagentStart"
	HookSubagentStop       HookEvent = "SubagentStop"
	HookPreCompact         HookEvent = "PreCompact"
	HookPostCompact        HookEvent = "PostCompact"
	HookNotification       HookEvent = "Notification"
	HookPermissionRequest  HookEvent = "PermissionRequest"
)

// HookFunc is a hook. Its ctx ends when claude withdraws the call, when
// the call's deadline passes, if claude gave one, or when the session
// closes. An answer returned after that isn't sent: claude has gone on
// without it.
type HookFunc func(ctx context.Context, in HookInput) (HookOutput, error)

// HookMatcher is a hook and when it runs.
type HookMatcher struct {
	// Matcher picks what the hook runs for, as in claude's settings: for
	// the tool events a tool name or names ("Edit|Write"); "" = all.
	Matcher string
	// Timeout is how long claude waits for the hook; 0 = claude's
	// default.
	Timeout time.Duration
	Fn      HookFunc
}

// HookInput is what claude tells a hook. The fields past AgentType are
// the tool events'; Raw has everything, the other events' fields among
// them.
type HookInput struct {
	Event          HookEvent      `json:"hook_event_name"`
	SessionID      string         `json:"session_id"`
	TranscriptPath string         `json:"transcript_path"`
	Cwd            string         `json:"cwd"`
	PermissionMode PermissionMode `json:"permission_mode"`
	AgentID        string         `json:"agent_id"`   // the subagent it runs for, if one
	AgentType      string         `json:"agent_type"` // that subagent's kind

	ToolName     string          `json:"tool_name"`
	ToolInput    json.RawMessage `json:"tool_input"`
	ToolResponse json.RawMessage `json:"tool_response"` // PostToolUse's: what the tool returned
	ToolUseID    string          `json:"tool_use_id"`

	Raw json.RawMessage `json:"-"`
}

// HookOutput is a hook's answer. The zero value lets claude go on as if
// the hook weren't there.
type HookOutput struct {
	Stop           bool   // claude stops after the hook
	StopReason     string // why, with Stop: shown to the user
	SuppressOutput bool   // keeps the hook's output out of the transcript
	Decision       HookDecision
	Reason         string // why, for the model
	SystemMessage  string // a warning shown to the user
	// Async says the hook goes on in the background: claude doesn't wait
	// for it, or waits AsyncTimeout at most. The other fields are then
	// not sent.
	Async        bool
	AsyncTimeout time.Duration
	// Specific is the event's own fields (hookSpecificOutput), such as
	// PreToolUse's permissionDecision or PostToolUse's
	// additionalContext. hookEventName is filled in.
	Specific map[string]any
}

// HookDecision is a hook's say on what its event is about.
type HookDecision string

// HookBlock stops what the event is about: the tool call, the prompt, the
// stop.
const HookBlock HookDecision = "block"

// hookCallbackID is the id the nth hook is registered under, as the
// official SDKs make them.
func hookCallbackID(n int) string { return "hook_" + strconv.Itoa(n) }

// hookRegistration is a HookMatcher as initialize registers it: by its
// callback's id. Timeout is in seconds.
type hookRegistration struct {
	HookCallbackIDs []string `json:"hookCallbackIds"`
	Matcher         string   `json:"matcher,omitempty"`
	Timeout         float64  `json:"timeout,omitempty"`
}

// registerHooks is initialize's hooks field for hooks, and the hooks by
// the ids it gives them. Events go in name order, so the ids are the same
// from run to run.
func registerHooks(hooks map[HookEvent][]HookMatcher) (map[HookEvent][]hookRegistration, map[string]HookFunc, error) {
	wire := map[HookEvent][]hookRegistration{}
	byID := map[string]HookFunc{}
	for _, event := range slices.Sorted(maps.Keys(hooks)) {
		for _, m := range hooks[event] {
			if m.Fn == nil {
				return nil, nil, fmt.Errorf("claudeagent: a %s hook with no Fn", event)
			}
			id := hookCallbackID(len(byID))
			byID[id] = m.Fn
			wire[event] = append(wire[event], hookRegistration{
				HookCallbackIDs: []string{id}, Matcher: m.Matcher, Timeout: max(m.Timeout, 0).Seconds(),
			})
		}
	}
	return wire, byID, nil
}

// hookCallback runs the hook a hook_callback request names and returns
// its answer as claude reads it. An id the session didn't register is an
// error.
func (s *Session) hookCallback(ctx context.Context, raw json.RawMessage) (any, error) {
	var r struct {
		CallbackID string          `json:"callback_id"`
		Input      json.RawMessage `json:"input"`
		ToolUseID  string          `json:"tool_use_id"`
		DeadlineMS int64           `json:"deadline_ms"` // optional; claude goes on without the answer after it
	}
	if err := json.Unmarshal(raw, &r); err != nil {
		return nil, fmt.Errorf("claudeagent: a hook callback that doesn't decode: %w", err)
	}
	fn, ok := s.hooks[r.CallbackID]
	if !ok {
		return nil, fmt.Errorf("claudeagent: no hook %q", r.CallbackID)
	}
	var in HookInput
	if len(r.Input) > 0 && !bytes.Equal(r.Input, []byte("null")) {
		if err := json.Unmarshal(r.Input, &in); err != nil {
			return nil, fmt.Errorf("claudeagent: a hook's input that doesn't decode: %w", err)
		}
		in.Raw = r.Input
	}
	if in.ToolUseID == "" {
		in.ToolUseID = r.ToolUseID
	}
	// claude doesn't withdraw a call whose deadline passes, it just stops
	// waiting; so the hook is stopped here, timed from when the call came.
	hctx := ctx
	if r.DeadlineMS > 0 {
		var cancel context.CancelFunc
		hctx, cancel = context.WithTimeout(ctx, time.Duration(r.DeadlineMS)*time.Millisecond)
		defer cancel()
	}
	out, err := fn(hctx, in)
	if hctx.Err() != nil && ctx.Err() == nil {
		return nil, errNoReply // too late: nobody waits for it
	}
	if err != nil {
		return nil, err
	}
	return hookAnswer(in.Event, out), nil
}

// hookReply is a hook's answer as claude reads it: only what is set. The
// fields are in their keys' order, as claude has always been sent them.
type hookReply struct {
	Async              bool           `json:"async,omitempty"`
	AsyncTimeout       int64          `json:"asyncTimeout,omitempty"` // in milliseconds
	Continue           *bool          `json:"continue,omitempty"`     // only ever false: claude stops
	Decision           HookDecision   `json:"decision,omitempty"`
	HookSpecificOutput map[string]any `json:"hookSpecificOutput,omitzero"`
	Reason             string         `json:"reason,omitempty"`
	StopReason         string         `json:"stopReason,omitempty"`
	SuppressOutput     bool           `json:"suppressOutput,omitempty"`
	SystemMessage      string         `json:"systemMessage,omitempty"`
}

// hookAnswer is out as claude reads it; an async one says only that.
func hookAnswer(event HookEvent, out HookOutput) hookReply {
	if out.Async {
		return hookReply{Async: true, AsyncTimeout: max(out.AsyncTimeout, 0).Milliseconds()}
	}
	r := hookReply{
		Decision: out.Decision, Reason: out.Reason, StopReason: out.StopReason,
		SuppressOutput: out.SuppressOutput, SystemMessage: out.SystemMessage,
	}
	if out.Stop {
		r.Continue = new(false)
	}
	if out.Specific != nil {
		r.HookSpecificOutput = maps.Clone(out.Specific)
		if event != "" {
			r.HookSpecificOutput["hookEventName"] = event
		}
	}
	return r
}
