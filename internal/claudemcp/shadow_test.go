package claudemcp

import (
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// Of servers of one name, local wins, then project, then user; a project
// server that isn't approved, or is off, gives way to a user one.
func TestShadowGoesByClaudesOrder(t *testing.T) {
	for _, c := range []struct {
		name    string
		servers []model.MCPServer
		used    int
	}{
		{"local over user", []model.MCPServer{{Name: "a", Scope: "user"}, {Name: "a", Scope: "local"}}, 1},
		{"local over project", []model.MCPServer{{Name: "a", Scope: "local"}, {Name: "a", Scope: "project", Approved: true}}, 0},
		{"approved project over user", []model.MCPServer{{Name: "a", Scope: "user"}, {Name: "a", Scope: "project", Approved: true}}, 1},
		{"unapproved project gives way", []model.MCPServer{{Name: "a", Scope: "user"}, {Name: "a", Scope: "project"}}, 0},
		{"project that's off gives way", []model.MCPServer{{Name: "a", Scope: "user"}, {Name: "a", Scope: "project", Approved: true, Off: true}}, 0},
	} {
		got := shadow(c.servers)
		for i, sv := range got {
			if sv.Shadowed != (i != c.used) {
				t.Errorf("%s: server %d (%s) shadowed = %v", c.name, i, sv.Scope, sv.Shadowed)
			}
		}
	}
	if got := shadow([]model.MCPServer{{Name: "a", Scope: "user"}, {Name: "b", Scope: "local"}}); got[0].Shadowed || got[1].Shadowed {
		t.Errorf("servers of different names: %+v", got)
	}
}
