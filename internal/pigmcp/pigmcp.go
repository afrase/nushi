// Package pigmcp reads and changes the MCP servers PiG uses in a folder
// (PiG 0.8.0; docs/facts/pig.md's MCP servers):
//   - yours: "mcpServers" in <agent dir>/mcp.json, the agent folder found
//     as the bridge finds it (pi.Flavor.AgentDir);
//   - the project's: "mcpServers" in the folder's own .pig/mcp.json (not a
//     parent's), loaded only when PiG trusts the folder (pi.Flavor.Trusts);
//     until then its servers are Untrusted;
//   - a project entry replaces yours of its name; one with no command, URL
//     or type is an override of yours, which changes only its "enabled"
//     (and exposure) there;
//   - "enabled": false keeps a server, unconnected: the off switch, in the
//     file that has the server (yours: on or off everywhere). Nushi writes
//     no override; one a trusted folder has holds yours there (Held).
//
// Nushi writes the files itself, a key at a time (jsonsettings: every
// other byte kept), as PiG's own `pig mcp add` would change them; it
// checks and signs in through PiG's CLI. PiG reads its servers when a
// session starts, so a chat picks a change up when its pig starts again.
package pigmcp

import (
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/pi"
	"github.com/afrase/nushi/internal/procgroup"
	"github.com/afrase/nushi/internal/tty"
)

// PiG is PiG's MCP config.
type PiG struct {
	pi.Flavor
	// Run finds the pig the chats run and their environment, for what runs
	// it (the check, a sign-in), or why PiG can't run.
	Run func() (model.AgentRun, error)
}

// file is a config file as PiG reads it: its servers by name, as stored.
type file struct {
	Servers map[string]json.RawMessage `json:"mcpServers"`
}

func (c PiG) userFile() string { return filepath.Join(c.AgentDir(), "mcp.json") }

// projectName is the project's file, relative to its folder.
func (c PiG) projectName() string { return filepath.Join(c.Folder, "mcp.json") }

// entry is what Nushi reads of a server's entry.
type entry struct {
	Command, URL, Type *json.RawMessage
	Enabled            *bool
}

func parse(raw json.RawMessage) entry {
	var e struct {
		Command *json.RawMessage `json:"command"`
		URL     *json.RawMessage `json:"url"`
		Type    *json.RawMessage `json:"type"`
		Enabled *bool            `json:"enabled"`
	}
	_ = json.Unmarshal(raw, &e) // not an object: PiG reports it, and it's listed as stored
	return entry{e.Command, e.URL, e.Type, e.Enabled}
}

// override says an entry only changes yours of its name: it has no
// command, URL or type.
func (e entry) override() bool { return e.Command == nil && e.URL == nil && e.Type == nil }

func (e entry) off() bool { return e.Enabled != nil && !*e.Enabled }

// Servers returns your servers, then the project's, each sorted by name,
// as PiG reads them in folder (the package's comment): a project's
// server hides yours of its name, and an override turns yours off or on,
// only when PiG trusts the folder. Yours not reading is an error; the
// project's is left out, as PiG does.
func (c PiG) Servers(folder string) ([]model.MCPServer, error) {
	var user, project file
	if err := jsonsettings.Read(c.userFile(), &user); err != nil {
		return nil, err
	}
	projectFile := filepath.Join(folder, c.projectName())
	if err := jsonsettings.Read(projectFile, &project); err != nil {
		slog.Warn("leaving out an MCP config", "err", err) // as PiG does: yours still count
		project = file{}
	}
	trusted := c.Trusts(folder)
	var out []model.MCPServer
	for _, name := range sorted(user.Servers) {
		raw := user.Servers[name]
		sv := model.MCPServer{Name: name, Scope: "user", Source: c.userFile(), Config: string(raw), Off: parse(raw).off()}
		if p, ok := project.Servers[name]; ok && trusted {
			if e := parse(p); !e.override() {
				sv.Shadowed = true
			} else if e.Enabled != nil {
				sv.Off, sv.Held = !*e.Enabled, heldHere
			}
		}
		out = append(out, sv)
	}
	for _, name := range sorted(project.Servers) {
		raw := project.Servers[name]
		e := parse(raw)
		if _, yours := user.Servers[name]; yours && e.override() {
			continue // part of yours
		}
		out = append(out, model.MCPServer{Name: name, Scope: "project", Source: projectFile, Config: string(raw), Off: e.off(), Untrusted: !trusted})
	}
	return out, nil
}

func sorted(m map[string]json.RawMessage) []string {
	names := make([]string, 0, len(m))
	for name := range m {
		names = append(names, name)
	}
	slices.SortFunc(names, cmp.Compare)
	return names
}

