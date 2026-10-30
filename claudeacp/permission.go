package claudeacp

import (
	"bytes"
	"context"
	"encoding/json"
	"reflect"
	"slices"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// Permissions: claude asks before a tool runs (can_use_tool) and the
// client asks the user (session/request_permission), naming the call,
// which is shown first if the stream hasn't yet. An AskUserQuestion is a
// question (question.go), not a permission.

// The options a permission request offers, by id.
const (
	optAllowOnce   = "allow-once"
	optAllowAlways = "allow-always"
	optReject      = "reject"
)

// canUseTool asks the user whether a tool may run. What the work a
// cancel stopped still asks, a question too, is denied at once.
func (s *session) canUseTool(ctx context.Context, r claudeagent.PermissionRequest) (claudeagent.PermissionResult, error) {
	s.caughtUp(ctx)
	s.mu.Lock()
	stopped := s.dropTop && r.AgentID == "" // a subagent's work goes on
	s.mu.Unlock()
	if stopped {
		return claudeagent.Deny{Message: "The user cancelled this prompt.", Interrupt: true}, nil
	}
	if r.ToolName == "AskUserQuestion" {
		return s.askUser(ctx, r)
	}
	call := s.shown(r)
	if r.BlockedPath != "" {
		call.Locations = append(call.Locations, acp.ToolCallLocation{Path: r.BlockedPath})
	}
	var offered offers
	var opts []acp.PermissionOption
	switch r.ToolName {
	case "ExitPlanMode":
		opts = s.exitPlanOptions()
	case "EnterPlanMode":
		opts = enterPlanOptions
	default:
		offered = alwaysOptions(r, s.cwd)
		opts = permissionOptions(offered, r.DefaultToNo)
	}
	ctx, done := s.opened(ctx, r.AgentID)
	defer done()
	resp, err := s.a.client.RequestPermission(ctx, &acp.RequestPermissionRequest{
		SessionID: acp.SessionID(s.sessionOf(r.AgentID)), ToolCall: call, Options: opts})
	if err != nil {
		s.log.Info("asking for a permission", "err", err)
	}
	if r.ToolName == "ExitPlanMode" && err == nil && resp != nil && resp.Outcome.Selected != nil {
		return s.exitPlan(string(resp.Outcome.Selected.OptionID)), nil
	}
	return permissionResult(offered, resp, err), nil
}

// shown shows the call a request names, whole, if it hasn't been, and
// returns it as a permission request names it.
func (s *session) shown(r claudeagent.PermissionRequest) acp.ToolCallUpdate {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	parent := ""
	if t := ts.byID[r.ToolUseID]; t != nil {
		parent = t.parent
	}
	input := r.Input
	if len(input) == 0 {
		input = json.RawMessage(`{}`)
	}
	if ts.byID[r.ToolUseID] == nil && r.AgentID != "" {
		// A subagent's call its stream hasn't shown: not one the turn
		// leaves open when it ends, and of the stream of the call that
		// started the subagent, if claude has said which.
		parent = s.callOf(r.AgentID)
		ts.byID[r.ToolUseID] = &tool{id: r.ToolUseID, name: r.ToolName, agent: r.AgentID, parent: parent}
	}
	// A call the stream showed whole keeps the input it showed, as with
	// claude-agent-acp, when the request's is claude's parse of it, the
	// same but for its keys' order. Input a hook changed is shown again,
	// so the call reads as what the user is asked to allow.
	t := ts.byID[r.ToolUseID]
	if t == nil || !t.whole || !sameJSON(t.sent["rawInput"], input) {
		t = s.wholeLocked(parent, r.ToolUseID, r.ToolName, input)
	}
	v := toolView(t.name, input, ts.cwd)
	cc := map[string]any{"toolName": t.name}
	if t.parent != "" {
		cc["parentToolUseId"] = t.parent
	}
	if r.MCPServer != "" {
		cc["mcpServer"] = map[string]any{"name": r.MCPServer}
	}
	return acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(t.id), Name: t.name, Status: acp.ToolCallStatusPending,
		Title: v.title, Kind: v.kind, Content: v.content, Locations: v.locations, RawInput: input,
		Meta: map[string]any{"claudeCode": cc}}
}

