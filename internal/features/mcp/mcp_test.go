package mcp

import (
	"context"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

type fakeConfig struct{ files, checked []model.MCPServer }

func (f fakeConfig) Servers(string) ([]model.MCPServer, error) { return f.files, nil }
func (f fakeConfig) Check(context.Context, string) ([]model.MCPServer, error) {
	return f.checked, nil
}

func TestListMergesTheCheck(t *testing.T) {
	svc := New(fakeConfig{
		files: []model.MCPServer{{Name: "a", Scope: "user"}, {Name: "a", Scope: "local"}, {Name: "gone", Scope: "project"}},
		checked: []model.MCPServer{{Name: "a", State: "connected"}, {Name: "plugin:x:y", Scope: "plugin", State: "failed"},
			{Name: "managed", State: "connected"}},
	})
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
}
