// Package claudemcp reads the MCP servers Claude Code uses in a folder, and
// asks Claude how they are. Claude's own files are the source of truth and
// are only read here (Claude Code 2.1.309; see ADR 0021):
//   - user scope: "mcpServers" in ~/.claude.json ($CLAUDE_CONFIG_DIR/.claude.json);
//   - local scope: "projects"[<project>]."mcpServers" in the same file, where
//     the project is the folder's repository (its main checkout, for a
//     worktree), or the folder itself outside git;
//   - project scope: .mcp.json in the folder or any folder above it, the
//     nearest winning; one that can't be read is left out, as Claude does;
//   - plugins' servers and claude.ai connectors: only what `claude mcp list`
//     reports.
package claudemcp

import (
	"cmp"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"syscall"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Claude reads Claude Code's MCP config.
type Claude struct{}

// ConfigFile is Claude's own config file, which holds user and local
// servers.
func ConfigFile() string {
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		return filepath.Join(dir, ".claude.json")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude.json")
}

// project is the folder Claude files a folder's local servers under: its
// repository's main checkout, or the folder outside git (real paths).
func project(folder string) string {
	if resolved, err := filepath.EvalSymlinks(folder); err == nil {
		folder = resolved
	}
	out, err := exec.Command("git", "-C", folder, "rev-parse", "--path-format=absolute", "--git-common-dir").Output()
	if common := strings.TrimSpace(string(out)); err == nil && filepath.Base(common) == ".git" {
		return filepath.Dir(common)
	}
	return folder
}

type servers map[string]json.RawMessage

// Servers returns the servers Claude's files give folder: user, local and
// project scope, each sorted by name, with their config as Claude has it.
// A .mcp.json that can't be read is left out (see Read).
func (c Claude) Servers(folder string) ([]model.MCPServer, error) {
	servers, unread, err := c.Read(folder)
	for _, u := range unread {
		slog.Warn("leaving out an MCP config", "err", u.Err) // as Claude does: the other files' servers still count
	}
	return servers, err
}

// Unread is a .mcp.json that is there but couldn't be read or parsed.
type Unread struct {
	Path string
	Err  error
}

// Read is Servers, with the .mcp.json files it left out.
func (Claude) Read(folder string) (out []model.MCPServer, unread []Unread, err error) {
	var cfg struct {
		MCPServers servers `json:"mcpServers"`
		Projects   map[string]struct {
			MCPServers servers `json:"mcpServers"`
			Disabled   names   `json:"disabledMcpjsonServers"`
		} `json:"projects"`
	}
	file := ConfigFile()
	if err := readJSON(file, &cfg); err != nil {
		return nil, nil, err
	}
	out = add(nil, cfg.MCPServers, "user", file)
	key := project(folder)
	out = add(out, cfg.Projects[key].MCPServers, "local", key)
	off, approved := rejected(folder, cfg.Projects[key].Disabled)
	seen := map[string]bool{}
	for dir := folder; ; dir = filepath.Dir(dir) {
		path := filepath.Join(dir, ".mcp.json")
		var mcp struct {
			MCPServers servers `json:"mcpServers"`
		}
		if err := readJSON(path, &mcp); err != nil {
			unread = append(unread, Unread{path, err})
		}
		for name := range mcp.MCPServers {
			if seen[name] {
				delete(mcp.MCPServers, name) // a nearer .mcp.json has it
			}
			seen[name] = true
		}
		start := len(out)
		out = add(out, mcp.MCPServers, "project", path)
		for i := start; i < len(out); i++ {
			out[i].Off, out[i].OffBy = offBy(off[out[i].Name], localSettings(folder))
			out[i].Approved = slices.Contains(approved, out[i].Name)
		}
		if dir == filepath.Dir(dir) {
			return out, unread, nil
		}
	}
}

// readJSON reads a JSON file into v; a missing file leaves v as it is.
func readJSON(path string, v any) error {
	b, err := ReadFile(path)
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

// maxFile is the largest of Claude's files Nushi reads.
const maxFile = 64 << 20

// ReadFile reads one of Claude's files as Claude would: only a regular file
// (a link is followed), of up to 64 MiB. A repository could bring a link to
// /dev/zero, or a fifo, in the place of one.
func ReadFile(path string) ([]byte, error) {
	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NONBLOCK, 0) // a fifo doesn't wait
	if err != nil {
		return nil, err
	}
	defer f.Close()
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() || fi.Size() > maxFile {
		return nil, fmt.Errorf("%s isn't a regular file of at most 64 MiB", path)
	}
	b, err := io.ReadAll(io.LimitReader(f, maxFile+1))
	if err == nil && len(b) > maxFile {
		err = fmt.Errorf("%s grew past 64 MiB", path)
	}
	return b, err
}

func add(out []model.MCPServer, s servers, scope, source string) []model.MCPServer {
	start := len(out)
	for name, raw := range s {
		out = append(out, model.MCPServer{Name: name, Scope: scope, Source: source, Config: string(raw)})
	}
	slices.SortFunc(out[start:], func(a, b model.MCPServer) int { return cmp.Compare(a.Name, b.Name) })
	return out
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

// offBy says whether files reject a server, and names one of them that
// isn't local (the settings file Nushi changes), if any.
func offBy(files []string, local string) (off bool, by string) {
	for _, f := range files {
		if f != local {
			return true, f
		}
	}
	return len(files) > 0, ""
}
