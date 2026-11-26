package pigmcp

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/pi"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestMain(m *testing.M) { testcheck.Main(m) }

// place is a made-up agent folder and project folder.
type place struct {
	agent, folder string
}

func newPlace(t *testing.T) place {
	t.Helper()
	home := t.TempDir()
	resolved, err := filepath.EvalSymlinks(home)
	testcheck.NoErr(t, err)
	p := place{agent: filepath.Join(resolved, "agent"), folder: filepath.Join(resolved, "repo")}
	t.Setenv("PIG_CODING_AGENT_DIR", p.agent)
	testcheck.NoErr(t, os.MkdirAll(p.folder, 0o700))
	return p
}

func (p place) user() string    { return filepath.Join(p.agent, "mcp.json") }
func (p place) project() string { return filepath.Join(p.folder, ".pig", "mcp.json") }
func (p place) trust(t *testing.T, on bool) {
	t.Helper()
	testcheck.Write(t, filepath.Join(p.agent, "trust.json"), fmt.Sprintf(`{%q: %v}`, p.folder, on))
}

func read(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	testcheck.NoErr(t, err)
	return string(b)
}

var config = PiG{Flavor: pi.PiG}

// line is a server as the tests compare it.
func line(s model.MCPServer) string {
	words := []string{s.Scope, s.Name}
	for _, f := range []struct {
		on   bool
		word string
	}{{s.Shadowed, "shadowed"}, {s.Off, "off"}, {s.Untrusted, "untrusted"}, {s.Held != "", "held"}} {
		if f.on {
			words = append(words, f.word)
		}
	}
	if s.OffBy != "" {
		words = append(words, "by", filepath.Base(filepath.Dir(s.OffBy))+"/"+filepath.Base(s.OffBy))
	}
	return strings.Join(words, " ")
}

func lines(t *testing.T, folder string) []string {
	t.Helper()
	servers, err := config.Servers(folder)
	testcheck.NoErr(t, err)
	var out []string
	for _, s := range servers {
		out = append(out, line(s))
	}
	return out
}

// Yours, then the project's, each by name. The project's file loads only
// when PiG trusts the folder: until then its servers are untrusted and
// hide none of yours, and its overrides do nothing. Trusted, a project
// server hides yours of its name, an override turns yours off or on there
// (and is no server of its own), and one with nothing to override is
// listed as the project's, for what PiG reports of it.
func TestServersAsPiGReadsThem(t *testing.T) {
	p := newPlace(t)
	testcheck.Write(t, p.user(), `{"mcpServers": {
		"shared": {"command": "u"}, "alpha": {"url": "https://example.com/mcp", "headers": {"K": "v"}},
		"ovr": {"command": "o"}, "offev": {"command": "x", "enabled": false}}}`)
	testcheck.Write(t, p.project(), `{"mcpServers": {
		"shared": {"command": "p"}, "ovr": {"enabled": false}, "offev": {"enabled": true},
		"projonly": {"command": "q", "enabled": false}, "orphan": {"exposure": "direct"}}}`)
	want := []string{"user alpha", "user offev off", "user ovr", "user shared",
		"project orphan untrusted", "project projonly off untrusted", "project shared untrusted"}
	if got := lines(t, p.folder); !reflect.DeepEqual(got, want) {
		t.Errorf("untrusted:\n%q\nwant\n%q", got, want)
	}
	if config.TrustsFolder(p.folder) {
		t.Error("an untrusted folder is said trusted")
	}
	p.trust(t, true)
	if !config.TrustsFolder(p.folder) {
		t.Error("a trusted folder is said untrusted")
	}
	want = []string{"user alpha", "user offev held", "user ovr off held", "user shared shadowed",
		"project orphan", "project projonly off", "project shared"}
	if got := lines(t, p.folder); !reflect.DeepEqual(got, want) {
		t.Errorf("trusted:\n%q\nwant\n%q", got, want)
	}
	servers, _ := config.Servers(p.folder)
	if servers[2].Held != "Set by this folder's .pig/mcp.json" {
		t.Errorf("held by: %q", servers[2].Held)
	}
	if servers[0].Source != p.user() || servers[6].Source != p.project() || servers[0].Config != `{"url": "https://example.com/mcp", "headers": {"K": "v"}}` {
		t.Errorf("source or config: %+v, %+v", servers[0], servers[6])
	}
	// Only the folder's own .pig: a subfolder has none of it.
	sub := filepath.Join(p.folder, "sub")
	testcheck.NoErr(t, os.MkdirAll(sub, 0o700))
	if got := lines(t, sub); len(got) != 4 {
		t.Errorf("in a subfolder: %q", got)
	}
}

