package claudemcp

import "github.com/afrase/nushi/internal/model"

// rank orders the scopes Read gives as Claude Code picks between servers
// of the same name: local wins, then project, then user.
var rank = map[string]int{"local": 0, "project": 1, "user": 2}

// order is a server's place among those of its name: as its scope ranks,
// except that a project server that is off or not approved gives way to a
// local or user one (Claude Code 2.1.309 skips it then).
func order(sv model.MCPServer) int {
	if sv.Scope == "project" && (sv.Off || !sv.Approved) {
		return 2*rank["user"] + 1
	}
	return 2 * rank[sv.Scope]
}

// shadow marks Shadowed on each server another of its name wins over, and
// returns servers.
func shadow(servers []model.MCPServer) []model.MCPServer {
	used := map[string]int{} // the server Claude uses, by name
	for i, sv := range servers {
		if j, ok := used[sv.Name]; !ok || order(sv) < order(servers[j]) {
			used[sv.Name] = i
		}
	}
	for i := range servers {
		servers[i].Shadowed = used[servers[i].Name] != i
	}
	return servers
}
