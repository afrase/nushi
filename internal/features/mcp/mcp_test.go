package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

type fakeConfig struct {
	files, checked []model.MCPServer
	checkErr       error
	accountErr     error           // what Login and Logout fail with
	shape          *model.MCPShape // Claude's scopes when nil
	calls          []string        // "add <name> <config>", "remove <name>"
}

func (f *fakeConfig) Servers(string) ([]model.MCPServer, error) { return f.files, nil }
func (f *fakeConfig) Check(context.Context, string) ([]model.MCPServer, error) {
	return f.checked, f.checkErr
}
func (f *fakeConfig) Add(ctx context.Context, _, _, name, config string) error {
	if ctx.Err() != nil {
		return ctx.Err()
	}
	f.calls = append(f.calls, "add "+name+" "+config)
	if strings.Contains(config, "bad") {
		return errors.New("refused")
	}
	return nil
}
func (f *fakeConfig) Remove(ctx context.Context, _, _, name string) error {
	if ctx.Err() != nil {
		return ctx.Err()
	}
	f.calls = append(f.calls, "remove "+name)
	return nil
}
func (f *fakeConfig) Project(folder string) string { return folder }
func (f *fakeConfig) SetOn(_ context.Context, _, scope, name string, on bool) error {
	f.calls = append(f.calls, fmt.Sprintf("on %s %s %v", scope, name, on))
	return nil
}
func (f *fakeConfig) Login(context.Context, string, string) error  { return f.accountErr }
func (f *fakeConfig) Logout(context.Context, string, string) error { return f.accountErr }
func (f *fakeConfig) Shape() model.MCPShape {
	if f.shape != nil {
		return *f.shape
	}
	return model.MCPShape{Scopes: []string{"user", "project", "local"}}
}
func (f *fakeConfig) ChecksInFolder() bool { return true }

func TestListMergesTheCheck(t *testing.T) {
	svc := New("claude", &fakeConfig{
		files: []model.MCPServer{{Name: "a", Scope: "user", Config: `{"env":{"K":"secret"}}`, Shadowed: true}, {Name: "a", Scope: "local"},
			{Name: "gone", Scope: "project"}},
		checked: []model.MCPServer{{Name: "a", State: "connected"}, {Name: "plugin:x:y", Scope: "plugin", State: "failed"},
			{Name: "managed", State: "connected"}},
	}, nil)
	got, checkErr, err := svc.List(context.Background(), "/f", true)
	if err != nil || checkErr != nil {
		t.Fatal(err, checkErr)
	}
	want := []string{"user a  shadowed", "local a connected ", "project gone disabled ", "plugin plugin:x:y failed ", "other managed connected "}
	for i, w := range want {
		g := got[i]
		s := g.Scope + " " + g.Name + " " + g.State + " "
		if g.Shadowed {
			s += "shadowed"
		}
		if s != w {
			t.Errorf("server %d = %q, want %q", i, s, w)
		}
	}
	if got[0].Config != `{"env":{"K":"••••"}}` {
		t.Errorf("config not masked: %s", got[0].Config)
	}
}

func TestEditKeepsMaskedValuesAndPutsTheOldOneBack(t *testing.T) {
	cfg := &fakeConfig{files: []model.MCPServer{{Name: "s", Scope: "local", Config: `{"command":"x","env":{"K":"secret"}}`}}}
	var notified []string
	svc := New("claude", cfg, func(_ string, affected func(string) bool) {
		for _, f := range []string{"/repo", "/repo/sub", "/other"} {
			if affected(f) {
				notified = append(notified, f)
			}
		}
	})
	ctx := context.Background()
	if err := svc.Edit(ctx, "/repo", "local", "s", `{"command":"x","env":{"K":"••••"}}`); err != nil {
		t.Fatal(err) // sent back as shown
	}
	if err := svc.Edit(ctx, "/repo", "local", "s", `{"command":"y","env":{"K":"typed","N":"new"}}`); err != nil {
		t.Fatal(err)
	}
	if err := svc.Edit(ctx, "/repo", "local", "s", `{"command":"bad"}`); err == nil {
		t.Fatal("a refused config should fail the edit")
	}
	want := []string{
		`remove s`, `add s {"command":"x","env":{"K":"secret"}}`,
		`remove s`, `add s {"command":"y","env":{"K":"typed","N":"new"}}`,
		`remove s`, `add s {"command":"bad"}`, `add s {"command":"x","env":{"K":"secret"}}`,
	}
	if strings.Join(cfg.calls, "\n") != strings.Join(want, "\n") {
		t.Errorf("calls:\n%s\nwant:\n%s", strings.Join(cfg.calls, "\n"), strings.Join(want, "\n"))
	}
	if strings.Join(notified, " ") != "/repo /repo/sub /repo /repo/sub" {
		t.Errorf("notified %v, want the repo's chats once per edit", notified)
	}
}