// What PiG can't read it skips: a project file that isn't JSON (comments
// too) is left out and yours still count. Yours not reading is an error, as
// changing it would be.
func TestAFileThatDoesntReadIsLeftOutOrRefused(t *testing.T) {
	p := newPlace(t)
	p.trust(t, true)
	testcheck.Write(t, p.user(), `{"mcpServers": {"mine": {"command": "x"}}}`)
	for _, bad := range []string{"{\n // a comment\n \"mcpServers\": {}\n}", ``, `{"mcpServers": []}`, `[]`} {
		testcheck.Write(t, p.project(), bad)
		if got := lines(t, p.folder); !reflect.DeepEqual(got, []string{"user mine"}) {
			t.Errorf("project file %q: %q", bad, got)
		}
	}
	testcheck.Write(t, p.user(), `{"mcpServers": {"mine": {"command": "x"},}}`)
	if _, err := config.Servers(p.folder); err == nil {
		t.Error("your file not reading: no error")
	}
	// An entry that isn't an object is still listed, to be removed.
	testcheck.Write(t, p.user(), `{"mcpServers": {"five": 5}}`)
	testcheck.NoErr(t, os.Remove(p.project()))
	if got := lines(t, p.folder); !reflect.DeepEqual(got, []string{"user five"}) {
		t.Errorf("an entry that isn't an object: %q", got)
	}
}

// A change writes the one server, every other byte of the file kept: keys
// Nushi doesn't know, at the top and in other servers, their order, the
// file's indentation and mode.
func TestAChangeKeepsWhatNushiDoesntKnow(t *testing.T) {
	p := newPlace(t)
	ctx := context.Background()
	before := "{\n    \"zTop\": 1,\n    \"mcpServers\": {\n        \"b\": {\"command\": \"x\", \"weird\": {\"k\": [1, 2]}}\n    },\n    \"aTop\": \"keep\"\n}\n"
	testcheck.Write(t, p.user(), before)
	testcheck.NoErr(t, os.Chmod(p.user(), 0o644))
	testcheck.NoErr(t, config.Add(ctx, p.folder, "user", "a", `{"type":"http","url":"https://example.com/mcp"}`))
	got := read(t, p.user())
	if !strings.HasPrefix(got, "{\n    \"zTop\": 1,\n    \"mcpServers\": {\n        \"b\": {\"command\": \"x\", \"weird\": {\"k\": [1, 2]}},\n        \"a\": ") ||
		!strings.HasSuffix(got, "\n    },\n    \"aTop\": \"keep\"\n}\n") {
		t.Errorf("after an add:\n%s", got)
	}
	if fi, _ := os.Stat(p.user()); fi.Mode().Perm() != 0o644 {
		t.Errorf("mode %v", fi.Mode().Perm())
	}
	testcheck.NoErr(t, config.Replace(ctx, p.folder, "user", "a", `{"command":"y","args":["1"]}`))
	testcheck.NoErr(t, config.Remove(ctx, p.folder, "user", "a"))
	if got := read(t, p.user()); got != before {
		t.Errorf("after a replace and a remove:\n%s\nwant\n%s", got, before)
	}
	// The project's file, made when there's none.
	testcheck.NoErr(t, config.Add(ctx, p.folder, "project", "p", `{"command":"z"}`))
	var file struct {
		Servers map[string]map[string]any `json:"mcpServers"`
	}
	testcheck.NoErr(t, json.Unmarshal([]byte(read(t, p.project())), &file))
	if file.Servers["p"]["command"] != "z" {
		t.Errorf("project file: %s", read(t, p.project()))
	}
}

