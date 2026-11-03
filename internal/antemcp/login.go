package antemcp

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/procgroup"
)

// Ante's sign-in to an MCP server is its own command, and it has moved:
// none before 0.2.15, `ante mcp login` in 0.2.15, `ante auth login` from
// 0.3.0 (docs/facts/ante.md). Ante keeps what it gets; Nushi only starts
// the command.

// signInFor is how long a sign-in may take in the browser, as Claude's.
const signInFor = 5 * time.Minute

// needsSignIn is in Ante's words for a server that answered 401, in every
// version that says so: "MCP server '<name>' requires sign-in (HTTP 401);
// run `<its command> <name>`". Only that counts: a server with 0.2's retired
// "oauth" block is told about `ante auth login` too, and needs its settings
// changed first.
const needsSignIn = "requires sign-in"

// errNoSignIn is why an Ante without the command gets no sign-in.
var errNoSignIn = errors.New("this Ante can't sign in to MCP servers: run `ante update`")

// signIn finds the command group that signs in to an MCP server in the
// Ante the chats run, by asking it: `ante auth login` exists in every
// version, but until 0.3.0 only for providers, so the version's command
// is the one whose help speaks of MCP servers.
func (a Ante) signIn(ctx context.Context) (r model.AgentRun, group string, err error) {
	if r, err = a.Run(); err != nil {
		return r, "", err
	}
	for _, group := range []string{"auth", "mcp"} {
		if offers(ctx, r, group) {
			return r, group, nil
		}
	}
	return r, "", errNoSignIn
}

// offers says `ante <group> login` signs in to MCP servers. An Ante
// without the group fails, and looks for an `ante-<group>` program first.
func offers(ctx context.Context, r model.AgentRun, group string) bool {
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, r.CLI, group, "login", "--help") //nolint:gosec // the user's ante, words of ours
	cmd.Dir, cmd.Env = ante.Home(), r.Env
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	return err == nil && strings.Contains(string(out), "MCP server")
}

// account is what Login and Logout start from: Ante's command for a
// server you have. `ante auth login` also takes a provider's or an OAuth
// profile's name, so one that isn't your server never reaches it.
func (a Ante) account(ctx context.Context, name string) (model.AgentRun, string, error) {
	servers, err := a.Servers("")
	if err != nil {
		return model.AgentRun{}, "", err
	}
	if !slices.ContainsFunc(servers, func(s model.MCPServer) bool { return s.Name == name }) {
		return model.AgentRun{}, "", fmt.Errorf("Ante has no server named %s", name)
	}
	return a.signIn(ctx)
}

// Login signs in to a server (`ante auth login`, or 0.2.15's `ante mcp
// login`): Ante opens the browser and waits for it. It runs as a chat's
// ante does, so the token lands where chats and checks look, and in
// Ante's own folder, whatever folder was asked: Ante's servers don't
// depend on one. Ante's sign-in was made for a terminal and offers to
// take a pasted URL while it waits, so it gets one (script(1), as
// Claude's) with a stdin that stays open and silent: a user who types
// nothing, not an input that ended. 0.2.15 needs --force, or it finds the
// token the server just refused, says it is signed in and opens no
// browser; from 0.3.0 login always signs in again and the flag is gone.
func (a Ante) Login(ctx context.Context, _, name string) error {
	r, group, err := a.account(ctx, name)
	if err != nil {
		return err
	}
	args := []string{"-q", "/dev/null", r.CLI, group, "login"}
	if group == "mcp" {
		args = append(args, "--force")
	}
	ctx, cancel := context.WithTimeout(ctx, signInFor)
	defer cancel()
	cmd := exec.CommandContext(ctx, "script", append(args, "--", name)...) //nolint:gosec // the user's ante, the server name after --
	cmd.Dir, cmd.Env = ante.Home(), r.Env
	if _, err := cmd.StdinPipe(); err != nil { // never written, closed when the command ends
		return err
	}
	procgroup.Bound(cmd)
	out, err := cmd.CombinedOutput()
	switch {
	case err == nil:
		return nil
	case ctx.Err() != nil:
		return fmt.Errorf("signing in to %s wasn't finished in time", name)
	}
	return fmt.Errorf("signing in to %s didn't finish: %s", name, claudemcp.LastLine(string(out)))
}

// Logout forgets a server's sign-in (`ante auth logout`, or 0.2.15's
// `ante mcp logout`).
func (a Ante) Logout(ctx context.Context, _, name string) error {
	r, group, err := a.account(ctx, name)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, r.CLI, group, "logout", "--", name) //nolint:gosec // the user's ante, the server name after --
	cmd.Dir, cmd.Env = ante.Home(), r.Env
	procgroup.Bound(cmd)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("signing out of %s failed: %s", name, claudemcp.LastLine(string(out)))
	}
	return nil
}
