package claudeagent

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestArgs(t *testing.T) {
	core := []string{"--output-format", "stream-json", "--verbose", "--input-format", "stream-json"}
	value := func(s string) *string { return &s }
	allow := func(context.Context, PermissionRequest) (PermissionResult, error) { return Allow{}, nil }
	for _, tc := range []struct {
		name string
		o    Options
		want []string
	}{
		{"zero", Options{}, nil},
		{"permission prompts", Options{CanUseTool: allow}, []string{"--permission-prompt-tool=stdio"}},
		{
			"values in the equals form",
			Options{Model: "-opus", FallbackModel: "sonnet", Effort: "high", PermissionMode: PermissionDefault, Resume: "-r", SessionID: "s1",
				ForkSession: true, ResumeSessionAt: "u1", MaxTurns: 3},
			[]string{"--model=-opus", "--fallback-model=sonnet", "--effort=high", "--permission-mode=default", "--resume=-r",
				"--session-id=s1", "--fork-session", "--resume-session-at=u1", "--max-turns=3"},
		},
		{
			"lists",
			Options{SettingSources: []string{"user", "project", "local"}, AddDirs: []string{"/a", "-b"},
				AllowedTools: []string{"Read", "Bash(git:*)"}, DisallowedTools: []string{"AskUserQuestion"}, Tools: []string{"Read"}},
			[]string{"--setting-sources=user,project,local", "--add-dir=/a", "--add-dir=-b", "--allowedTools=Read,Bash(git:*)",
				"--disallowedTools=AskUserQuestion", "--tools=Read"},
		},
		{"empty lists that mean none", Options{SettingSources: []string{}, Tools: []string{}}, []string{"--setting-sources=", "--tools="}},
		{
			"JSON in an argument of its own",
			Options{Settings: json.RawMessage(`{"ultracode":true}`), MCPServers: map[string]MCPServer{
				"web":   {Type: "http", URL: "https://x", Headers: map[string]string{"A": "b"}},
				"tools": {Type: "stdio", Command: "/bin/t", Args: []string{"-x"}, Env: map[string]string{"K": "v"}},
			}},
			[]string{"--settings", `{"ultracode":true}`, "--mcp-config",
				`{"mcpServers":{"tools":{"type":"stdio","command":"/bin/t","args":["-x"],"env":{"K":"v"}},"web":{"type":"http","url":"https://x","headers":{"A":"b"}}}}`},
		},
		{"thinking adaptive", Options{Thinking: &Thinking{Type: "adaptive", Display: "summarized"}}, []string{"--thinking=adaptive", "--thinking-display=summarized"}},
		{"thinking with a budget", Options{Thinking: &Thinking{Type: "enabled", BudgetTokens: 4000}}, []string{"--max-thinking-tokens=4000"}},
		{"thinking enabled, no budget", Options{Thinking: &Thinking{Type: "enabled"}}, []string{"--thinking=adaptive"}},
		{"thinking off", Options{Thinking: &Thinking{Type: "disabled", Display: "omitted"}}, []string{"--thinking=disabled"}},
		{
			"switches",
			Options{AllowBypass: true, IncludePartialMessages: true, ReplayUserMessages: true},
			[]string{"--allow-dangerously-skip-permissions", "--include-partial-messages", "--replay-user-messages"},
		},
		{
			"extra args, sorted",
			Options{ExtraArgs: map[string]*string{"strict-mcp-config": nil, "agent": value("-reviewer")}},
			[]string{"--agent=-reviewer", "--strict-mcp-config"},
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got, err := args(tc.o)
			if err != nil {
				t.Fatal(err)
			}
			if want := append(slices.Clone(core), tc.want...); !slices.Equal(got, want) {
				t.Errorf("args:\n got %q\nwant %q", got, want)
			}
			if slices.Contains(got, "-p") || slices.Contains(got, "--print") || slices.Contains(got, "--bare") {
				t.Errorf("print mode or bare asked for: %q", got)
			}
		})
	}
}

