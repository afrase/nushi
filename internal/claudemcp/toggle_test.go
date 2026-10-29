package claudemcp

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// fakeClaude puts a claude first on PATH that records its arguments and
// input in dir, writes $FAKE_CONFIG as Claude's config when it is set,
// and answers the toggle with $FAKE_ANSWER.
func fakeClaude(t *testing.T) (dir string) {
	t.Helper()
	dir = t.TempDir()
	script := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"" + dir + "/args\"\ncat > \"" + dir + "/stdin\"\n" +
		"[ -n \"$FAKE_CONFIG\" ] && printf '%s' \"$FAKE_CONFIG\" > \"$CLAUDE_CONFIG_DIR/.claude.json\"\n" +
		"echo '{\"type\":\"control_response\",\"response\":{\"subtype\":\"success\",\"request_id\":\"init\",\"response\":{}}}'\n" +
		"echo \"$FAKE_ANSWER\"\n"
	testcheck.Write(t, filepath.Join(dir, "claude"), script)
	if err := os.Chmod(filepath.Join(dir, "claude"), 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+":"+os.Getenv("PATH"))
	return dir
}

func TestToggleAsksClaudeAndReadsItBack(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	folder, _ := filepath.EvalSymlinks(t.TempDir())
	dir := fakeClaude(t)
	testcheck.Write(t, filepath.Join(cfg, ".claude.json"), `{"mcpServers":{"web":{"command":"w"}},"projects":{"`+folder+`":{"mcpServers":{"loc":{"command":"l"}}}}}`)
	off := `{"mcpServers":{"web":{"command":"w"}},"projects":{"` + folder + `":{"mcpServers":{"loc":{"command":"l"}},"disabledMcpServers":["web"],"x":1}}}`
	t.Setenv("FAKE_CONFIG", off)
	t.Setenv("FAKE_ANSWER", `{"type":"control_response","response":{"subtype":"success","request_id":"toggle"}}`)
	ctx := context.Background()
	if err := (Claude{}).SetOn(ctx, folder, "user", "web", false); err != nil {
		t.Fatal(err)
	}
	args, _ := os.ReadFile(filepath.Join(dir, "args"))
	if got := strings.Fields(string(args)); !slices.Equal(got, toggleArgs) {
		t.Errorf("args = %q", got)
	}
	in, _ := os.ReadFile(filepath.Join(dir, "stdin"))
	lines := strings.Split(strings.TrimSpace(string(in)), "\n")
	var toggle struct {
		Type    string `json:"type"`
		ID      string `json:"request_id"`
		Request struct {
			Subtype, ServerName string
			Enabled             bool
		} `json:"request"`
	}
	if len(lines) != 2 || !strings.Contains(lines[0], `"initialize"`) || json.Unmarshal([]byte(lines[1]), &toggle) != nil ||
		toggle.Type != "control_request" || toggle.ID != "toggle" || toggle.Request.Subtype != "mcp_toggle" ||
		toggle.Request.ServerName != "web" || toggle.Request.Enabled {
		t.Errorf("input:\n%s", in)
	}
	servers, _ := Claude{}.Servers(folder)
	if len(servers) != 2 || !servers[0].Off || servers[0].OffBy != "" || servers[1].Off {
		t.Errorf("after turning web off: %+v", servers)
	}

	// Turning on: Claude's error connecting to it doesn't undo the change.
	t.Setenv("FAKE_CONFIG", strings.Replace(off, `["web"]`, `[]`, 1))
	t.Setenv("FAKE_ANSWER", `{"type":"control_response","response":{"subtype":"error","request_id":"toggle","error":"Method not found"}}`)
	if err := (Claude{}).SetOn(ctx, folder, "user", "web", true); err != nil {
		t.Errorf("turned on, but: %v", err)
	}
	// A change Claude refused (the config unchanged) is Claude's error.
	t.Setenv("FAKE_CONFIG", "")
	t.Setenv("FAKE_ANSWER", `{"type":"control_response","response":{"subtype":"error","request_id":"toggle","error":"Server not found: nope"}}`)
	if err := (Claude{}).SetOn(ctx, folder, "local", "nope", false); err == nil || err.Error() != "Server not found: nope" {
		t.Errorf("refused: %v", err)
	}
	t.Setenv("FAKE_ANSWER", "not json")
	if err := (Claude{}).SetOn(ctx, folder, "local", "loc", false); err == nil {
		t.Error("no answer: no error")
	}
}
