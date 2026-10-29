package claudeacp

import (
	"context"
	"encoding/json"
	"slices"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

const suggestion = `{"type":"addRules","rules":[{"toolName":"Bash","ruleContent":"rm:*"}],"behavior":"allow","destination":"localSettings"}`

// canUseTool is claude asking whether a tool may run.
func canUseTool(id, tool, input, fields string) claudetest.Step {
	return sendf(`{"type":"control_request","request_id":"p_` + id + `","request":{"subtype":"can_use_tool","tool_name":"` + tool +
		`","input":` + input + `,"tool_use_id":"` + id + `"` + fields + `}}`)
}

// answers expects claude to get answer to the request about call id.
func answers(id, answer string) claudetest.Step {
	return claudetest.Expect(`{"type":"control_response","response":{"subtype":"success","request_id":"p_` + id + `","response":` + answer + `}}`)
}

// pick answers a permission request with option, or cancelled.
func pick(option string) func(context.Context, *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	return func(context.Context, *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
		if option == "" {
			return &acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{Cancelled: true}}, nil
		}
		return &acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{Selected: &acp.SelectedPermissionOutcome{OptionID: acp.PermissionOptionID(option)}}}, nil
	}
}

// The user's pick goes back as claude reads it: allowed once, allowed
// with claude's own rules, refused, or (cancelled, or an option never
// offered) stopped with the turn. The request names the call, shown
// first when the stream hasn't shown it.
func TestPermission(t *testing.T) {
	input := `{"command":"rm x"}`
	for _, tc := range []struct {
		pick, answer string
		streamed     bool
	}{
		{optAllowOnce, `{"behavior":"allow","updatedInput":` + input + `,"toolUseID":"toolu_1","decisionClassification":"user_temporary"}`, true},
		{optAllowAlways, `{"behavior":"allow","updatedInput":` + input + `,"updatedPermissions":[` + suggestion + `],"decisionClassification":"user_permanent"}`, false},
		{optReject, `{"behavior":"deny","message":"The user refused permission to run the tool.","toolUseID":"toolu_1","decisionClassification":"user_reject"}`, true},
		{"", `{"behavior":"deny","interrupt":true}`, true},
		{"maybe", `{"behavior":"deny","interrupt":true}`, true},
	} {
		t.Run(tc.pick, func(t *testing.T) {
			steps := []claudetest.Step{user("id2"), echo("id2")}
			if tc.streamed {
				steps = append(steps, assistant(`{"type":"tool_use","id":"toolu_1","name":"Bash","input":`+input+`}`))
			}
			steps = append(steps, canUseTool("toolu_1", "Bash", input, `,"permission_suggestions":[`+suggestion+`],"blocked_path":"/x"`),
				answers("toolu_1", tc.answer), result(names("id2")), claudetest.Send(idle))
			p := start(t, &acp.ClientCapabilities{}, fake(steps...))
			var asked *acp.RequestPermissionRequest
			p.permit = func(ctx context.Context, req *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
				asked = req
				return pick(tc.pick)(ctx, req)
			}
			stopReason(p.prompt(t, p.open(t), "go"))
			if asked == nil {
				t.Fatal("not asked")
			}
			call, _ := json.Marshal(asked.ToolCall)
			if want := `{"toolCallId":"toolu_1","kind":"execute","status":"pending","title":"rm x","name":"Bash","locations":[{"path":"/x"}],"rawInput":{"command":"rm x"},"_meta":{"claudeCode":{"toolName":"Bash"}}}`; string(call) != want {
				t.Errorf("call %s", call)
			}
			var opts []string
			for _, o := range asked.Options {
				opts = append(opts, string(o.OptionID)+" "+string(o.Kind)+" "+o.Name)
			}
			if want := []string{"allow-once allow_once Yes", "allow-always allow_always Yes, and don't ask again", "reject reject_once No"}; !slices.Equal(opts, want) {
				t.Errorf("%q", opts)
			}
			if ups := p.toolUpdates(); len(ups) == 0 || !strings.HasPrefix(ups[0], `tool_call {"toolCallId":"toolu_1","title":"rm x"`) {
				t.Errorf("%q", ups)
			}
		})
	}
}

// "Don't ask again" is offered only with claude's rules for it, and not
// when a rule of the user's asks each time; default-to-no puts No first.
func TestPermissionOptions(t *testing.T) {
	rules := []claudeagent.PermissionUpdate{{Type: "addRules"}}
	for _, tc := range []struct {
		r    claudeagent.PermissionRequest
		want string
	}{
		{claudeagent.PermissionRequest{}, "allow-once reject"},
		{claudeagent.PermissionRequest{Suggestions: rules}, "allow-once allow-always reject"},
		{claudeagent.PermissionRequest{Suggestions: rules, MatchedAskRule: true}, "allow-once reject"},
		{claudeagent.PermissionRequest{Suggestions: rules, SuppressAlwaysAllowRule: true}, "allow-once reject"},
		{claudeagent.PermissionRequest{Suggestions: rules, DefaultToNo: true}, "reject allow-once allow-always"},
	} {
		var got []string
		for _, o := range permissionOptions(tc.r) {
			got = append(got, string(o.OptionID))
		}
		if strings.Join(got, " ") != tc.want {
			t.Errorf("%+v: %q", tc.r, got)
		}
	}
}

