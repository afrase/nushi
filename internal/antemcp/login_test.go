package antemcp

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/model"
)

const gateway = `{"mcp_servers": {"example-gateway": {"url": "https://mcp.example.com/mcp"}, "local-tools": {"command": "tools-mcp"}}}`

// The first line of `login --help` in each Ante (docs/facts/ante.md).
const (
	authHelp     = `Sign in with an OAuth profile, or to the connector (provider or MCP server) that uses one`
	providerHelp = `Sign in to a provider`
	mcpHelp      = `Sign in to a remote MCP server with OAuth`
)

// fakeAnte is an `ante` script answering help as one version does:
// current (0.3), between (0.2.15) or old (0.2.14). login is the rest of
// what it does for a real call.
func fakeAnte(t *testing.T, version, login string) (run func() (model.AgentRun, error), calls func() []string) {
	t.Helper()
	dir := t.TempDir()
	bin := filepath.Join(dir, "ante")
	authLogin, mcpLogin := providerHelp, ""
	switch version {
	case "0.3":
		authLogin = authHelp
	case "0.2.15":
		mcpLogin = mcpHelp
	}
	script := `#!/bin/bash
here=$(dirname "$0")
echo "$*" >> "$here/calls"
case "$*" in
"auth login --help") echo '` + authLogin + `'; exit 0 ;;
"mcp login --help") [ -n '` + mcpLogin + `' ] && { echo '` + mcpLogin + `'; exit 0; }
  echo "ante: 'mcp' is not an ante command" >&2; exit 127 ;;
esac
` + login + "\n"
	if err := os.WriteFile(bin, []byte(script), 0o700); err != nil {
		t.Fatal(err)
	}
	env := append(os.Environ(), "NUSHI_TEST_MARK=as-a-chat")
	return func() (model.AgentRun, error) { return model.AgentRun{CLI: bin, Env: env}, nil },
		func() []string {
			b, err := os.ReadFile(filepath.Join(dir, "calls"))
			if err != nil {
				return nil
			}
			var out []string
			for line := range strings.Lines(string(b)) {
				if !strings.HasSuffix(strings.TrimSpace(line), "--help") {
					out = append(out, strings.TrimSpace(line))
				}
			}
			return out
		}
}

// Each version gets its own command, and the name after --; 0.2.15's is
// forced past the stored token the server refused.
func TestLoginRunsThatAntesCommand(t *testing.T) {
	for _, c := range []struct{ version, want string }{
		{"0.3", "auth login -- example-gateway"},
		{"0.2.15", "mcp login --force -- example-gateway"},
	} {
		t.Run(c.version, func(t *testing.T) {
			home(t, gateway)
			run, calls := fakeAnte(t, c.version, "")
			if err := (Ante{Run: run}).Login(context.Background(), "/some/folder", "example-gateway"); err != nil {
				t.Fatal(err)
			}
			if got := calls(); !reflect.DeepEqual(got, []string{c.want}) {
				t.Errorf("ran %q, want %q", got, c.want)
			}
		})
	}
}

// The fake's terminal, folder, environment and input are as Login means
// them: a terminal, Ante's folder, a chat's environment, and an input
// that neither ends nor says anything while it waits.
func TestLoginRunsAsAChatsAnte(t *testing.T) {
	path := home(t, gateway)
	run, _ := fakeAnte(t, "0.3", `{
  [ -t 0 ] && echo terminal
  pwd -P
  echo "$NUSHI_TEST_MARK"
  start=$SECONDS; read -r -t 2 _; echo "waited $((SECONDS - start))"
} > "$here/seen"`)
	if err := (Ante{Run: run}).Login(context.Background(), "/some/folder", "example-gateway"); err != nil {
		t.Fatal(err)
	}
	r, _ := run()
	b, err := os.ReadFile(filepath.Join(filepath.Dir(r.CLI), "seen"))
	if err != nil {
		t.Fatal(err)
	}
	dir, err := filepath.EvalSymlinks(filepath.Dir(path))
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(string(b)), "\n")
	if len(lines) != 4 || lines[0] != "terminal" || lines[1] != dir || lines[2] != "as-a-chat" {
		t.Fatalf("seen = %q, want a terminal, %s, a chat's environment", lines, dir)
	}
	if lines[3] == "waited 0" {
		t.Error("stdin ended")
	}
}

func TestLoginFailure(t *testing.T) {
	home(t, gateway)
	run, _ := fakeAnte(t, "0.3", `printf 'Opening browser\r\n\033[31mFailed to start callback server on port 1455\033[0m\r\n'; exit 3`)
	err := Ante{Run: run}.Login(context.Background(), "/f", "example-gateway")
	if err == nil || err.Error() != "signing in to example-gateway didn't finish: Failed to start callback server on port 1455" {
		t.Errorf("err = %v, want Ante's last line", err)
	}
}

// A sign-in never finished ends with its context, and so does the wait.
// The context also covers the version check before it, which a loaded
// machine can take past a few hundred milliseconds, so it's given 2 s.
func TestLoginGivesUp(t *testing.T) {
	home(t, gateway)
	run, _ := fakeAnte(t, "0.3", `exec sleep 60`)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	start := time.Now()
	err := Ante{Run: run}.Login(ctx, "/f", "example-gateway")
	if err == nil || !strings.Contains(err.Error(), "in time") {
		t.Errorf("err = %v", err)
	}
	if d := time.Since(start); d > 10*time.Second {
		t.Errorf("waited %v", d)
	}
}