// What PiG would refuse, or Nushi can't do here, is refused with the file
// left as it was.
func TestRefusals(t *testing.T) {
	p := newPlace(t)
	ctx := context.Background()
	before := `{"mcpServers": {"have": {"command": "x"}}}`
	testcheck.Write(t, p.user(), before)
	for _, c := range []struct {
		name string
		err  error
	}{
		{"local scope", config.Add(ctx, p.folder, "local", "n", `{"command":"x"}`)},
		{"a name there", config.Add(ctx, p.folder, "user", "have", `{"command":"x"}`)},
		{"SSE", config.Add(ctx, p.folder, "user", "n", `{"type":"sse","url":"https://example.com/sse"}`)},
		{"a command and a URL", config.Add(ctx, p.folder, "user", "n", `{"command":"x","url":"https://example.com/mcp"}`)},
		{"neither", config.Add(ctx, p.folder, "user", "n", `{"args":["x"]}`)},
		{"another type", config.Add(ctx, p.folder, "user", "n", `{"type":"ws","url":"https://example.com/mcp"}`)},
		{"no such server to remove", config.Remove(ctx, p.folder, "user", "n")},
		{"no such server to replace", config.Replace(ctx, p.folder, "user", "n", `{"command":"x"}`)},
		{"local remove", config.Remove(ctx, p.folder, "local", "have")},
	} {
		if c.err == nil {
			t.Errorf("%s: not refused", c.name)
		}
	}
	if got := read(t, p.user()); got != before {
		t.Errorf("file changed: %s", got)
	}
	sse := config.Add(ctx, p.folder, "user", "n", `{"type":"sse","url":"https://example.com/sse"}`)
	if sse == nil || sse.Error() != "PiG doesn't speak the legacy SSE transport: use the server's Streamable HTTP URL" {
		t.Errorf("SSE refused as %v", sse)
	}
	testcheck.Write(t, p.user(), `{"mcpServers": [1]}`)
	if err := config.Add(ctx, p.folder, "user", "n", `{"command":"x"}`); err == nil {
		t.Error("mcpServers not an object: not refused")
	}
}

// The project's .pig can't lead the write out of the folder.
func TestAProjectWriteStaysInTheFolder(t *testing.T) {
	p := newPlace(t)
	elsewhere := t.TempDir()
	testcheck.NoErr(t, os.Symlink(elsewhere, filepath.Join(p.folder, ".pig")))
	if err := config.Add(context.Background(), p.folder, "project", "n", `{"command":"x"}`); err == nil {
		t.Error("written through a link out of the folder")
	}
	if entries, _ := os.ReadDir(elsewhere); len(entries) > 0 {
		t.Errorf("wrote %v out of the folder", entries)
	}
}

// A project file that is a link is written as PiG writes it: followed
// while it stays in the folder (the target changed, its mode kept, the
// link left), refused when it leads out.
func TestAProjectFileLinkIsWrittenAsPiGWritesIt(t *testing.T) {
	p := newPlace(t)
	conf := filepath.Join(p.folder, "conf.json")
	testcheck.Write(t, conf, `{"mcpServers": {}}`)
	testcheck.NoErr(t, os.Chmod(conf, 0o640))
	testcheck.NoErr(t, os.MkdirAll(filepath.Dir(p.project()), 0o755))
	testcheck.NoErr(t, os.Symlink("../conf.json", p.project()))
	testcheck.NoErr(t, config.Add(context.Background(), p.folder, "project", "n", `{"command":"x"}`))
	if fi, err := os.Lstat(p.project()); err != nil || fi.Mode()&os.ModeSymlink == 0 {
		t.Errorf("the link went: %v", err)
	}
	if fi, _ := os.Stat(conf); fi.Mode().Perm() != 0o640 || !strings.Contains(read(t, conf), `"n"`) {
		t.Errorf("the target: %v %s", fi.Mode(), read(t, conf))
	}
	victim := filepath.Join(t.TempDir(), "victim.json")
	testcheck.Write(t, victim, `{"mcpServers": {}}`)
	testcheck.NoErr(t, os.Remove(p.project()))
	testcheck.NoErr(t, os.Symlink(victim, p.project()))
	err := config.Add(context.Background(), p.folder, "project", "m", `{"command":"x"}`)
	if err == nil || !strings.Contains(err.Error(), "is a link out of its folder") {
		t.Errorf("a link out: %v", err)
	}
	if got := read(t, victim); got != `{"mcpServers": {}}` {
		t.Errorf("the file outside became %s", got)
	}
}

