package claudemcp

import (
	"encoding/json"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// parseList reads `claude mcp list`, which has no JSON form: a line per
// server, "<name>: <command or URL> - <status>", where a plugin's server is
// named "plugin:<plugin>:<server>" and a claude.ai connector "claude.ai
// <name>". A line it can't read is skipped, and a status it doesn't know
// is "unknown", with Claude's words as its detail.
func parseList(out string) []model.MCPServer {
	var list []model.MCPServer
	for line := range strings.SplitSeq(out, "\n") {
		name, rest, ok := strings.Cut(strings.TrimSpace(line), ": ")
		i := statusAt(rest)
		if !ok || i < 0 {
			continue
		}
		s := model.MCPServer{Name: name, Config: targetConfig(strings.TrimSpace(rest[:i]))}
		s.State, s.Detail = state(strings.TrimSpace(rest[i+3:]))
		switch {
		case strings.HasPrefix(name, "plugin:"):
			s.Scope = "plugin"
		case strings.HasPrefix(name, "claude.ai "):
			s.Scope = "claudeai"
		}
		list = append(list, s)
	}
	return list
}

// statusAt finds the " - " before the status: the first one followed by a
// status mark or word (a command can hold " - " too), else the last.
func statusAt(rest string) int {
	last := -1
	for i := 0; ; {
		j := strings.Index(rest[i:], " - ")
		if j < 0 {
			return last
		}
		last = i + j
		after := strings.TrimLeft(rest[last+3:], "✔✓✘✗!⏸⊘⚠ ")
		for _, w := range []string{"Connected", "Failed", "Needs", "Pending", "Disabled", "Rejected", "Connection"} {
			if strings.HasPrefix(after, w) {
				return last
			}
		}
		i = last + 3
	}
}

// state reads a status ("✔ Connected", "✘ Failed to connect — why").
func state(status string) (state, detail string) {
	words := strings.ToLower(status)
	_, why, _ := strings.Cut(status, "—")
	why = strings.TrimSpace(why)
	switch {
	case strings.Contains(words, "needs auth"):
		return "needs_auth", ""
	case strings.Contains(words, "pending approval"):
		return "pending", ""
	case strings.Contains(words, "disabled"), strings.Contains(words, "rejected"):
		return "disabled", why
	case strings.Contains(words, "failed"), strings.Contains(words, "error"):
		return "failed", why
	case strings.Contains(words, "connected"):
		return "connected", ""
	}
	return "unknown", status
}

// targetConfig is the config of a server Claude alone knows, from what the
// list shows of it: "https://… (HTTP)", a bare URL (a claude.ai
// connector), or a command line.
func targetConfig(target string) string {
	cfg := map[string]string{"command": target}
	if open := strings.LastIndex(target, " ("); open > 0 && strings.HasSuffix(target, ")") {
		cfg = map[string]string{"type": strings.ToLower(target[open+2 : len(target)-1]), "url": target[:open]}
	} else if strings.HasPrefix(target, "https://") || strings.HasPrefix(target, "http://") {
		cfg = map[string]string{"type": "http", "url": target}
	}
	b, _ := json.Marshal(cfg)
	return string(b)
}