// An Ante without the command runs nothing and says to update; its own
// `ante auth login` signs in to a provider, so it must not be tried.
func TestOldAnteHasNoSignIn(t *testing.T) {
	home(t, gateway)
	run, calls := fakeAnte(t, "0.2.14", "")
	a := Ante{Run: run}
	for what, err := range map[string]error{
		"login":  a.Login(context.Background(), "/f", "example-gateway"),
		"logout": a.Logout(context.Background(), "/f", "example-gateway"),
	} {
		if err == nil || !strings.Contains(err.Error(), "ante update") {
			t.Errorf("%s: %v", what, err)
		}
	}
	if got := calls(); got != nil {
		t.Errorf("ran %q", got)
	}
}

// A name that isn't a server of yours could be a provider's or an OAuth
// profile's, which `ante auth login` and logout would take.
func TestOnlyYourServers(t *testing.T) {
	home(t, gateway)
	run, calls := fakeAnte(t, "0.3", "")
	a := Ante{Run: run}
	if err := a.Login(context.Background(), "/f", "example-provider"); err == nil {
		t.Error("login: signed in to a name that isn't a server")
	}
	if err := a.Logout(context.Background(), "/f", "example-provider/work"); err == nil {
		t.Error("logout: forgot a name that isn't a server")
	}
	if got := calls(); got != nil {
		t.Errorf("ran %q", got)
	}
}

func TestLogout(t *testing.T) {
	for _, c := range []struct{ version, want string }{
		{"0.3", "auth logout -- example-gateway"},
		{"0.2.15", "mcp logout -- example-gateway"},
	} {
		t.Run(c.version, func(t *testing.T) {
			home(t, gateway)
			run, calls := fakeAnte(t, c.version, "")
			if err := (Ante{Run: run}).Logout(context.Background(), "/f", "example-gateway"); err != nil {
				t.Fatal(err)
			}
			if got := calls(); !reflect.DeepEqual(got, []string{c.want}) {
				t.Errorf("ran %q, want %q", got, c.want)
			}
		})
	}
	home(t, gateway)
	run, _ := fakeAnte(t, "0.3", `echo 'not signed in to example-gateway' >&2; exit 1`)
	err := Ante{Run: run}.Logout(context.Background(), "/f", "example-gateway")
	if err == nil || !strings.Contains(err.Error(), "not signed in to example-gateway") {
		t.Errorf("err = %v, want Ante's words", err)
	}
}

// check is Check against a host whose warm-up says why for example-gateway.
func check(t *testing.T, a Ante, why string) []model.MCPServer {
	t.Helper()
	a.Spawn = func() (ante.Spawn, error) {
		return func(string) (io.WriteCloser, io.Reader, func(), error) {
			in, out, kill := host(`{"event":{"SessionStart":{"session_id":"ses_1","cwd":"/tmp/x"}}}`,
				`{"event":{"ExtensionRefreshed":{"session_id":"ses_1","mcp_servers":[{"name":"example-gateway","tools":[]},{"name":"local-tools","tools":[{"name":"read"}]}]}}}`,
				`{"event":{"InfoBlockAppend":{"id":"mcp-warmup-ses_1","detail":"MCP server 'example-gateway' failed: `+why+`"}}}`,
				`{"event":{"InfoBlockAppend":{"id":"mcp-warmup-ses_1","detail":"MCP ready: 1/2 servers connected, 1 tools registered."}}}`)
			return in, out, kill, nil
		}, nil
	}
	got, err := a.Check(context.Background(), "/f")
	if err != nil {
		t.Fatal(err)
	}
	return got
}

// Ante's 401, in each version's words, is a sign-in to offer, not a
// failure; Ante's words go, the button says it.
func TestCheckNeedsAuth(t *testing.T) {
	for version, why := range map[string]string{
		"0.3":    "MCP server 'example-gateway' requires sign-in (HTTP 401); run `ante auth login example-gateway`",
		"0.2.15": "MCP server 'example-gateway' requires sign-in (HTTP 401); run `ante mcp login example-gateway`",
	} {
		t.Run(version, func(t *testing.T) {
			home(t, gateway)
			run, _ := fakeAnte(t, version, "")
			want := []model.MCPServer{{Name: "example-gateway", State: "needs_auth"}, {Name: "local-tools", State: "connected"}}
			if got := check(t, Ante{Run: run}, why); !reflect.DeepEqual(got, want) {
				t.Errorf("Check = %+v, want %+v", got, want)
			}
		})
	}
}

// An Ante with no sign-in gets no button that can't work: the row stays a
// failure, in its own words. Nor does a mention of the command make one:
// that server needs its retired "oauth" block taken out first.
func TestCheckStaysFailed(t *testing.T) {
	const sayRun = "MCP server 'example-gateway' requires sign-in (HTTP 401); run `ante mcp login example-gateway`"
	const block = "the `oauth` block is retired; use `ante auth login example-gateway` or `headers.Authorization`"
	for _, c := range []struct{ version, why string }{{"0.2.14", sayRun}, {"0.3", block}} {
		home(t, gateway)
		run, _ := fakeAnte(t, c.version, "")
		got := check(t, Ante{Run: run}, c.why)
		if got[0].State != "failed" || got[0].Detail != c.why {
			t.Errorf("%s: %+v, want failed with Ante's words", c.version, got[0])
		}
	}
}