// replacingConfig is a Config that changes a server in one write.
type replacingConfig struct{ fakeConfig }

func (f *replacingConfig) Replace(_ context.Context, _, _, name, config string) error {
	f.calls = append(f.calls, "replace "+name+" "+config)
	if strings.Contains(config, "bad") {
		return errors.New("refused")
	}
	return nil
}

// An agent whose config can change a server in one write (Ante's) gets
// the edit as that one write, never a remove then an add: nothing can
// come between them and lose the server.
func TestEditIsOneChangeWhereTheAgentCan(t *testing.T) {
	cfg := &replacingConfig{fakeConfig{files: []model.MCPServer{{Name: "s", Scope: "user", Config: `{"command":"x","env":{"K":"secret"}}`}}}}
	svc := New("ante", cfg, nil)
	ctx := context.Background()
	if err := svc.Edit(ctx, "/repo", "user", "s", `{"command":"x","env":{"K":"••••"}}`); err != nil {
		t.Fatal(err)
	}
	if err := svc.Edit(ctx, "/repo", "user", "s", `{"command":"bad"}`); err == nil {
		t.Fatal("a refused config should fail the edit")
	}
	want := []string{`replace s {"command":"x","env":{"K":"secret"}}`, `replace s {"command":"bad"}`}
	if strings.Join(cfg.calls, "\n") != strings.Join(want, "\n") {
		t.Errorf("calls:\n%s\nwant:\n%s", strings.Join(cfg.calls, "\n"), strings.Join(want, "\n"))
	}
}

func TestRemoveRefusesWhatIsntAServer(t *testing.T) {
	cfg := &fakeConfig{}
	svc := New("claude", cfg, nil)
	for _, c := range []struct{ folder, scope, name string }{
		{"/repo", "user", "-s user"},
		{"/repo", "user", "-x"},
		{"/repo", "local", "../x"},
		{"repo", "local", "s"},
		{"/repo/../etc", "local", "s"},
		{"/repo", "plugin", "s"},
	} {
		if err := svc.Remove(context.Background(), c.folder, c.scope, c.name); err == nil {
			t.Errorf("Remove(%q, %q, %q) was let through", c.folder, c.scope, c.name)
		}
	}
	if len(cfg.calls) > 0 {
		t.Errorf("the agent was asked: %v", cfg.calls)
	}
}

func TestSecretsAreMaskedWhereverTheyAre(t *testing.T) {
	for in, want := range map[string]string{
		`{"url":"https://u:p@h.io/s/aB3dE5fG7hJ9kL1mN3/x?apiKey=k1&v=2#t","headers":{"A":"b"},"headersHelper":"get-token"}`:                                                                      `{"headers":{"A":"••••"},"headersHelper":"••••","url":"https://••••@h.io/s/••••/x?apiKey=••••\u0026v=••••#••••"}`,
		`{"url":"https://h.io/my-server-2024-edition/v1"}`:                                                                                                                                       `{"url":"https://h.io/my-server-2024-edition/v1"}`,
		`{"command":"docker","args":["run","-e","LOG=1","--api-key","sk-1","--token=t","GH_TOKEN=g","--port","80","plain=1"]}`:                                                                   `{"args":["run","-e","LOG=••••","--api-key","••••","--token=••••","GH_TOKEN=••••","--port","80","plain=1"],"command":"docker"}`,
		`{"command":"x","args":["-H","Authorization: Bearer t1","--header","X-Key: k2","Bearer t3","sh -c 'curl -H \"Authorization: Bearer t4\" --token t5 https://h.io/?aB3dE5fG7hJ9kL1mN3'"]}`: `{"args":["-H","Authorization: ••••","--header","X-Key: ••••","••••","sh -c 'curl -H \"Authorization: ••••\" --token •••• https://h.io/?••••'"],"command":"x"}`,
		`{"command":"npx srv --password pw https://h.io/?k=v"}`:                                                                                                                                  `{"command":"npx srv --password •••• https://h.io/?k=••••"}`,
		// Secrets' shapes wherever they stand (tech debt review 2026-11-22):
		// a positional token, one inside sh -c, a JWT in a URL's path.
		`{"command":"npx","args":["-y","@modelcontextprotocol/server-github","ghp_aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5"]}`: `{"args":["-y","@modelcontextprotocol/server-github","••••"],"command":"npx"}`,
		`{"command":"sh","args":["-c","run --x sk-ant-api03-aB3dE5fG7hJ9kL1mN3pQ"]}`:                                       `{"args":["-c","run --x ••••"],"command":"sh"}`,
		`{"url":"https://h.io/mcp/eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.aB3dE5fG7hJ9kL"}`:                       `{"url":"https://h.io/mcp/••••"}`,
	} {
		if got := masked(in); got != want {
			t.Errorf("masked(%s)\n= %s\nwant %s", in, got, want)
		}
	}
}

