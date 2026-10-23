// Package claudemcp reads the MCP servers Claude Code uses in a folder, and
// asks Claude how they are. Claude's own files are the source of truth and
// are only read here (Claude Code 2.1.309; see ADR 0021):
//   - user scope: "mcpServers" in ~/.claude.json ($CLAUDE_CONFIG_DIR/.claude.json);
//   - local scope: "projects"[<project>]."mcpServers" in the same file, where
//     the project is the folder's repository (its main checkout, for a
//     worktree), or the folder itself outside git;
//   - project scope: .mcp.json in the folder or any folder above it, the
//     nearest winning;
//   - plugins' servers and claude.ai connectors: only what `claude mcp list`
//     reports.
package claudemcp

import (
	"cmp"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Mask stands in for env and header values, which never leave the daemon.
const Mask = "••••"

// Claude reads Claude Code's MCP config.
type Claude struct{}

// configFile is Claude's own config file, which holds user and local
// servers.
func configFile() string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return filepath.Join(dir, ".claude.json")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude.json")
}

// project is the folder Claude files a folder's local servers under: its
// repository's main checkout, or the folder outside git (real paths).
func project(folder string) string {
	if real, err := filepath.EvalSymlinks(folder); err == nil {
		folder = real
	}
	out, err := exec.Command("git", "-C", folder, "rev-parse", "--path-format=absolute", "--git-common-dir").Output()
	if common := strings.TrimSpace(string(out)); err == nil && filepath.Base(common) == ".git" {
		return filepath.Dir(common)
	}
	return folder
}

type servers map[string]json.RawMessage

// Servers returns the servers Claude's files give folder: user, local and
// project scope, each sorted by name.
func (Claude) Servers(folder string) ([]model.MCPServer, error) {
	var cfg struct {
		MCPServers servers `json:"mcpServers"`
		Projects   map[string]struct {
			MCPServers servers `json:"mcpServers"`
		} `json:"projects"`
	}
	file := configFile()
	if err := readJSON(file, &cfg); err != nil {
		return nil, err
	}
	out := add(nil, cfg.MCPServers, "user", file)
	key := project(folder)
	out = add(out, cfg.Projects[key].MCPServers, "local", key)
	seen := map[string]bool{}
	for dir := folder; ; dir = filepath.Dir(dir) {
		path := filepath.Join(dir, ".mcp.json")
		var mcp struct {
			MCPServers servers `json:"mcpServers"`
		}
		if err := readJSON(path, &mcp); err != nil {
			return nil, err
		}
		for name := range mcp.MCPServers {
			if seen[name] {
				delete(mcp.MCPServers, name) // a nearer .mcp.json has it
			}
			seen[name] = true
		}
		out = add(out, mcp.MCPServers, "project", path)
		if dir == filepath.Dir(dir) {
			return out, nil
		}
	}
}

// readJSON reads a JSON file into v; a missing file leaves v as it is.
func readJSON(path string, v any) error {
	b, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err == nil {
		err = json.Unmarshal(b, v)
	}
	if err != nil {
		return fmt.Errorf("reading %s: %w", path, err)
	}
	return nil
}

func add(out []model.MCPServer, s servers, scope, source string) []model.MCPServer {
	start := len(out)
	for name, raw := range s {
		out = append(out, model.MCPServer{Name: name, Scope: scope, Source: source, Config: masked(raw)})
	}
	slices.SortFunc(out[start:], func(a, b model.MCPServer) int { return cmp.Compare(a.Name, b.Name) })
	return out
}

// masked is a server's config with its env and header values replaced by
// Mask.
func masked(raw json.RawMessage) string {
	var cfg map[string]any
	if json.Unmarshal(raw, &cfg) != nil {
		return "{}"
	}
	for _, key := range []string{"env", "headers"} {
		if m, ok := cfg[key].(map[string]any); ok {
			for k := range m {
				m[k] = Mask
			}
		}
	}
	b, _ := json.Marshal(cfg)
	return string(b)
}

// Check runs `claude mcp list` in folder, which connects to every server
// Claude would use there, and returns what it says of each: Name, State
// and Detail, and for a plugin's server or a claude.ai connector (which
// only Claude knows) also Scope and Config.
func (Claude) Check(ctx context.Context, folder string) ([]model.MCPServer, error) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "claude", "mcp", "list")
	cmd.Dir = folder
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("claude mcp list: %w", err)
	}
	return parseList(string(out)), nil
}