// permissionOptions are Yes and No, and between them the "don't ask
// again" options offered (always.go). Claude's default-to-no puts No
// first.
func permissionOptions(offered offers, defaultToNo bool) []acp.PermissionOption {
	opts := []acp.PermissionOption{{OptionID: optAllowOnce, Name: "Yes", Kind: acp.PermissionOptionKindAllowOnce}}
	for _, a := range offered {
		opts = append(opts, acp.PermissionOption{OptionID: acp.PermissionOptionID(a.id), Name: a.name, Kind: acp.PermissionOptionKindAllowAlways})
	}
	no := acp.PermissionOption{OptionID: optReject, Name: "No", Kind: acp.PermissionOptionKindRejectOnce}
	if defaultToNo {
		return append([]acp.PermissionOption{no}, opts...)
	}
	return append(opts, no)
}

// permissionResult is the user's pick as claude's answer: a "don't ask
// again" gives claude its rules. No answer (the request withdrawn, the
// turn cancelled, an option the request didn't offer) stops the tool and
// the turn.
func permissionResult(offered offers, resp *acp.RequestPermissionResponse, err error) claudeagent.PermissionResult {
	if err != nil || resp == nil || resp.Outcome.Selected == nil {
		return claudeagent.Deny{Message: "The user cancelled.", Interrupt: true}
	}
	switch id := string(resp.Outcome.Selected.OptionID); id {
	case optAllowOnce:
		return claudeagent.Allow{Classification: claudeagent.UserTemporary}
	case optReject:
		return claudeagent.Deny{Message: "The user refused permission to run the tool.", Classification: claudeagent.UserReject}
	default:
		if i := slices.IndexFunc(offered, func(a always) bool { return a.id == id }); i >= 0 {
			return claudeagent.Allow{UpdatedPermissions: offered[i].updates, Classification: claudeagent.UserPermanent}
		}
	}
	return claudeagent.Deny{Message: "The user cancelled.", Interrupt: true}
}

// ask is a permission or question the user is asked, while it is open.
type ask struct {
	cancel    context.CancelFunc
	agent     string // the subagent asking, if one is
	withdrawn bool   // a cancel withdrew it
}

// opened counts a permission or question the user is asked while it is
// open, so steers wait behind it and a cancel withdraws it, and a
// subagent asking requires action meanwhile; done closes it.
func (s *session) opened(ctx context.Context, agent string) (context.Context, func()) {
	ctx, cancel := context.WithCancel(ctx)
	a := &ask{cancel: cancel, agent: agent}
	s.mu.Lock()
	s.asks++
	s.lastAsk++
	n := s.lastAsk
	s.open[n] = a
	s.mu.Unlock()
	if agent != "" {
		s.asking(agent, 1, false)
	}
	return ctx, func() {
		cancel()
		s.mu.Lock()
		s.asks--
		delete(s.open, n)
		withdrawn := a.withdrawn
		s.mu.Unlock()
		if agent != "" {
			s.asking(agent, -1, withdrawn)
		}
	}
}

// withdraw withdraws the open requests which says.
func (s *session) withdraw(which func(*ask) bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.withdrawLocked(which)
}

func (s *session) withdrawLocked(which func(*ask) bool) {
	for _, a := range s.open {
		if which(a) {
			a.withdrawn = true
			a.cancel()
		}
	}
}

// sameJSON says whether a and b are the same JSON value, whatever their
// keys' order and spacing.
func sameJSON(a string, b json.RawMessage) bool {
	var x, y any
	da, db := json.NewDecoder(strings.NewReader(a)), json.NewDecoder(bytes.NewReader(b))
	da.UseNumber()
	db.UseNumber()
	return da.Decode(&x) == nil && db.Decode(&y) == nil && reflect.DeepEqual(x, y)
}
