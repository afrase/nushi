package claudemcp

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/ansi"
	"github.com/afrase/nushi/internal/procgroup"
)

// Nushi changes Claude's MCP config through Claude's own CLI, run in the
// folder (which names the project for project and local scope), and the
// approval lists in settings.go. It never writes ~/.claude.json itself
// (ADR 0021).

// Add adds a server to a scope (`claude mcp add-json`).
func (Claude) Add(ctx context.Context, folder, scope, name, config string) error {
	return run(ctx, folder, "add-json", "--scope", scope, "--", name, config)
}

// Remove removes a server from a scope (`claude mcp remove`).
func (Claude) Remove(ctx context.Context, folder, scope, name string) error {
	return run(ctx, folder, "remove", "--scope", scope, "--", name)
}

// Login signs in to a server that needs OAuth (`claude mcp login`): it
// opens the browser and waits, a few minutes at most, for the sign-in to
// finish there. The CLI refuses to run without a terminal, so it runs
// under script(1), which gives it one. script looks a bare name up
// itself, in the folder for a relative PATH entry (node_modules/.bin), so
// it gets the path Go's lookup found, which refuses those as every other
// claude Nushi runs does.
func (Claude) Login(ctx context.Context, folder, name string) error {
	claude, err := exec.LookPath("claude")
	if err != nil {
		return fmt.Errorf("signing in to %s: %w", name, err)
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "/usr/bin/script", "-q", "/dev/null", claude, "mcp", "login", "--", name) //nolint:gosec // the user's claude, the server name after --
	cmd.Dir = folder
	procgroup.Bound(cmd)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("signing in to %s didn't finish: %s", name, LastLine(string(out)))
	}
	return nil
}

// Logout forgets a server's OAuth sign-in (`claude mcp logout`).
func (Claude) Logout(ctx context.Context, folder, name string) error {
	return run(ctx, folder, "logout", "--", name)
}

// LastLine is the last line of a terminal's output with text, without its
// escape sequences.
func LastLine(out string) string {
	out = ansi.Strip(out)
	lines := strings.FieldsFunc(out, func(r rune) bool { return r == '\n' || r == '\r' })
	for _, line := range slices.Backward(lines) {
		if l := strings.TrimSpace(line); l != "" {
			return l
		}
	}
	return "no output"
}

// Project is the folder Claude files folder's local servers under.
func (Claude) Project(folder string) string { return Project(folder) }

// UserOnly is false: Claude's is the whole model (mcp.Config).
func (Claude) UserOnly() bool { return false }

func run(ctx context.Context, folder string, args ...string) error {
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "claude", append([]string{"mcp"}, args...)...) //nolint:gosec // the user's claude, names after --
	cmd.Dir = folder
	procgroup.Bound(cmd)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if msg := strings.TrimSpace(string(out)); msg != "" {
			return errors.New(msg) // Claude's own words: "MCP server x already exists in local config"
		}
		return err
	}
	return nil
}
