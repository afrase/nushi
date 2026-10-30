// Derived from claude-agent-acp (https://github.com/agentclientprotocol/claude-agent-acp),
// v0.94.0, its "don't ask again" options' wording for files
// (dist/permissions/options/*.js).
// Copyright 2025 Zed Industries, Inc. and contributors. Licensed under the
// Apache License, Version 2.0 (see NOTICE). Modified: rewritten in Go for
// claudeacp, and the words come from the rules, never narrower than what
// they allow.

package claudeacp

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/afrase/nushi/claudeagent"
)

// The words of a file's "don't ask again" option (always.go), from the
// rules claude suggests: they never say less than the rules allow.

// grant is what file rules for the session allow: any file, or the
// files below one folder.
type grant struct {
	broad  bool   // a rule naming no path: any file
	rules  bool   // a rule at all, not only folders added
	folder string // the one folder the rules and the folders added reach
}

// readGrant reads updates as rules for tool (Read, or Edit with the
// folders write adds) for the session; not ok when they are anything
// else, a rule for a single file or a pattern, or reach more than one
// folder.
func readGrant(updates []claudeagent.PermissionUpdate, tool, cwd string, write bool) (g grant, ok bool) {
	var reached []string
	for _, u := range updates {
		switch {
		case u.Destination != claudeagent.DestinationSession:
			return g, false
		case u.Type == claudeagent.UpdateAddDirectories && write:
			reached = append(reached, u.Directories...)
		case u.Type == claudeagent.UpdateAddRules && u.Behavior == claudeagent.BehaviorAllow:
			for _, r := range u.Rules {
				content := strings.TrimSpace(r.RuleContent)
				switch {
				case r.ToolName != tool:
					return g, false
				case content == "":
					g.broad = true
				case strings.HasSuffix(content, "/**"):
					reached = append(reached, strings.TrimSuffix(content, "/**"))
				default:
					return g, false
				}
				g.rules = true
			}
		default:
			return g, false
		}
	}
	for _, d := range reached {
		if d = absIn(cwd, d); g.folder != "" && g.folder != d {
			return g, false
		}
		g.folder = d
	}
	return g, true
}

// fileLabel words claude's suggestions for reading (or, with write,
// editing) the file or folder at path ("" when the call names none) for
// the session, saying no less than they allow: any file (a rule naming
// no path) while the call is in the session's folder, or the one folder
// their rules and the folders they add reach, which must take in path.
// "" when the words can't say what they allow: rules for a single file
// or a pattern, more than one folder, a rule for any file outside the
// session's folder, rules kept past the session, or more than such rules
// and, for an edit, folders.
func fileLabel(updates []claudeagent.PermissionUpdate, path, cwd string, write bool) string {
	tool, anything := "Read", "Yes, during this session"
	if write {
		tool, anything = "Edit", "Yes, allow all edits during this session"
	}
	g, ok := readGrant(updates, tool, cwd, write)
	if !ok {
		return ""
	}
	abs := absIn(cwd, path)
	switch {
	case g.broad && (path == "" || inside(cwd, abs)):
		return anything
	case g.broad, !g.rules, path == "", !inside(g.folder, abs):
		return ""
	}
	home, _ := os.UserHomeDir()
	dir := filepath.Base(g.folder) + string(filepath.Separator)
	switch {
	case write && (g.folder == filepath.Join(cwd, ".claude") || home != "" && g.folder == filepath.Join(home, ".claude")):
		return "Yes, and allow Claude to edit its own settings for this session"
	case g.folder == cwd:
		return anything
	case write:
		return "Yes, allow all edits in " + dir + " during this session"
	}
	return "Yes, allow reading from " + dir + " during this session"
}

// absIn is path made absolute from cwd.
func absIn(cwd, path string) string {
	if filepath.IsAbs(path) {
		return filepath.Clean(path)
	}
	return filepath.Join(cwd, path)
}

// inside says whether path is dir or below it.
func inside(dir, path string) bool {
	rel, err := filepath.Rel(dir, path)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}
