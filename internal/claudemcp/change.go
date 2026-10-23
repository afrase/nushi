package claudemcp

import (
	"context"
	"errors"
	"os/exec"
	"strings"
	"time"
)

// The only ways Nushi changes Claude's MCP config: Claude's own CLI, run in
// the folder (which names the project for project and local scope). It
// never writes ~/.claude.json itself (ADR 0021).

// Add adds a server to a scope (`claude mcp add-json`).
func (Claude) Add(ctx context.Context, folder, scope, name, config string) error {
	return run(ctx, folder, "add-json", "--scope", scope, "--", name, config)
}

// Remove removes a server from a scope (`claude mcp remove`).
func (Claude) Remove(ctx context.Context, folder, scope, name string) error {
	return run(ctx, folder, "remove", "--scope", scope, "--", name)
}

// Project is the folder Claude files folder's local servers under.
func (Claude) Project(folder string) string { return project(folder) }

func run(ctx context.Context, folder string, args ...string) error {
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "claude", append([]string{"mcp"}, args...)...)
	cmd.Dir = folder
	out, err := cmd.CombinedOutput()
	if err != nil {
		if msg := strings.TrimSpace(string(out)); msg != "" {
			return errors.New(msg) // Claude's own words: "MCP server x already exists in local config"
		}
		return err
	}
	return nil
}