// Two of Nushi's changes at once both land.
func TestTwoWritersBothLand(t *testing.T) {
	p := newPlace(t)
	var wg sync.WaitGroup
	for i := range 8 {
		wg.Go(func() {
			if err := config.Add(context.Background(), p.folder, "user", fmt.Sprintf("s%d", i), `{"command":"x"}`); err != nil {
				t.Error(err)
			}
		})
	}
	wg.Wait()
	if got := lines(t, p.folder); len(got) != 8 {
		t.Errorf("servers: %q", got)
	}
}

// Off and on as PiG's own flag means: a project server by its own
// "enabled" in the project's file; one of yours by "enabled" in your own
// mcp.json, on or off everywhere, with no trust needed and no repository
// touched. Nushi writes no override: one of yours that a trusted folder's
// file overrides there is held, its switch refused with why. A change
// that leaves the servers as they were writes nothing and makes nothing.
func TestSetOnAsPiGDoes(t *testing.T) {
	p := newPlace(t)
	ctx := context.Background()
	yours := `{"mcpServers": {"mine": {"command": "x"}, "offev": {"command": "y", "enabled": false}, "both": {"command": "z"}, "ovr": {"command": "o"}, "expl": {"command": "e", "enabled": true}}}`
	testcheck.Write(t, p.user(), yours)
	// No project file, untrusted: turning yours on that is on changes
	// nothing, and makes no .pig; nor does one whose entry says
	// "enabled": true.
	testcheck.NoErr(t, config.SetOn(ctx, p.folder, "user", "mine", true))
	testcheck.NoErr(t, config.SetOn(ctx, p.folder, "user", "expl", true))
	if got := read(t, p.user()); got != yours {
		t.Errorf("a change that changed nothing wrote %s", got)
	}
	if _, err := os.Stat(filepath.Join(p.folder, ".pig")); !os.IsNotExist(err) {
		t.Errorf("a change that changed nothing made .pig: %v", err)
	}
	testcheck.NoErr(t, config.SetOn(ctx, p.folder, "user", "mine", false)) // no trust needed
	testcheck.NoErr(t, config.SetOn(ctx, p.folder, "user", "offev", true))
	if _, err := os.Stat(filepath.Join(p.folder, ".pig")); !os.IsNotExist(err) {
		t.Errorf("your switch touched the repository: %v", err)
	}
	var file struct {
		Servers map[string]json.RawMessage `json:"mcpServers"`
	}
	testcheck.NoErr(t, json.Unmarshal([]byte(read(t, p.user())), &file))
	if string(file.Servers["mine"]) != `{"command": "x", "enabled": false}` || string(file.Servers["offev"]) != `{"command": "y"}` {
		t.Errorf("your file: %s", read(t, p.user()))
	}
	project := `{"other": 1, "mcpServers": {"proj": {"command": "p", "timeout": 5}, "both": {"command": "b"}, "ovr": {"enabled": false}}}`
	testcheck.Write(t, p.project(), project)
	testcheck.NoErr(t, config.SetOn(ctx, p.folder, "project", "proj", true)) // on already
	if got := read(t, p.project()); got != project {
		t.Errorf("a project change that changed nothing wrote %s", got)
	}
	testcheck.NoErr(t, config.SetOn(ctx, p.folder, "project", "proj", false)) // the project's own file needs no trust
	// The project's entry for one of yours is an override: Nushi writes
	// none, whoever asks, trusted or not.
	for _, trusted := range []bool{false, true} {
		p.trust(t, trusted)
		before := read(t, p.project())
		err := config.SetOn(ctx, p.folder, "project", "ovr", true)
		if err == nil || err.Error() != p.project()+": ovr here only changes one of your servers: Nushi writes no override" || read(t, p.project()) != before {
			t.Errorf("an override, trusted %v: %v, %s", trusted, err, read(t, p.project()))
		}
	}
	// Hidden by the project's own server, yours still turns off for you.
	testcheck.NoErr(t, config.SetOn(ctx, p.folder, "user", "both", false))
	err := config.SetOn(ctx, p.folder, "user", "ovr", true)
	if err == nil || err.Error() != "Set by this folder's .pig/mcp.json" {
		t.Errorf("held by an override: %v", err)
	}
	want := []string{"user both shadowed off", "user expl", "user mine off", "user offev", "user ovr off held", "project both", "project proj off"}
	if got := lines(t, p.folder); !reflect.DeepEqual(got, want) {
		t.Errorf("off:\n%q\nwant\n%q", got, want)
	}
	testcheck.NoErr(t, config.SetOn(ctx, p.folder, "user", "mine", true))
	testcheck.NoErr(t, config.SetOn(ctx, p.folder, "project", "proj", true))
	file.Servers = nil
	testcheck.NoErr(t, json.Unmarshal([]byte(read(t, p.project())), &file))
	if len(file.Servers) != 3 || string(file.Servers["proj"]) != `{"command": "p", "timeout": 5}` || string(file.Servers["ovr"]) != `{"enabled": false}` {
		t.Errorf("project file after turning all back: %s", read(t, p.project()))
	}
	if err := config.SetOn(ctx, p.folder, "project", "nothere", false); err == nil {
		t.Error("no such project server: not refused")
	}
}