func TestEditKeepsHiddenValuesOnlyForTheSameServer(t *testing.T) {
	old := `{"type":"http","url":"https://h.io/mcp?key=s1","headers":{"Authorization":"Bearer s2"},"headersHelper":"get s3",` +
		`"command":"srv --token s4","args":["--api-key","s5"],"env":{"K":"s6"}}`
	shown := masked(old)
	if got, err := unmasked(shown, old); err != nil || !reflect.DeepEqual(decoded(got), decoded(old)) {
		t.Errorf("sent back as shown: %s, %v", got, err)
	}
	// Each field changed, the hidden values kept: refused.
	for key, value := range map[string]any{
		"type": "sse", "url": "https://evil.io/mcp", "command": "evil", "args": []any{"-x"}, "headersHelper": "evil",
		"headers": map[string]any{"Authorization": Mask, "X": "y"}, "env": map[string]any{"K": Mask, "NODE_OPTIONS": "--require evil"},
		"timeout": 5.0,
	} {
		edit := decoded(shown)
		edit[key] = value
		b, _ := json.Marshal(edit)
		if got, err := unmasked(string(b), old); err == nil {
			t.Errorf("%s changed, hidden values kept: %s", key, got)
		}
	}
	// Everything typed again: fine.
	if _, err := unmasked(`{"type":"sse","url":"https://h.io/x","headers":{"A":"b"}}`, old); err != nil {
		t.Error(err)
	}
}

func decoded(s string) map[string]any {
	m, _ := decode(s)
	return m
}

func TestAChangeReachesTheChatsItAffects(t *testing.T) {
	folders := []string{"/r", "/r/sub", "/other", "/rx"}
	var reached []string
	svc := New("claude", &fakeConfig{}, func(_ string, affected func(string) bool) {
		reached = nil
		for _, f := range folders {
			if affected(f) {
				reached = append(reached, f)
			}
		}
	})
	ctx := context.Background()
	for scope, want := range map[string][]string{"user": folders, "local": {"/r", "/r/sub"}, "project": {"/r", "/r/sub"}} {
		if err := svc.Add(ctx, "/r", scope, "s", `{"command":"x"}`); err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(reached, want) {
			t.Errorf("%s: reached %v, want %v", scope, reached, want)
		}
	}
}

// folderConfig is a Config whose project servers count in the folder
// alone (PiG's .pig/mcp.json, not a parent's).
type folderConfig struct{ fakeConfig }

func (folderConfig) OwnFolderOnly() bool { return true }

// A project change of such an agent tells only the folder's chats, not
// its subfolders', which never read that file.
func TestAFolderOnlyChangeTellsTheFolder(t *testing.T) {
	var reached []string
	svc := New("pig", &folderConfig{}, func(_ string, affected func(string) bool) {
		for _, f := range []string{"/r", "/r/sub", "/rx"} {
			if affected(f) {
				reached = append(reached, f)
			}
		}
	})
	noErr(t, svc.Add(context.Background(), "/r", "project", "s", `{"command":"x"}`))
	if !reflect.DeepEqual(reached, []string{"/r"}) {
		t.Errorf("reached %v", reached)
	}
}

