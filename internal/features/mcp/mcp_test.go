package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"reflect"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

type fakeConfig struct {
	files, checked []model.MCPServer
	calls          []string // "add <name> <config>", "remove <name>"
}

func (f *fakeConfig) Servers(string) ([]model.MCPServer, error) { return f.files, nil }
func (f *fakeConfig) Check(context.Context, string) ([]model.MCPServer, error) {
	return f.checked, nil
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
func (f *fakeConfig) Project(folder string) string                      { return folder }
func (f *fakeConfig) SetOn(context.Context, string, string, bool) error { return nil }
func (f *fakeConfig) Login(context.Context, string, string) error       { return nil }
func (f *fakeConfig) Logout(context.Context, string, string) error      { return nil }

func TestListMergesTheCheck(t *testing.T) {
	svc := New(&fakeConfig{
		files: []model.MCPServer{{Name: "a", Scope: "user", Config: `{"env":{"K":"secret"}}`}, {Name: "a", Scope: "local"},
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
	svc := New(cfg, func(affected func(string) bool) {
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

func TestRemoveRefusesWhatIsntAServer(t *testing.T) {
	cfg := &fakeConfig{}
	svc := New(cfg, nil)
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
		`{"command":"x","args":["-H","Authorization: Bearer t1","--header","X-Key: k2","Bearer t3","sh -c 'curl -H \"Authorization: Bearer t4\" --token t5 https://h.io/?aB3dE5fG7hJ9kL1mN3'"]}`: `{"args":["-H","Authorization: ••••","--header","X-Key: ••••","••••","sh -c 'curl -H \"Authorization: •••• Bearer •••• --token •••• https://h.io/?••••'"],"command":"x"}`,
		`{"command":"npx srv --password pw https://h.io/?k=v"}`:                                                                                                                                  `{"command":"npx srv --password •••• https://h.io/?k=••••"}`,
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
	svc := New(&fakeConfig{}, func(affected func(string) bool) {
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

// The app going away mid-edit doesn't stop it halfway (removed, not added).
func TestAnEditOutlivesTheApp(t *testing.T) {
	cfg := &fakeConfig{files: []model.MCPServer{{Name: "s", Scope: "user", Config: `{"command":"x"}`}}}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := New(cfg, nil).Edit(ctx, "/repo", "user", "s", `{"command":"y"}`); err != nil {
		t.Fatal(err)
	}
	if want := []string{"remove s", `add s {"command":"y"}`}; !reflect.DeepEqual(cfg.calls, want) {
		t.Errorf("calls = %q", cfg.calls)
	}
}

// A repository's .mcp.json server that isn't approved, or is off, gives way
// to the user's of the same name, which gets its state.
func TestAnUnapprovedProjectServerGivesWay(t *testing.T) {
	for _, project := range []model.MCPServer{{Name: "github", Scope: "project"}, {Name: "github", Scope: "project", Approved: true, Off: true}} {
		svc := New(&fakeConfig{files: []model.MCPServer{{Name: "github", Scope: "user"}, project},
			checked: []model.MCPServer{{Name: "github", State: "connected"}}}, nil)
		got, _, _ := svc.List(context.Background(), "/f", true)
		if got[0].Shadowed || got[0].State != "connected" || !got[1].Shadowed || got[1].State == "connected" {
			t.Errorf("%+v: user %+v, project %+v", project, got[0], got[1])
		}
	}
	svc := New(&fakeConfig{files: []model.MCPServer{{Name: "github", Scope: "user"}, {Name: "github", Scope: "project", Approved: true}}}, nil)
	if got, _, _ := svc.List(context.Background(), "/f", false); !got[0].Shadowed || got[1].Shadowed {
		t.Errorf("an approved project server: %+v", got)
	}
}
