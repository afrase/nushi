package claude

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"reflect"
	"testing"

	"github.com/afrase/claude-acp-go/claudeacp"

	"github.com/afrase/nushi/internal/model"
)

// answering is an agent's call that answers claudeacp.ContextUsageMethod
// with answer, for session s1 asked in full.
func answering(t *testing.T, answer json.RawMessage) func(context.Context, string, any, any) error {
	t.Helper()
	return func(_ context.Context, method string, params, result any) error {
		want := claudeacp.ContextUsageRequest{SessionID: "s1", Detail: "full"}
		if method != claudeacp.ContextUsageMethod || params != want {
			t.Errorf("call(%q, %+v); want %q, %+v", method, params, claudeacp.ContextUsageMethod, want)
		}
		return json.Unmarshal(answer, result)
	}
}

// Claude's own answers to get_context_usage (the context-usage scenario's,
// Claude Code 2.1.331: the first session after a prompt, then a second
// session once a CLAUDE.md and an agent were written; gridRows cut and the
// run's folder written /tmp/claude/work) read as the card read the
// /context markdown of the same kind of session (the context scenario's):
// claude's categories in its order, the deferred tools by kind, the
// conversation by id, the buffer by kind, each a share of the window, and
// the lists /context put under them, each with rows.
func TestContextFromTheRecording(t *testing.T) {
	data, err := os.ReadFile("testdata/context-usage.json")
	if err != nil {
		t.Fatal(err)
	}
	var answers []json.RawMessage
	if err := json.Unmarshal(data, &answers); err != nil || len(answers) != 2 {
		t.Fatalf("%d answers, %v", len(answers), err)
	}
	skills := model.ContextList{Name: "Skills", Rows: []model.ContextRow{{Name: "dataviz", Tokens: 482}, {Name: "update-config", Tokens: 236},
		{Name: "keybindings-help", Tokens: 83}, {Name: "code-review", Tokens: 283}, {Name: "simplify", Tokens: 63}, {Name: "fewer-permission-prompts", Tokens: 64},
		{Name: "loop", Tokens: 115}, {Name: "claude-api", Tokens: 390}, {Name: "workflow-authoring", Tokens: 84}, {Name: "run", Tokens: 123},
		{Name: "plugin-authoring", Tokens: 92}, {Name: "init", Tokens: 22}, {Name: "security-review", Tokens: 30}}}
	for i, tc := range []struct {
		name string
		want model.ContextUsage
	}{
		{"after a prompt", model.ContextUsage{
			Categories: []model.ContextCategory{{Name: "System prompt", Tokens: 1997, Percent: 0.1997}, {Name: "System tools", Tokens: 6832, Percent: 0.6832},
				{Name: "System tools", Tokens: 5371, Percent: 0.5371, Kind: "deferred"}, {Name: "Skills", Tokens: 2067, Percent: 0.2067},
				{Name: "Messages", Tokens: 2736, Percent: 0.2736, Part: model.PartMessages}, {Name: "Autocompact buffer", Tokens: 33000, Percent: 3.3, Part: model.PartBuffer},
				{Name: "Free space", Tokens: 953368, Percent: 95.3368, Kind: "free"}},
			Lists: []model.ContextList{{Name: "MCP tools", Rows: []model.ContextRow{{Name: "mcp__echo__echo"}}}, skills},
		}},
		{"with a CLAUDE.md and an agent", model.ContextUsage{
			Categories: []model.ContextCategory{{Name: "System prompt", Tokens: 1997, Percent: 0.1997}, {Name: "System tools", Tokens: 6677, Percent: 0.6677},
				{Name: "System tools", Tokens: 5371, Percent: 0.5371, Kind: "deferred"}, {Name: "Custom agents", Tokens: 27, Percent: 0.0027},
				{Name: "Memory files", Tokens: 28, Percent: 0.0028}, {Name: "Skills", Tokens: 2067, Percent: 0.2067},
				{Name: "Messages", Tokens: 20, Percent: 0.002, Part: model.PartMessages}, {Name: "Autocompact buffer", Tokens: 33000, Percent: 3.3, Part: model.PartBuffer},
				{Name: "Free space", Tokens: 956184, Percent: 95.6184, Kind: "free"}},
			Lists: []model.ContextList{{Name: "Custom agents", Rows: []model.ContextRow{{Name: "helper", Tokens: 27}}},
				{Name: "Memory files", Rows: []model.ContextRow{{Name: "/tmp/claude/work/CLAUDE.md", Tokens: 28}}}, skills},
		}},
	} {
		got, err := Harness{}.Context(context.Background(), answering(t, answers[i]), "s1")
		if err != nil {
			t.Fatalf("%s: %v", tc.name, err)
		}
		for j := range got.Categories { // shares to a millionth of the window
			got.Categories[j].Percent = float64(int64(got.Categories[j].Percent*1e4+0.5)) / 1e4
		}
		if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("%s: Context =\n%+v\nwant\n%+v", tc.name, got, tc.want)
		}
	}
}

// The lists are claude's own, undocumented: one it drops or retypes is
// left out, and the rest of the answer stands.
func TestContextSkipsAListItCantRead(t *testing.T) {
	answer := json.RawMessage(`{"categories":[{"id":"messages","name":"Messages","tokens":500,"kind":"used"}],"maxTokens":1000,
		"memoryFiles":{"path":"CLAUDE.md"},"agents":[{"agentType":7}],"skills":{"skillFrontmatter":"none"},
		"mcpTools":[{"name":"mcp__x__y","tokens":12}]}`)
	got, err := Harness{}.Context(context.Background(), answering(t, answer), "s1")
	want := model.ContextUsage{Categories: []model.ContextCategory{{Name: "Messages", Tokens: 500, Percent: 50, Part: model.PartMessages}},
		Lists: []model.ContextList{{Name: "MCP tools", Rows: []model.ContextRow{{Name: "mcp__x__y", Tokens: 12}}}}}
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Errorf("Context = %+v, %v; want %+v", got, err, want)
	}
	failing := func(context.Context, string, any, any) error { return errors.New("gone") }
	if _, err := (Harness{}).Context(context.Background(), failing, "s1"); err == nil {
		t.Error("a failed call answered")
	}
}

// Only the categories and the window are read: a field Nushi doesn't read
// that claude retypes can't fail the card.
func TestContextIgnoresAFieldItDoesntRead(t *testing.T) {
	answer := json.RawMessage(`{"categories":[{"id":"messages","name":"Messages","tokens":500,"kind":"used"}],"maxTokens":1000,
		"model":{"id":"opus"},"totalTokens":"many","rawMaxTokens":null,"percentage":"half"}`)
	got, err := Harness{}.Context(context.Background(), answering(t, answer), "s1")
	want := model.ContextUsage{Categories: []model.ContextCategory{{Name: "Messages", Tokens: 500, Percent: 50, Part: model.PartMessages}}}
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Errorf("Context = %+v, %v; want %+v", got, err, want)
	}
}
