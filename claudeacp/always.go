// Derived from claude-agent-acp (https://github.com/agentclientprotocol/claude-agent-acp),
// v0.94.0, its "don't ask again" options and their wording
// (dist/permissions/options/*.js, normalization.js, effects.js).
// Copyright 2025 Zed Industries, Inc. and contributors. Licensed under the
// Apache License, Version 2.0 (see NOTICE). Modified: rewritten in Go for
// claudeacp, and an option whose rules would change the session's mode is
// never offered.

package claudeacp

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/afrase/nushi/claudeagent"
)

// The "don't ask again" options of a permission request, worded as
// claude's terminal words them, each with the rules claude gets when it
// is picked: claude's own suggestions where the wording can say what they
// do, else rules made here for the tool (a fetch's domain, a skill, any
// use of a tool without rules of its own). None is offered when a rule of
// the user's asks each time, or when the rules would change the session's
// mode (claude suggests acceptEdits for a write outside the session's
// folder): the user is asked about the call, not the mode.

// The ids of the options a skill adds to optAllowAlways.
const (
	optSkillExact  = "allow-skill-exact"
	optSkillPrefix = "allow-skill-prefix"
)

// always is a "don't ask again" option: its id and words, and the rules
// it gives claude.
type always struct {
	id, name string
	updates  []claudeagent.PermissionUpdate
}

// offers are the "don't ask again" options of a request.
type offers []always

// add offers a "don't ask again" named name (none when it is "") with
// updates, unless they would change the session's mode.
func (o *offers) add(id, name string, updates []claudeagent.PermissionUpdate) {
	if name != "" && len(updates) > 0 && !changesMode(updates) {
		*o = append(*o, always{id, name, updates})
	}
}

// alwaysOptions are r's "don't ask again" options; cwd is the session's
// folder.
func alwaysOptions(r claudeagent.PermissionRequest, cwd string) offers {
	if r.MatchedAskRule || r.SuppressAlwaysAllowRule {
		return nil
	}
	var in struct {
		URL      string `json:"url"`
		Skill    string `json:"skill"`
		Host     string `json:"host"`
		FilePath string `json:"file_path"`
		Path     string `json:"path"`
		Notebook string `json:"notebook_path"`
	}
	_ = json.Unmarshal(r.Input, &in)
	sugg := suggested(r.Suggestions)
	label := cmpTrim(r.DisplayName, r.ToolName)
	var out offers
	switch tool := r.ToolName; {
	case strings.HasPrefix(tool, "mcp__computer-use__"):
		if mcpAllows(sugg, tool) {
			out.add(optAllowAlways, "Yes, and don't ask again for "+label, sugg)
		}
	case strings.HasPrefix(tool, "mcp__"):
		if mcpAllows(sugg, tool) {
			out.add(optAllowAlways, "Yes, and don't ask again for "+label+" commands", sugg)
		}
	case tool == "Bash", tool == "PowerShell":
		out.add(optAllowAlways, shellLabel(tool, sugg), sugg)
	case tool == "Read":
		out.add(optAllowAlways, fileLabel(sugg, in.FilePath, cwd, false), sugg)
	case tool == "Glob", tool == "Grep":
		out.add(optAllowAlways, fileLabel(sugg, cmpTrim(in.Path, cwd), cwd, false), sugg)
	case tool == "Edit", tool == "Write":
		out.add(optAllowAlways, fileLabel(sugg, in.FilePath, cwd, true), sugg)
	case tool == "NotebookEdit":
		out.add(optAllowAlways, fileLabel(sugg, in.Notebook, cwd, true), sugg)
	case tool == "WebFetch":
		if u, err := url.Parse(strings.TrimSpace(in.URL)); err == nil && u.Hostname() != "" {
			host := strings.ToLower(u.Hostname())
			out.add(optAllowAlways, "Yes, and don't ask again for "+host, localRule("WebFetch", "domain:"+host))
		}
	case tool == "Skill":
		skill := strings.TrimSpace(in.Skill)
		if skill == "" || len(skill) > 1000 {
			break
		}
		out.add(optSkillExact, "Yes, and don't ask again for "+skill, localRule("Skill", skill))
		if name, _, ok := strings.Cut(skill, " "); ok && name != "" {
			out.add(optSkillPrefix, "Yes, and don't ask again for "+name+":* commands", localRule("Skill", name+":*"))
		}
	case tool == "SandboxNetworkAccess":
		if host := strings.TrimSpace(in.Host); host != "" && exactLocalRule(sugg, tool, host) {
			out.add(optAllowAlways, "Yes, and don't ask again for "+host, sugg)
		}
	default: // WebSearch, Agent and the rest: any use of the tool
		out.add(optAllowAlways, "Yes, and don't ask again for "+label+" commands", localRule(tool, ""))
	}
	return out
}