// fakePig is a pig that records how it ran and prints out.
func fakePig(t *testing.T, out string, code int) (model.AgentRun, string) {
	t.Helper()
	dir := t.TempDir()
	log := filepath.Join(dir, "log")
	testcheck.Write(t, filepath.Join(dir, "out"), out)
	script := fmt.Sprintf("#!/bin/sh\necho \"$PWD $*\" >> %q\ncat %q\necho 'said on stderr' >&2\nexit %d\n", log, filepath.Join(dir, "out"), code)
	testcheck.Write(t, filepath.Join(dir, "pig"), script)
	testcheck.NoErr(t, os.Chmod(filepath.Join(dir, "pig"), 0o700))
	return model.AgentRun{CLI: filepath.Join(dir, "pig"), Env: []string{"PATH=/usr/bin:/bin"}}, log
}

func runs(r model.AgentRun) func() (model.AgentRun, error) {
	return func() (model.AgentRun, error) { return r, nil }
}

// The check is `pig mcp list --json` in the folder, which exits 1 when a
// server failed: each server's state as PiG says it, with its scope, and
// an entry PiG skipped (its errors, by file and server name) failed with
// PiG's words, also when PiG used yours of that name instead.
func TestCheckReadsPigMcpList(t *testing.T) {
	p := newPlace(t)
	list := `{"servers": [
		{"name": "good", "scope": "global", "state": "connected", "tools": ["echo"]},
		{"name": "bad", "scope": "project", "state": "failed", "error": "MCP connection closed\nmade-up failure"},
		{"name": "authy", "scope": "global", "state": "needs-auth"},
		{"name": "off", "scope": "global", "state": "disabled"},
		{"name": "odd", "scope": "global", "state": "connecting"}],
	  "errors": [
		"` + p.user() + `: server \"old\": legacy SSE transport is not supported; use the streamable HTTP URL",
		"` + p.project() + `: invalid server name \"bad name!\" (use letters, digits, \"_\" and \"-\")",
		"` + p.project() + `: Unexpected end of JSON input",
		"` + p.project() + `: server \"good\": legacy SSE transport is not supported; use the streamable HTTP URL"]}`
	r, log := fakePig(t, list, 1)
	got, err := PiG{Flavor: pi.PiG, Run: runs(r)}.Check(context.Background(), p.folder)
	testcheck.NoErr(t, err)
	var says []string
	for _, s := range got {
		says = append(says, fmt.Sprintf("%s %s %s %q", s.Scope, s.Name, s.State, s.Detail))
	}
	want := []string{`user good connected ""`, `project bad failed "MCP connection closed\nmade-up failure"`,
		`user authy needs_auth ""`, `user off disabled ""`, `user odd unknown "connecting"`,
		`user old failed "server \"old\": legacy SSE transport is not supported; use the streamable HTTP URL"`,
		`project bad name! failed "invalid server name \"bad name!\" (use letters, digits, \"_\" and \"-\")"`,
		`project good failed "server \"good\": legacy SSE transport is not supported; use the streamable HTTP URL"`}
	if !reflect.DeepEqual(says, want) {
		t.Errorf("check:\n%s\nwant\n%s", strings.Join(says, "\n"), strings.Join(want, "\n"))
	}
	if ran := read(t, log); ran != p.folder+" mcp list --json\n" {
		t.Errorf("ran %q", ran)
	}
	// What isn't PiG's list is an error in its words.
	r, _ = fakePig(t, "Error: unknown command\n", 2)
	if _, err := (PiG{Flavor: pi.PiG, Run: runs(r)}).Check(context.Background(), p.folder); err == nil || !strings.Contains(err.Error(), "said on stderr") {
		t.Errorf("not a list: %v", err)
	}
}