// checkFor is the longest a check waits: PiG gives a server 60 s a
// request by default, and connects them all at once.
var checkFor = 2 * time.Minute

// listed is `pig mcp list --json`'s answer.
type listed struct {
	Servers []struct {
		Name  string `json:"name"`
		Scope string `json:"scope"`
		State string `json:"state"`
		Error string `json:"error"`
	} `json:"servers"`
	Errors []string `json:"errors"`
}

// Check runs `pig mcp list --json` in folder, which connects to every
// enabled server PiG would use there (the project's only when it trusts
// the folder, by trust.json alone: the list ignores defaultProjectTrust
// "always"; no extensions load), and returns each one's state and scope;
// an entry PiG skipped as it can't read it comes back failed, with PiG's
// words, by its file's scope.
// PiG exits 1 when a server failed: the list says how each went.
//
// It runs in folder only when PiG trusts it. In one PiG doesn't trust it
// runs in an empty temporary folder: pig would leave that folder's
// .pig/mcp.json out anyway, and run elsewhere it reads nothing else the
// folder brings, whatever its version does with a folder's settings. So
// a list asked for any folder (Settings names one, a paired device any)
// starts nothing of a folder the user hasn't trusted in PiG.
func (c PiG) Check(ctx context.Context, folder string) ([]model.MCPServer, error) {
	r, err := c.Run()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, checkFor)
	defer cancel()
	dir := folder
	if !c.Trusts(folder) {
		empty, err := os.MkdirTemp("", "nushi-pig-mcp-")
		if err != nil {
			return nil, fmt.Errorf("pig mcp list: %w", err)
		}
		defer func() { _ = os.RemoveAll(empty) }()
		dir = empty
	}
	cmd := exec.CommandContext(ctx, r.CLI, "mcp", "list", "--json") //nolint:gosec // the user's pig, words of ours
	cmd.Dir, cmd.Env = dir, r.Env
	procgroup.Bound(cmd)
	var stdout, stderr capped
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	runErr := cmd.Run()
	out := stdout.b
	var l listed
	if err := json.Unmarshal(out, &l); err != nil || l.Servers == nil {
		if ctx.Err() != nil {
			return nil, fmt.Errorf("pig mcp list didn't finish in %s", checkFor)
		}
		if stdout.cut || stderr.cut {
			return nil, errTooLong()
		}
		if said := strings.TrimSpace(stderr.String() + string(out)); said != "" {
			return nil, fmt.Errorf("pig mcp list: %s", tty.LastLine(string(out)+"\n"+stderr.String()))
		}
		if runErr == nil {
			return nil, errors.New("pig mcp list printed no list")
		}
		return nil, fmt.Errorf("pig mcp list: %w", runErr)
	}
	var got []model.MCPServer
	seen := map[[2]string]bool{} // by scope and name
	for _, s := range l.Servers {
		sv := model.MCPServer{Name: s.Name, Scope: scope(s.Scope)}
		switch s.State {
		case "connected", "disabled":
			sv.State = s.State
		case "needs-auth":
			sv.State = "needs_auth"
		case "failed":
			sv.State, sv.Detail = "failed", s.Error
		default:
			sv.State, sv.Detail = "unknown", s.State
		}
		seen[[2]string{sv.Scope, sv.Name}] = true
		got = append(got, sv)
	}
	for _, e := range l.Errors {
		if sv, ok := c.skipped(folder, e); ok && !seen[[2]string{sv.Scope, sv.Name}] {
			seen[[2]string{sv.Scope, sv.Name}] = true
			got = append(got, sv)
		}
	}
	return got, nil
}

// ChecksByScope is true: PiG's list says each server's scope, and an
// entry it refused in one file is no state of another's of its name
// (mcp's byScope).
func (PiG) ChecksByScope() bool { return true }

// scope is Nushi's word for a scope PiG lists.
func scope(s string) string {
	if s == "global" {
		return "user"
	}
	return s
}

// skipped reads an error of PiG's list about one entry: "<file>:
// server \"<name>\" …" or "<file>: invalid server name \"<name>\" …".
// One about a whole file names no server.
func (c PiG) skipped(folder, e string) (model.MCPServer, bool) {
	sv := model.MCPServer{State: "failed"}
	for path, s := range map[string]string{c.userFile(): "user", filepath.Join(folder, c.projectName()): "project"} {
		if rest, ok := strings.CutPrefix(e, path+": "); ok {
			sv.Scope, sv.Detail = s, rest
		}
	}
	for _, lead := range []string{`server "`, `invalid server name "`} {
		if name, ok := strings.CutPrefix(sv.Detail, lead); ok {
			sv.Name, _, ok = strings.Cut(name, `"`)
			return sv, ok && sv.Name != ""
		}
	}
	return sv, false
}