// cmpTrim is s trimmed, else or.
func cmpTrim(s, or string) string {
	if s = strings.TrimSpace(s); s != "" {
		return s
	}
	return or
}

// localRule is a rule allowing tool (with content, when given) kept in
// the project's local settings.
func localRule(tool, content string) []claudeagent.PermissionUpdate {
	return []claudeagent.PermissionUpdate{{Type: "addRules", Behavior: "allow", Destination: "localSettings",
		Rules: []claudeagent.PermissionRule{{ToolName: tool, RuleContent: content}}}}
}

// changesMode says whether updates set the session's mode.
func changesMode(updates []claudeagent.PermissionUpdate) bool {
	return slices.ContainsFunc(updates, func(u claudeagent.PermissionUpdate) bool { return u.Type == "setMode" })
}

// suggested is claude's suggestions when they are all updates claude
// knows, within bounds; else none, as no wording can be trusted to say
// what they do.
func suggested(us []claudeagent.PermissionUpdate) []claudeagent.PermissionUpdate {
	if len(us) == 0 || len(us) > 100 {
		return nil
	}
	for _, u := range us {
		if !known(u) {
			return nil
		}
	}
	return us
}

// known says whether u is an update of a kind claude takes, well formed.
func known(u claudeagent.PermissionUpdate) bool {
	switch u.Destination {
	case "session", "cliArg", "userSettings", "projectSettings", "localSettings":
	default:
		return false
	}
	switch u.Type {
	case "addRules", "replaceRules", "removeRules":
		if len(u.Rules) > 100 || u.Type != "replaceRules" && len(u.Rules) == 0 {
			return false
		}
		for _, r := range u.Rules {
			if !plain(r.ToolName, 512) || r.RuleContent != "" && !plain(r.RuleContent, 10_000) {
				return false
			}
		}
		return u.Behavior == "allow" || u.Behavior == "deny" || u.Behavior == "ask"
	case "setMode":
		switch u.Mode {
		case "default", "acceptEdits", "bypassPermissions", "plan", "dontAsk", "auto":
			return true
		}
		return false
	case "addDirectories", "removeDirectories":
		if len(u.Directories) == 0 || len(u.Directories) > 100 {
			return false
		}
		for _, d := range u.Directories {
			if !plain(d, 4096) {
				return false
			}
		}
		return true
	}
	return false
}

// plain says whether s is text worth showing: not blank, at most max
// bytes, and no control characters but tabs and line breaks.
func plain(s string, maxLen int) bool {
	if strings.TrimSpace(s) == "" || len(s) > maxLen {
		return false
	}
	return !strings.ContainsFunc(strings.TrimSpace(s), func(c rune) bool {
		return c < 0x20 && c != '\t' && c != '\n' && c != '\r' || c == 0x7f
	})
}

// mcpAllows says whether updates only allow every use of the MCP tool
// asked about: what "don't ask again" for it can truthfully say.
func mcpAllows(updates []claudeagent.PermissionUpdate, tool string) bool {
	if len(updates) == 0 {
		return false
	}
	for _, u := range updates {
		if u.Type != "addRules" || u.Behavior != "allow" || len(u.Rules) == 0 {
			return false
		}
		for _, r := range u.Rules {
			if r.ToolName != tool || r.RuleContent != "" {
				return false
			}
		}
	}
	return true
}

// exactLocalRule says whether updates are just one local rule allowing
// tool for content.
func exactLocalRule(updates []claudeagent.PermissionUpdate, tool, content string) bool {
	if len(updates) != 1 {
		return false
	}
	u := updates[0]
	return u.Type == "addRules" && u.Behavior == "allow" && u.Destination == "localSettings" && len(u.Rules) == 1 &&
		u.Rules[0].ToolName == tool && strings.TrimSpace(u.Rules[0].RuleContent) == content
}

// shellLabel words claude's suggestions for a command, as claude's
// terminal does: commands allowed (a prefix rule's "x:*" said as x),
// folders reached for the session, files read. "" when they do anything
// else, which the words couldn't say.
func shellLabel(tool string, updates []claudeagent.PermissionUpdate) string {
	var commands, reads, dirs []string
	for _, u := range updates {
		switch {
		case u.Type == "addDirectories" && u.Destination == "session":
			dirs = append(dirs, u.Directories...)
		case u.Type == "addRules" && u.Behavior == "allow":
			for _, r := range u.Rules {
				content := strings.TrimSpace(r.RuleContent)
				switch {
				case content == "", r.ToolName != tool && r.ToolName != "Read":
					return ""
				case r.ToolName == "Read":
					reads = append(reads, strings.TrimSuffix(r.RuleContent, "/**"))
				case !slices.Contains(commands, strings.TrimSuffix(r.RuleContent, ":*")):
					commands = append(commands, strings.TrimSuffix(r.RuleContent, ":*"))
				}
			}
		default:
			return ""
		}
	}
	paths := append(slices.Clip(dirs), reads...)
	switch {
	case len(paths) == 0 && len(commands) > 0:
		return "Yes, and don't ask again for " + enumerate(commands) + " commands"
	case len(paths) == 0:
		return ""
	case len(reads) > 0 && len(dirs) == 0 && len(commands) == 0:
		return "Yes, allow reading from " + shortPaths(reads) + " from this project"
	case len(commands) == 0:
		return "Yes, and always allow access to " + shortPaths(paths) + " from this project"
	case len(paths) == 1 && len(commands) == 1:
		return "Yes, and allow access to " + shortPaths(paths) + " and " + enumerate(commands) + " commands"
	}
	return "Yes, and allow " + shortPaths(paths) + " access and " + enumerate(commands) + " commands"
}

