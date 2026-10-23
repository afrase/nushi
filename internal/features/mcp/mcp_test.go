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
	if err := svc.Edit(ctx, "/repo", "local", "s", `{"command":"y","env":{"K":"••••","N":"new"}}`); err != nil {
		t.Fatal(err)
	}
	if err := svc.Edit(ctx, "/repo", "local", "s", `{"command":"bad"}`); err == nil {
		t.Fatal("a refused config should fail the edit")
	}
	want := []string{
		`remove s`, `add s {"command":"y","env":{"K":"secret","N":"new"}}`,
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