// signInFor is how long a sign-in may take in the browser, as PiG's own
// default.
const signInFor = 5 * time.Minute

// Login signs in to a server (`pig mcp login`), in folder: the server
// PiG uses there. PiG opens the browser and waits for it, with no
// terminal needed, and keeps the tokens in its mcp-auth.json.
func (c PiG) Login(ctx context.Context, folder, name string) error {
	ctx, cancel := context.WithTimeout(ctx, signInFor+10*time.Second)
	defer cancel()
	if out, err := c.pig(ctx, folder, "login", "--timeout", strconv.Itoa(int(signInFor.Seconds())), "--", name); err != nil {
		return fmt.Errorf("signing in to %s didn't finish: %s", name, out)
	}
	return nil
}

// Logout forgets a server's sign-in (`pig mcp logout`).
func (c PiG) Logout(ctx context.Context, folder, name string) error {
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	if out, err := c.pig(ctx, folder, "logout", "--", name); err != nil {
		return fmt.Errorf("signing out of %s failed: %s", name, out)
	}
	return nil
}

// pig runs `pig mcp <args>` in folder, as a chat's pig runs, and returns
// its last line.
func (c PiG) pig(ctx context.Context, folder string, args ...string) (string, error) {
	r, err := c.Run()
	if err != nil {
		return err.Error(), err
	}
	cmd := exec.CommandContext(ctx, r.CLI, append([]string{"mcp"}, args...)...) //nolint:gosec // the user's pig, the server name after --
	cmd.Dir, cmd.Env = folder, r.Env
	procgroup.Bound(cmd)
	var out capped
	cmd.Stdout, cmd.Stderr = &out, &out
	err = cmd.Run()
	if out.cut {
		return errTooLong().Error(), err
	}
	return tty.LastLine(string(out.b)), err
}

// maxOutput is the most of what pig prints that is kept, stdout and
// stderr each: PiG caps a server's stderr itself (8 MB gave a 3 KB
// error), so only a broken pig gets near it. A variable for a test.
var maxOutput = 4 << 20

// capped keeps the first maxOutput bytes written to it and drops the
// rest, still taking them, so pig never blocks on a full pipe; cut says
// some were dropped.
type capped struct {
	b   []byte
	cut bool
}

func (c *capped) Write(p []byte) (int, error) {
	room := maxOutput - len(c.b)
	c.b = append(c.b, p[:max(0, min(room, len(p)))]...)
	c.cut = c.cut || len(p) > room
	return len(p), nil
}

// errTooLong is why what pig printed isn't shown: it passed the limit,
// and a fragment of it would mean nothing.
func errTooLong() error { return fmt.Errorf("pig printed more than %s", size(maxOutput)) }

// size is n bytes in words, in whole MB from 1 MB up.
func size(n int) string {
	if n >= 1<<20 {
		return fmt.Sprintf("%d MB", n>>20)
	}
	return fmt.Sprintf("%d bytes", n)
}

func (c *capped) String() string { return string(c.b) }

// Project is folder: the project's file is the folder's own.
func (PiG) Project(folder string) string { return folder }

// OwnFolderOnly is true: PiG reads the session's own .pig/mcp.json, not
// a parent's, so a project change reaches that folder's chats alone.
func (PiG) OwnFolderOnly() bool { return true }

// Shape is yours and the project's, an off switch (yours on or off
// everywhere, as PiG's own flag means; a project's in the project's
// file, shared with everyone on it), a project's servers loaded with the
// folder's trust, and no legacy SSE (mcp.Config).
func (PiG) Shape() model.MCPShape {
	return model.MCPShape{Scopes: []string{"user", "project"}, Switch: true, UserSwitch: model.SwitchEverywhere, ProjectShared: true}
}

// TrustsFolder says PiG trusts folder, so loads its .pig/mcp.json: the
// same answer Servers marks Untrusted by (mcp's folderTrust).
func (c PiG) TrustsFolder(folder string) bool { return c.Trusts(folder) }

// ChecksInFolder is true: `pig mcp list` runs in the folder when PiG
// trusts it, where it reads its .pig/mcp.json (mcp.Config); Check runs it
// elsewhere for a folder PiG doesn't trust.
func (PiG) ChecksInFolder() bool { return true }

// errNoLocal is why Claude's local scope is refused.
var errNoLocal = errors.New("PiG has no local servers: add it for you (user) or the project")