// enumerate is items as a sentence lists them ("a, b, and c"), or
// "similar" when that runs past 50 characters.
func enumerate(items []string) string {
	switch {
	case len(strings.Join(items, ", ")) > 50:
		return "similar"
	case len(items) == 1:
		return items[0]
	case len(items) == 2:
		return items[0] + " and " + items[1]
	}
	return strings.Join(items[:len(items)-1], ", ") + ", and " + items[len(items)-1]
}

// shortPaths names folders as briefly as tells them apart, each ending
// in a slash: their last parts, more where two share them; two at most,
// the rest counted.
func shortPaths(paths []string) string {
	var clean []string
	for _, p := range paths {
		if p = filepath.Clean(p); !slices.Contains(clean, p) {
			clean = append(clean, p)
		}
	}
	parts := make([][]string, len(clean))
	for i, p := range clean {
		parts[i] = slices.DeleteFunc(strings.Split(p, string(filepath.Separator)), func(s string) bool { return s == "" })
	}
	tail := func(i, depth int) string {
		if s := filepath.Join(parts[i][max(len(parts[i])-depth, 0):]...); s != "" {
			return s
		}
		return clean[i]
	}
	names := make([]string, len(clean))
	for i, p := range clean {
		name := filepath.Base(p)
		for depth := 1; depth <= len(parts[i]); depth++ {
			unique := true
			for j := range clean {
				if j != i && tail(j, depth) == tail(i, depth) {
					unique = false
				}
			}
			if unique {
				name = tail(i, depth)
				break
			}
			if depth == len(parts[i]) {
				name = p
			}
		}
		if !strings.HasSuffix(name, string(filepath.Separator)) {
			name += string(filepath.Separator)
		}
		names[i] = name
	}
	if len(names) <= 2 {
		return enumerate(names)
	}
	return fmt.Sprintf("%s, %s and %d more", names[0], names[1], len(names)-2)
}

// fileLabel words claude's suggestions for reading (or, with write,
// editing) the file or folder at path ("" when the call names none) for
// the session: what they allow must take in path. "" when they don't, or
// do more than allow such rules or, for an edit, reach folders.
func fileLabel(updates []claudeagent.PermissionUpdate, path, cwd string, write bool) string {
	tool := "Read"
	if write {
		tool = "Edit"
	}
	if len(updates) == 0 {
		return ""
	}
	broad, rules := false, false
	var reach []string // the folders the rules and folders added reach
	for _, u := range updates {
		switch {
		case u.Destination != "session":
			return ""
		case u.Type == "addDirectories" && write:
			reach = append(reach, u.Directories...)
		case u.Type == "addRules" && u.Behavior == "allow":
			rules = true
			for _, r := range u.Rules {
				switch {
				case r.ToolName != tool:
					return ""
				case strings.TrimSpace(r.RuleContent) == "":
					broad = true
				default:
					reach = append(reach, strings.TrimSuffix(strings.TrimSpace(r.RuleContent), "/**"))
				}
			}
		default:
			return ""
		}
	}
	if path == "" {
		if !broad {
			return ""
		}
		if write {
			return "Yes, allow all edits during this session"
		}
		return "Yes, during this session"
	}
	abs := absIn(cwd, path)
	if !broad && !slices.ContainsFunc(reach, func(d string) bool {
		d = absIn(cwd, d)
		return d == filepath.Dir(abs) || inside(d, abs)
	}) {
		return ""
	}
	home, _ := os.UserHomeDir()
	ownSettings := write && rules && (inside(filepath.Join(cwd, ".claude"), abs) || home != "" && inside(filepath.Join(home, ".claude"), abs))
	switch dir := filepath.Base(filepath.Dir(abs)); {
	case ownSettings:
		return "Yes, and allow Claude to edit its own settings for this session"
	case inside(cwd, abs) && write:
		return "Yes, allow all edits during this session"
	case inside(cwd, abs):
		return "Yes, during this session"
	case write:
		return "Yes, allow all edits in " + dir + string(filepath.Separator) + " during this session"
	default:
		return "Yes, allow reading from " + dir + string(filepath.Separator) + " during this session"
	}
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