func noErr(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

// The app going away mid-edit doesn't stop it halfway (removed, not added).
func TestAnEditOutlivesTheApp(t *testing.T) {
	cfg := &fakeConfig{files: []model.MCPServer{{Name: "s", Scope: "user", Config: `{"command":"x"}`}}}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := New("claude", cfg, nil).Edit(ctx, "/repo", "user", "s", `{"command":"y"}`); err != nil {
		t.Fatal(err)
	}
	if want := []string{"remove s", `add s {"command":"y"}`}; !reflect.DeepEqual(cfg.calls, want) {
		t.Errorf("calls = %q", cfg.calls)
	}
}

// The check's state goes to the server of its name the Config left
// unshadowed, whatever its scope (the Config's rule picks it).
func TestTheCheckGoesToTheUnshadowedServer(t *testing.T) {
	svc := New("claude", &fakeConfig{files: []model.MCPServer{{Name: "github", Scope: "user"}, {Name: "github", Scope: "project", Shadowed: true}},
		checked: []model.MCPServer{{Name: "github", State: "connected"}}}, nil)
	got, _, _ := svc.List(context.Background(), "/f", true)
	if got[0].Shadowed || got[0].State != "connected" || !got[1].Shadowed || got[1].State == "connected" {
		t.Errorf("user %+v, project %+v", got[0], got[1])
	}
}

// SetOn goes by scope: project (also when no scope is given), user and
// local reach the config; any other scope is refused.
func TestSetOnGoesByScope(t *testing.T) {
	cfg := &fakeConfig{files: []model.MCPServer{{Name: "web", Scope: "user"}, {Name: "web", Scope: "local"}}}
	var reached []string
	svc := New("claude", cfg, func(_ string, affected func(string) bool) {
		for _, f := range []string{"/p", "/p/sub", "/q"} {
			if affected(f) {
				reached = append(reached, f)
			}
		}
	})
	ctx := context.Background()
	for _, scope := range []string{"", "user", "local"} {
		if err := svc.SetOn(ctx, "/p", scope, "web", false); err != nil {
			t.Fatal(err)
		}
	}
	for _, scope := range []string{"plugin", "claudeai", "other"} {
		if err := svc.SetOn(ctx, "/p", scope, "web", false); err == nil {
			t.Errorf("%s: not refused", scope)
		}
	}
	if err := svc.SetOn(ctx, "/p", "user", "nothere", true); err == nil {
		t.Error("a user server that isn't one: not refused")
	}
	if err := svc.SetOn(ctx, "/p", "user", "-x", true); err == nil {
		t.Error("a name like a flag: not refused")
	}
	if want := []string{"on project web false", "on user web false", "on local web false"}; !reflect.DeepEqual(cfg.calls, want) {
		t.Errorf("calls = %q", cfg.calls)
	}
	if want := []string{"/p", "/p/sub", "/p", "/p/sub", "/p", "/p/sub"}; !reflect.DeepEqual(reached, want) {
		t.Errorf("chats told = %q", reached) // the project's, not every folder's
	}
}

// scopedConfig is a Config whose check says each server's scope (PiG's).
type scopedConfig struct{ fakeConfig }

func (scopedConfig) ChecksByScope() bool { return true }

// A check that says each server's scope is matched by scope and name: a
// project entry the agent refused (its error, failed) doesn't take your
// server's state or hide yours; a server the check didn't report stays
// unchecked, not "Not in use here" (PiG's list ignores a project trusted
// only by defaultProjectTrust "always", which a session honours); one it
// reports for a name it hid stays hidden while the winner went
// unreported (that same "always").
func TestAScopedCheckMatchesByScopeAndName(t *testing.T) {
	svc := New("pig", &scopedConfig{fakeConfig{
		files: []model.MCPServer{{Name: "shared", Scope: "user", Shadowed: true}, {Name: "mine", Scope: "user"},
			{Name: "quiet", Scope: "user", Shadowed: true}, {Name: "shared", Scope: "project"},
			{Name: "proj", Scope: "project"}, {Name: "quiet", Scope: "project"}},
		checked: []model.MCPServer{{Name: "shared", Scope: "user", State: "failed", Detail: "closed"}, {Name: "mine", Scope: "user", State: "connected"},
			{Name: "shared", Scope: "project", State: "failed", Detail: "legacy SSE"}, {Name: "quiet", Scope: "user", State: "connected"}},
	}}, nil)
	got, _, err := svc.List(context.Background(), "/f", true)
	if err != nil {
		t.Fatal(err)
	}
	var says []string
	for _, g := range got {
		says = append(says, fmt.Sprintf("%s %s %s %q %v", g.Scope, g.Name, g.State, g.Detail, g.Shadowed))
	}
	want := []string{`user shared failed "closed" false`, `user mine connected "" false`, `user quiet  "" true`,
		`project shared failed "legacy SSE" false`, `project proj  "" false`, `project quiet  "" false`}
	if !reflect.DeepEqual(says, want) {
		t.Errorf("got\n%s\nwant\n%s", strings.Join(says, "\n"), strings.Join(want, "\n"))
	}
}

// A switch on yours that reaches everywhere (PiG's) tells every chat of
// the agent; one for the project (Claude's) only the project's.
func TestAnEverywhereSwitchTellsEveryChat(t *testing.T) {
	for reach, want := range map[model.Reach][]string{model.SwitchEverywhere: {"/p", "/p/sub", "/q"}, model.SwitchProject: {"/p", "/p/sub"}} {
		cfg := &fakeConfig{files: []model.MCPServer{{Name: "web", Scope: "user"}},
			shape: &model.MCPShape{Scopes: []string{"user", "project"}, Switch: true, UserSwitch: reach}}
		var reached []string
		svc := New("pig", cfg, func(_ string, affected func(string) bool) {
			for _, f := range []string{"/p", "/p/sub", "/q"} {
				if affected(f) {
					reached = append(reached, f)
				}
			}
		})
		if err := svc.SetOn(context.Background(), "/p", "user", "web", false); err != nil {
			t.Fatal(err)
		}
		if !reflect.DeepEqual(reached, want) {
			t.Errorf("%s: chats told = %q", reach, reached)
		}
	}
}

// A project server the agent doesn't load (the folder isn't trusted in
// it) never takes the check's state of its name, even listed first: the
// agent uses the other one.
func TestAnUntrustedServerIsntTheOneUsed(t *testing.T) {
	svc := New("pig", &fakeConfig{files: []model.MCPServer{{Name: "web", Scope: "project", Untrusted: true}, {Name: "web", Scope: "user"},
		{Name: "only", Scope: "project", Untrusted: true}},
		checked: []model.MCPServer{{Name: "web", State: "connected"}}}, nil)
	got, _, _ := svc.List(context.Background(), "/f", true)
	if got[0].State != "disabled" || got[1].State != "connected" || got[2].State != "disabled" {
		t.Errorf("project %+v, user %+v, only %+v", got[0], got[1], got[2])
	}
}

// An OAuth client's secret (PiG's oauth.clientSecret) is masked, and goes
// back only into the same server.
func TestAnOAuthSecretIsMaskedAndKept(t *testing.T) {
	old := `{"url":"https://h.io/mcp","oauth":{"clientId":"c","clientSecret":"s1","callbackPort":8765}}`
	shown := masked(old)
	if want := `{"oauth":{"callbackPort":8765,"clientId":"c","clientSecret":"••••"},"url":"https://h.io/mcp"}`; shown != want {
		t.Errorf("masked = %s, want %s", shown, want)
	}
	if got, err := unmasked(shown, old); err != nil || !reflect.DeepEqual(decoded(got), decoded(old)) {
		t.Errorf("sent back as shown: %s, %v", got, err)
	}
	for _, edit := range []string{
		`{"url":"https://evil.io/mcp","oauth":{"clientId":"c","clientSecret":"••••","callbackPort":8765}}`,
		`{"url":"https://h.io/mcp","oauth":{"clientId":"other","clientSecret":"••••","callbackPort":8765}}`,
	} {
		if got, err := unmasked(edit, old); err == nil {
			t.Errorf("changed, the secret kept: %s", got)
		}
	}
	if _, err := unmasked(`{"url":"https://h.io/mcp","oauth":{"clientSecret":"••••"}}`, `{"url":"https://h.io/mcp"}`); err == nil {
		t.Error("a secret that was never there: not refused")
	}
}

// User only is yours alone and nothing else of Claude's model: a switch
// or SSE on yours alone is more.
func TestShapeSaysUserOnly(t *testing.T) {
	for _, c := range []struct {
		shape model.MCPShape
		want  bool
	}{
		{model.MCPShape{Scopes: []string{"user"}}, true},
		{model.MCPShape{Scopes: []string{"user", "project"}}, false},
		{model.MCPShape{Scopes: []string{"user", "project", "local"}}, false},
		{model.MCPShape{Scopes: []string{"user"}, Switch: true}, false},
		{model.MCPShape{Scopes: []string{"user"}, SSE: true}, false},
		{model.MCPShape{Scopes: []string{"project"}}, false},
	} {
		if got := New("x", shaped{c.shape}, nil).UserOnly(); got != c.want {
			t.Errorf("%+v: user only %v", c.shape, got)
		}
	}
}

type shaped struct{ shape model.MCPShape }

func (s shaped) Servers(string) ([]model.MCPServer, error)                 { return nil, nil }
func (s shaped) Check(context.Context, string) ([]model.MCPServer, error)  { return nil, nil }
func (s shaped) Add(context.Context, string, string, string, string) error { return nil }
func (s shaped) Remove(context.Context, string, string, string) error      { return nil }
func (s shaped) Project(f string) string                                   { return f }
func (s shaped) SetOn(context.Context, string, string, string, bool) error { return nil }
func (s shaped) Login(context.Context, string, string) error               { return nil }
func (s shaped) Logout(context.Context, string, string) error              { return nil }
func (s shaped) Shape() model.MCPShape                                     { return s.shape }
func (s shaped) ChecksInFolder() bool                                      { return false }