func TestArgsRefused(t *testing.T) {
	for _, o := range []Options{
		{Model: "opus", FallbackModel: "opus"},
		{ExtraArgs: map[string]*string{"bare": nil}},
		{ExtraArgs: map[string]*string{"p": nil}},
		{ExtraArgs: map[string]*string{"output-format": nil}},
		{ExtraArgs: map[string]*string{"--model": nil}},
		{ExtraArgs: map[string]*string{"a=b": nil}},
		{ExtraArgs: map[string]*string{"": nil}},
	} {
		if a, err := args(o); err == nil {
			t.Errorf("%+v: %q, no error", o, a)
		}
	}
}

func TestEnviron(t *testing.T) {
	base := []string{
		"PATH=/bin", "CLAUDECODE=1", "NODE_OPTIONS=--x", "CLAUDE_AGENT_SDK_VERSION=0.3.303",
		"CLAUDE_CODE_SDK_HAS_OAUTH_REFRESH=1", "CLAUDE_CODE_SDK_HAS_HOST_AUTH_REFRESH=1",
		"CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS=0", "PWD=/old", "HOME=/h",
	}
	for _, tc := range []struct {
		name string
		o    Options
		want []string
	}{
		{
			"defaults",
			Options{Env: base},
			[]string{"PATH=/bin", "PWD=/old", "HOME=/h", "CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS=1",
				"CLAUDE_AGENT_SDK_CLIENT_APP=claudeagent-go/" + Version, "CLAUDE_CODE_ENTRYPOINT=sdk-cli"},
		},
		{
			"the app, the folder",
			Options{Env: base, ClientApp: "nushi/0.9", Cwd: "/w"},
			[]string{"PATH=/bin", "HOME=/h", "CLAUDE_AGENT_SDK_CLIENT_APP=nushi/0.9", "CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS=1",
				"PWD=/w", "CLAUDE_CODE_ENTRYPOINT=sdk-cli"},
		},
		{
			"the caller's entrypoint and app are kept",
			Options{Env: []string{"CLAUDE_CODE_ENTRYPOINT=x", "CLAUDE_AGENT_SDK_CLIENT_APP=y/1"}},
			[]string{"CLAUDE_CODE_ENTRYPOINT=x", "CLAUDE_AGENT_SDK_CLIENT_APP=y/1", "CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS=1"},
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := environ(tc.o); !slices.Equal(got, tc.want) {
				t.Errorf("environ:\n got %q\nwant %q", got, tc.want)
			}
		})
	}
}

// With no Env, claude gets this process's environment, edited.
func TestEnvironInherits(t *testing.T) {
	t.Setenv("CLAUDECODE", "1")
	t.Setenv("CLAUDEAGENT_TEST_MARK", "x")
	env := environ(Options{})
	if !slices.Contains(env, "CLAUDEAGENT_TEST_MARK=x") || slices.ContainsFunc(env, func(kv string) bool { return strings.HasPrefix(kv, "CLAUDECODE=") }) {
		t.Errorf("%q", env)
	}
}

// claude is looked up on the PATH claude will have, not this process's.
func TestSpecFindsClaude(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, "bin")
	if err := os.Mkdir(bin, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "claude"), nil, 0o600); err != nil { // not executable
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(bin, "claude"), nil, 0o700); err != nil {
		t.Fatal(err)
	}
	s, err := spec(Options{Env: []string{"PATH=relative:" + dir + ":" + bin}, Cwd: "/w"})
	if err != nil {
		t.Fatal(err)
	}
	if s.Path != filepath.Join(bin, "claude") || s.Dir != "/w" || s.Args[0] != "--output-format" {
		t.Errorf("%+v", s)
	}
	if _, err := spec(Options{Env: []string{"PATH=" + dir}}); err == nil {
		t.Error("found a claude that can't run")
	}
	if s, err := spec(Options{CLIPath: "/opt/claude", Env: []string{}}); err != nil || s.Path != "/opt/claude" {
		t.Errorf("%+v %v", s, err)
	}
}