// What pig prints is read through a limit: past it, the rest is dropped,
// so a broken pig can't fill the daemon's memory, and the error says so,
// never showing a fragment of what was cut.
func TestPigsOutputIsReadThroughALimit(t *testing.T) {
	p := newPlace(t)
	was := maxOutput
	maxOutput = 64
	t.Cleanup(func() { maxOutput = was })
	r, _ := fakePig(t, `{"servers": [{"name": "good", "scope": "global", "state": "connected", "tools": ["a", "b", "c", "d"]}], "errors": []}`, 0)
	if _, err := (PiG{Flavor: pi.PiG, Run: runs(r)}).Check(context.Background(), p.folder); err == nil || err.Error() != "pig printed more than 64 bytes" {
		t.Errorf("a list longer than the limit: %v", err)
	}
	r, _ = fakePig(t, strings.Repeat("x", 100)+"\n", 1)
	err := PiG{Flavor: pi.PiG, Run: runs(r)}.Logout(context.Background(), p.folder, "web")
	if err == nil || err.Error() != "signing out of web failed: pig printed more than 64 bytes" {
		t.Errorf("a sign-out's words past the limit: %v", err)
	}
	if got := size(4 << 20); got != "4 MB" {
		t.Errorf("the limit reads %q", got)
	}
}

// Signing in and out is PiG's own command, in the folder (the server used
// there), the name after --; its last words say why it failed.
func TestLoginAndLogoutArePigsOwn(t *testing.T) {
	p := newPlace(t)
	r, log := fakePig(t, "Signed out.\n", 0)
	c := PiG{Flavor: pi.PiG, Run: runs(r)}
	testcheck.NoErr(t, c.Login(context.Background(), p.folder, "web"))
	testcheck.NoErr(t, c.Logout(context.Background(), p.folder, "web"))
	if ran, want := read(t, log), p.folder+" mcp login --timeout 300 -- web\n"+p.folder+" mcp logout -- web\n"; ran != want {
		t.Errorf("ran %q, want %q", ran, want)
	}
	r, _ = fakePig(t, "Sign-in to MCP server \"web\" was cancelled or not completed within 300 seconds.\n", 1)
	if err := (PiG{Flavor: pi.PiG, Run: runs(r)}).Login(context.Background(), p.folder, "web"); err == nil || !strings.Contains(err.Error(), "said on stderr") {
		t.Errorf("a failed sign-in: %v", err)
	}
}

// PiG has yours and the project's, an off switch (yours on or off
// everywhere; a project's in the file everyone on it shares), no
// approval one by one and no legacy SSE; its check runs in the folder.
func TestShape(t *testing.T) {
	want := model.MCPShape{Scopes: []string{"user", "project"}, Switch: true, UserSwitch: model.SwitchEverywhere, ProjectShared: true}
	if got := config.Shape(); !reflect.DeepEqual(got, want) || !config.ChecksInFolder() || config.Project("/a/b") != "/a/b" || !config.ChecksByScope() || !config.OwnFolderOnly() {
		t.Errorf("shape %+v, checks in folder %v", got, config.ChecksInFolder())
	}
}