// A cancel withdraws an open permission request, which stops the tool and
// the turn; a steer while it is open waits for it (priority "later").
func TestPermissionWithdrawn(t *testing.T) {
	f := fake(user("id2"), echo("id2"), canUseTool("toolu_1", "Bash", `{}`, ""),
		claudetest.Expect(`{"type":"user","uuid":"id3","priority":"later"}`),
		answers("toolu_1", `{"behavior":"deny","interrupt":true}`),
		result(names("id2")), claudetest.Send(idle))
	p := start(t, nil, f)
	asked := make(chan struct{})
	p.permit = func(ctx context.Context, _ *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
		close(asked)
		<-ctx.Done()
		return nil, ctx.Err()
	}
	sid := p.open(t)
	w := p.prompt(t, sid, "go")
	wait(t, asked, "the request")
	if outcome, err := steering.Steer(t.Context(), p.AgentConn, string(sid), steerText("also")); err != nil || outcome != steering.Injected {
		t.Fatalf("%s %v", outcome, err)
	}
	if err := p.Cancel(t.Context(), &acp.CancelNotification{SessionID: sid}); err != nil {
		t.Fatal(err)
	}
	if got := stopReason(w); got != "cancelled" {
		t.Error(got)
	}
}

// What the work a cancel stopped still asks, a question too, is denied
// at once: the client isn't asked.
func TestStoppedWorkAsks(t *testing.T) {
	for _, tc := range []struct{ tool, input string }{
		{"Bash", `{"command":"ls"}`},
		{"AskUserQuestion", `{"questions":[{"question":"Which?","options":[{"label":"A"}]}]}`},
	} {
		t.Run(tc.tool, func(t *testing.T) {
			taken, release := make(chan struct{}), make(chan struct{})
			f := fake(user("id2"), echo("id2"), signal(taken), claudetest.Until(release),
				canUseTool("toolu_1", tc.tool, tc.input, ""),
				answers("toolu_1", `{"behavior":"deny","message":"The user cancelled this prompt.","interrupt":true}`),
				claudetest.Send(idle))
			p := start(t, &acp.ClientCapabilities{Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}}}, f)
			var asked atomic.Bool
			p.permit = func(ctx context.Context, req *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
				asked.Store(true)
				return pick(optAllowOnce)(ctx, req)
			}
			p.elicit = func(context.Context, *acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
				asked.Store(true)
				return &acp.CreateElicitationResponse{Decline: true}, nil
			}
			sid := p.open(t)
			w := p.prompt(t, sid, "go")
			wait(t, taken, "the prompt taken")
			eventually(t, "the prompt running", func() bool { _, a := p.queue(t, sid); return a == "id2" })
			if err := p.Cancel(t.Context(), &acp.CancelNotification{SessionID: sid}); err != nil {
				t.Fatal(err)
			}
			s, _ := p.agent.session(sid)
			eventually(t, "the cancel taken", func() bool {
				s.mu.Lock()
				defer s.mu.Unlock()
				return s.dropTop
			})
			close(release)
			if got := stopReason(w); got != "cancelled" {
				t.Error(got)
			}
			if asked.Load() {
				t.Error("the client was asked")
			}
		})
	}
}

// A subagent's call that a permission request shows before its stream
// does isn't one the turn leaves open: it outlives the turn's result, and
// its stream then says whose it is.
func TestSubagentPermission(t *testing.T) {
	f := fake(user("id2"), echo("id2"), canUseTool("toolu_s", "Bash", `{"command":"ls"}`, `,"agent_id":"a1"`),
		answers("toolu_s", `{"behavior":"allow"}`), result(names("id2")), claudetest.Send(idle),
		claudetest.Send(`{"type":"assistant","parent_tool_use_id":"toolu_p","message":{"id":"msg_2","content":[{"type":"tool_use","id":"toolu_s","name":"Bash","input":{"command":"ls"}}]}}`),
		sendf(`{"type":"user","parent_tool_use_id":"toolu_p","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_s","content":"a"}]}}`))
	p := start(t, nil, f)
	p.permit = pick(optAllowOnce)
	if got := stopReason(p.prompt(t, p.open(t), "go")); got != "end_turn" {
		t.Fatal(got)
	}
	<-f.Played()
	eventually(t, "the call's result", func() bool { return len(p.toolUpdates()) == 2 })
	if got := p.toolUpdates()[1]; !strings.Contains(got, `"status":"completed"`) || !strings.Contains(got, `"parentToolUseId":"toolu_p"`) {
		t.Errorf("%s", got)
	}
}
