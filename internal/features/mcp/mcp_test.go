package mcp

import (
	"context"
	"errors"
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
func (f *fakeConfig) Add(_ context.Context, _, _, name, config string) error {
	f.calls = append(f.calls, "add "+name+" "+config)
	if strings.Contains(config, "bad") {
		return errors.New("refused")
	}
	return nil
}
func (f *fakeConfig) Remove(_ context.Context, _, _, name string) error {
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
	if err := svc.Edit(ctx, "/repo", "local", "s", `{"command":"x","env":{"K":"••••","N":"new"}}`); err != nil {
		t.Fatal(err)
	}
	if err := svc.Edit(ctx, "/repo", "local", "s", `{"command":"y","env":{"K":"••••"}}`); err == nil {
		t.Fatal("a kept secret went to another command")
	}
	if err := svc.Edit(ctx, "/repo", "local", "s", `{"command":"bad"}`); err == nil {
		t.Fatal("a refused config should fail the edit")
	}
	want := []string{
		`remove s`, `add s {"command":"x","env":{"K":"secret","N":"new"}}`,
		`remove s`, `add s {"command":"bad"}`, `add s {"command":"x","env":{"K":"secret"}}`,
	}
	if strings.Join(cfg.calls, "\n") != strings.Join(want, "\n") {
		t.Errorf("calls:\n%s\nwant:\n%s", strings.Join(cfg.calls, "\n"), strings.Join(want, "\n"))
	}
	if strings.Join(notified, " ") != "/repo /repo/sub" {
		t.Errorf("notified %v, want the repo's chats once", notified)
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
		`{"url":"https://u:p@h.io/s/aB3dE5fG7hJ9kL1mN3/x?apiKey=k1&v=2#t","headers":{"A":"b"},"headersHelper":"get-token"}`:    `{"headers":{"A":"••••"},"headersHelper":"••••","url":"https://••••@h.io/s/••••/x?apiKey=••••\u0026v=••••#••••"}`,
		`{"url":"https://h.io/my-server-2024-edition/v1"}`:                                                                     `{"url":"https://h.io/my-server-2024-edition/v1"}`,
		`{"command":"docker","args":["run","-e","LOG=1","--api-key","sk-1","--token=t","GH_TOKEN=g","--port","80","plain=1"]}`: `{"args":["run","-e","LOG=••••","--api-key","••••","--token=••••","GH_TOKEN=••••","--port","80","plain=1"],"command":"docker"}`,
		`{"command":"npx srv --password pw https://h.io/?k=v"}`:                                                                `{"command":"npx srv --password •••• https://h.io/?k=••••"}`,
	} {
		if got := masked(in); got != want {
			t.Errorf("masked(%s)\n= %s\nwant %s", in, got, want)
		}
	}
}

func TestEditKeepsWhatWasShownMasked(t *testing.T) {
	old := `{"url":"https://h.io/mcp?key=s1","headers":{"Authorization":"Bearer s2"}}`
	shown := masked(old)
	if got, err := unmasked(shown, old); err != nil || got != `{"headers":{"Authorization":"Bearer s2"},"url":"https://h.io/mcp?key=s1"}` {
		t.Errorf("sent back as shown: %s, %v", got, err)
	}
	for _, edit := range []string{
		`{"url":"https://evil.io/mcp?key=••••","headers":{"Authorization":"••••"}}`, // the URL's hidden part elsewhere
		`{"url":"https://evil.io/mcp","headers":{"Authorization":"••••"}}`,          // the header elsewhere
	} {
		if got, err := unmasked(edit, old); err == nil {
			t.Errorf("unmasked(%s) = %s: a kept secret went to a new URL", edit, got)
		}
	}
	if got, err := unmasked(`{"url":"https://h.io/mcp?key=s1","headers":{"Authorization":"••••","X":"y"}}`, old); err != nil ||
		!strings.Contains(got, "Bearer s2") {
		t.Errorf("same URL, header kept: %s, %v", got, err)
	}
}
