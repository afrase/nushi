package claudemcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/procgroup"
)

// A user, local, plugin or claude.ai server is turned off per project by
// Claude's /mcp, which records it in the project's entry of ~/.claude.json
// ("disabledMcpServers"); `claude mcp` has no command for it (Claude Code
// 2.1.310). Nushi never writes that file (ADR 0021): it asks Claude to,
// through the Agent SDK's control request for it (mcp_toggle, what the
// SDK's toggleMcpServer and the adapter's `/mcp disable` send), to a
// `claude -p --bare` run in the folder for that alone (ADR 0050). --bare
// runs none of the folder's hooks, helpers or MCP servers and reads no
// keychain; it knows user and local servers, not plugins' or claude.ai's.

// toggleArgs are the arguments of the claude run that toggles a server.
var toggleArgs = []string{"-p", "--bare", "--no-session-persistence",
	"--input-format", "stream-json", "--output-format", "stream-json", "--verbose"}

// Toggle turns a user or local server on or off for folder's project, as
// /mcp in a terminal does. Turning one on has Claude connect to it once
// (its error, if that fails, doesn't undo the change). Whether it took is
// read back from Claude's config.
func (Claude) Toggle(ctx context.Context, folder, name string, on bool) error {
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "claude", toggleArgs...)
	cmd.Dir = folder
	procgroup.Bound(cmd)
	type request struct {
		Type    string         `json:"type"`
		ID      string         `json:"request_id"`
		Request map[string]any `json:"request"`
	}
	var in []byte
	for _, req := range []request{ // initialize first, as the SDK does
		{"control_request", "init", map[string]any{"subtype": "initialize"}},
		{"control_request", "toggle", map[string]any{"subtype": "mcp_toggle", "serverName": name, "enabled": on}},
	} {
		line, err := json.Marshal(req)
		if err != nil {
			return err
		}
		in = append(append(in, line...), '\n')
	}
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("running claude: %w", err)
	}
	go func() {
		_, _ = stdin.Write(in) // Claude answers both, then ends at the end of its input
		_ = stdin.Close()
	}()
	said := answer(stdout, "toggle")
	_, _ = io.Copy(io.Discard, stdout)
	waitErr := cmd.Wait()
	if disabled, err := projectDisabled(folder); err == nil && slices.Contains(disabled, name) != on {
		return nil
	}
	switch {
	case said != "":
		return errors.New(said) // Claude's words: "Server not found: x"
	case waitErr != nil:
		return fmt.Errorf("claude: %w", waitErr)
	}
	return fmt.Errorf("claude didn't turn %s %s", name, map[bool]string{true: "on", false: "off"}[on])
}

// answer reads Claude's messages until its answer to the request id: ""
// for a success, else its error (or why there was none).
func answer(r io.Reader, id string) string {
	dec := json.NewDecoder(r)
	for {
		var msg struct {
			Type     string `json:"type"`
			Response struct {
				Subtype string `json:"subtype"`
				ID      string `json:"request_id"`
				Error   string `json:"error"`
			} `json:"response"`
		}
		if err := dec.Decode(&msg); err != nil {
			return "Claude ended without answering"
		}
		if msg.Type != "control_response" || msg.Response.ID != id {
			continue
		}
		if msg.Response.Subtype == "success" {
			return ""
		}
		if msg.Response.Error == "" {
			return "Claude refused"
		}
		return msg.Response.Error
	}
}

// projectDisabled is the servers /mcp turned off for folder's project.
func projectDisabled(folder string) ([]string, error) {
	var cfg struct {
		Projects map[string]struct {
			Disabled names `json:"disabledMcpServers"`
		} `json:"projects"`
	}
	err := readJSON(claude.ConfigFile(), &cfg)
	return cfg.Projects[Project(folder)].Disabled, err
}
