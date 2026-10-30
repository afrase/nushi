package claudeacp

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/claudeagent"
)

// rules is an addRules update allowing each rule ("Tool" or
// "Tool(content)") at dest.
func rules(dest claudeagent.PermissionDestination, rs ...string) claudeagent.PermissionUpdate {
	u := claudeagent.PermissionUpdate{Type: "addRules", Behavior: "allow", Destination: dest}
	for _, r := range rs {
		tool, content, _ := strings.Cut(strings.TrimSuffix(r, ")"), "(")
		u.Rules = append(u.Rules, claudeagent.PermissionRule{ToolName: tool, RuleContent: content})
	}
	return u
}

func dirs(ds ...string) claudeagent.PermissionUpdate {
	return claudeagent.PermissionUpdate{Type: "addDirectories", Destination: "session", Directories: ds}
}

var acceptEdits = claudeagent.PermissionUpdate{Type: "setMode", Mode: "acceptEdits", Destination: "session"}

// Each tool's "don't ask again", worded as claude's terminal words it,
// and the rules it gives claude: claude's suggestions where the words can
// say what they do, else rules of its own for the tool. None when a rule
// of the user's asks each time, or the rules would change the mode.
func TestAlwaysOptions(t *testing.T) {
	const cwd = "/w/proj"
	home, _ := os.UserHomeDir()
	for _, tc := range []struct {
		name  string
		r     claudeagent.PermissionRequest
		want  string // each option as id: name; "" for none
		rules string // the first option's updates, as JSON, when not claude's suggestions
	}{
		{"command", claudeagent.PermissionRequest{ToolName: "Bash", Input: json.RawMessage(`{"command":"perl -e 1"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", `Bash(perl -e 'print "c"')`)}},
			`allow-always: Yes, and don't ask again for perl -e 'print "c"' commands`, ""},
		{"command prefixes", claudeagent.PermissionRequest{ToolName: "Bash",
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "Bash(npm test:*)", "Bash(npm run:*)", "Bash(git log:*)")}},
			"allow-always: Yes, and don't ask again for npm test, npm run, and git log commands", ""},
		{"command too long to list", claudeagent.PermissionRequest{ToolName: "PowerShell",
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "PowerShell(Get-ChildItem -Recurse:*)", "PowerShell(Get-Content -Path something:*)")}},
			"allow-always: Yes, and don't ask again for similar commands", ""},
		{"command with a folder", claudeagent.PermissionRequest{ToolName: "Bash",
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "Bash(ls:*)"), dirs("/x/data")}},
			"allow-always: Yes, and allow access to data/ and ls commands", ""},
		{"folders only", claudeagent.PermissionRequest{ToolName: "Bash",
			Suggestions: []claudeagent.PermissionUpdate{dirs("/a/src", "/b/src", "/c/lib")}},
			"allow-always: Yes, and always allow access to a/src/, b/src/ and 1 more from this project", ""},
		{"reads only", claudeagent.PermissionRequest{ToolName: "Bash",
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Read(/x/logs/**)")}},
			"allow-always: Yes, allow reading from logs/ from this project", ""},
		{"command changing the mode", claudeagent.PermissionRequest{ToolName: "Bash",
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "Bash(mkdir -v d)"), dirs("/x"), acceptEdits}}, "", ""},
		{"command, any use", claudeagent.PermissionRequest{ToolName: "Bash",
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "Bash")}}, "", ""},
		{"command reaching a folder for good", claudeagent.PermissionRequest{ToolName: "Bash",
			Suggestions: []claudeagent.PermissionUpdate{{Type: "addDirectories", Destination: "localSettings", Directories: []string{"/x"}}}}, "", ""},
		{"a rule of the user's asks", claudeagent.PermissionRequest{ToolName: "Bash", MatchedAskRule: true,
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "Bash(ls)")}}, "", ""},
		{"always allowing suppressed", claudeagent.PermissionRequest{ToolName: "WebSearch", SuppressAlwaysAllowRule: true}, "", ""},
		{"read in the folder", claudeagent.PermissionRequest{ToolName: "Read", Input: json.RawMessage(`{"file_path":"/w/proj/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Read(/w/proj/**)")}},
			"allow-always: Yes, during this session", ""},
		{"read outside", claudeagent.PermissionRequest{ToolName: "Read", Input: json.RawMessage(`{"file_path":"/etc/hosts"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Read(/etc/**)")}},
			"allow-always: Yes, allow reading from etc/ during this session", ""},
		{"read not covered", claudeagent.PermissionRequest{ToolName: "Read", Input: json.RawMessage(`{"file_path":"/etc/hosts"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Read(/var/**)")}}, "", ""},
		{"grep in the folder", claudeagent.PermissionRequest{ToolName: "Grep", Input: json.RawMessage(`{"pattern":"x"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Read")}},
			"allow-always: Yes, during this session", ""},
		{"glob outside", claudeagent.PermissionRequest{ToolName: "Glob", Input: json.RawMessage(`{"path":"/srv/www"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Read(/srv/**)")}},
			"allow-always: Yes, allow reading from srv/ during this session", ""},
		// The words never say less than the rules allow.
		{"read anywhere, outside", claudeagent.PermissionRequest{ToolName: "Read", Input: json.RawMessage(`{"file_path":"/etc/hosts"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Read")}}, "", ""},
		{"edit in an ancestor", claudeagent.PermissionRequest{ToolName: "Edit", Input: json.RawMessage(`{"file_path":"/x/lib/deep/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit(/x/**)")}},
			"allow-always: Yes, allow all edits in x/ during this session", ""},
		{"edit in the exact folder", claudeagent.PermissionRequest{ToolName: "Edit", Input: json.RawMessage(`{"file_path":"/x/lib/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit(/x/lib/**)"), dirs("/x/lib")}},
			"allow-always: Yes, allow all edits in lib/ during this session", ""},
		{"edit in two folders", claudeagent.PermissionRequest{ToolName: "Edit", Input: json.RawMessage(`{"file_path":"/x/lib/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit(/x/lib/**)", "Edit(/y/**)")}}, "", ""},
		{"edit adding another folder", claudeagent.PermissionRequest{ToolName: "Edit", Input: json.RawMessage(`{"file_path":"/x/lib/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit(/x/lib/**)"), dirs("/y")}}, "", ""},
		{"edit of one file", claudeagent.PermissionRequest{ToolName: "Edit", Input: json.RawMessage(`{"file_path":"/x/lib/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit(/x/lib/a.go)")}}, "", ""},
		{"edit with a folder added only", claudeagent.PermissionRequest{ToolName: "Edit", Input: json.RawMessage(`{"file_path":"/x/lib/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{dirs("/x/lib")}}, "", ""},
		{"claude's settings, the whole folder allowed", claudeagent.PermissionRequest{ToolName: "Edit", Input: json.RawMessage(`{"file_path":"/w/proj/.claude/settings.json"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit(/w/proj/**)")}},
			"allow-always: Yes, allow all edits during this session", ""},
		{"edit outside", claudeagent.PermissionRequest{ToolName: "Edit", Input: json.RawMessage(`{"file_path":"/x/lib/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit(/x/lib/**)")}},
			"allow-always: Yes, allow all edits in lib/ during this session", ""},
		{"write in the folder", claudeagent.PermissionRequest{ToolName: "Write", Input: json.RawMessage(`{"file_path":"/w/proj/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit")}},
			"allow-always: Yes, allow all edits during this session", ""},
		{"write's mode change", claudeagent.PermissionRequest{ToolName: "Write", Input: json.RawMessage(`{"file_path":"/x/a.go"}`),
			Suggestions: []claudeagent.PermissionUpdate{dirs("/x"), acceptEdits}}, "", ""},
		{"claude's own settings", claudeagent.PermissionRequest{ToolName: "Edit", Input: json.RawMessage(`{"file_path":"/w/proj/.claude/settings.json"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit(/w/proj/.claude/**)")}},
			"allow-always: Yes, and allow Claude to edit its own settings for this session", ""},
		{"notebook kept for good", claudeagent.PermissionRequest{ToolName: "NotebookEdit", Input: json.RawMessage(`{"notebook_path":"/w/proj/n.ipynb"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "Edit")}}, "", ""},
		{"fetch", claudeagent.PermissionRequest{ToolName: "WebFetch", Input: json.RawMessage(`{"url":"https://Docs.Example.com/a?b"}`)},
			"allow-always: Yes, and don't ask again for docs.example.com",
			`[{"type":"addRules","rules":[{"toolName":"WebFetch","ruleContent":"domain:docs.example.com"}],"behavior":"allow","destination":"localSettings"}]`},
		{"fetch without a host", claudeagent.PermissionRequest{ToolName: "WebFetch", Input: json.RawMessage(`{"url":"example.com/a"}`)}, "", ""},
		{"skill", claudeagent.PermissionRequest{ToolName: "Skill", Input: json.RawMessage(`{"skill":"pdf extract"}`)},
			"allow-skill-exact: Yes, and don't ask again for pdf extract; allow-skill-prefix: Yes, and don't ask again for pdf:* commands",
			`[{"type":"addRules","rules":[{"toolName":"Skill","ruleContent":"pdf extract"}],"behavior":"allow","destination":"localSettings"}]`},
		{"network", claudeagent.PermissionRequest{ToolName: "SandboxNetworkAccess", Input: json.RawMessage(`{"host":"pypi.org"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "SandboxNetworkAccess(pypi.org)")}},
			"allow-always: Yes, and don't ask again for pypi.org", ""},
		{"MCP tool", claudeagent.PermissionRequest{ToolName: "mcp__echo__echo", DisplayName: "Echo",
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "mcp__echo__echo")}},
			"allow-always: Yes, and don't ask again for Echo commands", ""},
		{"MCP tool, other rules", claudeagent.PermissionRequest{ToolName: "mcp__echo__echo",
			Suggestions: []claudeagent.PermissionUpdate{rules("localSettings", "mcp__echo__other")}}, "", ""},
		{"computer use", claudeagent.PermissionRequest{ToolName: "mcp__computer-use__click",
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "mcp__computer-use__click")}},
			"allow-always: Yes, and don't ask again for mcp__computer-use__click", ""},
		{"any other tool", claudeagent.PermissionRequest{ToolName: "Agent"},
			"allow-always: Yes, and don't ask again for Agent commands",
			`[{"type":"addRules","rules":[{"toolName":"Agent"}],"behavior":"allow","destination":"localSettings"}]`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			offered := alwaysOptions(tc.r, cwd)
			var got []string
			for _, a := range offered {
				got = append(got, a.id+": "+a.name)
			}
			if strings.Join(got, "; ") != tc.want {
				t.Errorf("got %q\nwant %q", strings.Join(got, "; "), tc.want)
			}
			if len(offered) == 0 {
				return
			}
			want := tc.rules
			if want == "" {
				b, _ := json.Marshal(tc.r.Suggestions)
				want = string(b)
			}
			if b, _ := json.Marshal(offered[0].updates); string(b) != want {
				t.Errorf("rules %s\nwant %s", b, want)
			}
		})
	}
	if home != "" {
		r := claudeagent.PermissionRequest{ToolName: "Write", Input: json.RawMessage(`{"file_path":"` + filepath.Join(home, ".claude", "x.md") + `"}`),
			Suggestions: []claudeagent.PermissionUpdate{rules("session", "Edit("+filepath.Join(home, ".claude")+"/**)")}}
		if got := alwaysOptions(r, cwd); len(got) != 1 || got[0].name != "Yes, and allow Claude to edit its own settings for this session" {
			t.Errorf("home's .claude: %+v", got)
		}
	}
}
