package opencodetrust

import (
	"encoding/json"
	"maps"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/tailscale/hujson"

	"github.com/afrase/nushi/internal/model"
)

// object is a JSON object of a config. A config is read as open JSON, not
// into a struct: encoding/json matches a struct's keys whatever their
// case and opencode only as written, so "Plugins": [] after "plugins"
// would hide a plugin from the summary; and a key of another shape than
// expected is skipped, hiding no other.
type object = map[string]any

// as is v when it is a T, else T's zero value.
func as[T any](v any) T {
	t, _ := v.(T)
	return t
}

// strs is the strings of the list v.
func strs(v any) []string {
	var out []string
	for _, e := range as[[]any](v) {
		if s, ok := e.(string); ok {
			out = append(out, s)
		}
	}
	return out
}

func sorted(o object) []string { return slices.Sorted(maps.Keys(o)) }

var (
	// shellLine is a command template's !`…`, which opencode runs in the
	// shell when the command is used.
	shellLine = regexp.MustCompile("!`([^`]+)`")
	// fileRef and envRef are what opencode puts a file's text or a
	// variable's value in place of, anywhere in a config's text, before
	// it parses it; a file's path may hold a variable.
	fileRef = regexp.MustCompile(`\{file:((?:\{env:[^}]+\}|[^}])+)\}`)
	envRef  = regexp.MustCompile(`\{env:([^}]+)\}`)
)

// configRuns is a summary of a config (the file itself shows whole below
// it): what it has opencode import, start, run, allow and copy in, in
// opencode 2's spelling and in opencode 1's, which opencode 2 still takes
// (docs/facts/opencode.md). The files and folders it names are named,
// never read.
func configRuns(path string, text []byte) []model.FolderRun {
	var out []model.FolderRun
	add := func(what string, lines ...string) {
		if lines = slices.DeleteFunc(lines, func(l string) bool { return l == "" }); len(lines) > 0 {
			out = append(out, model.FolderRun{File: path, What: what, Command: strings.Join(lines, "\n")})
		}
	}
	var c object
	std, err := hujson.Standardize(slices.Clone(text))
	if err == nil {
		err = json.Unmarshal(std, &c)
	}
	switch {
	case err != nil: // fixed words: the parser's own quote the file
		add("Settings Nushi couldn't read", "not a JSON object with comments: opencode may make more of it")
	case copiedName(c):
		add("Settings Nushi couldn't read", "a setting's name is copied from a file or a variable: it may be any setting")
	}
	for _, entry := range append(as[[]any](c["plugin"]), as[[]any](c["plugins"])...) {
		switch name := plugin(entry); {
		case name == "" || strings.HasPrefix(name, "-"): // "-name" takes a plugin away
		case strings.HasPrefix(name, "file://") || strings.HasPrefix(name, "./") || strings.HasPrefix(name, "../") || filepath.IsAbs(name):
			add("Plugin, imported at once", name)
		default:
			add("Plugin from npm, installed if missing and imported at once", name)
		}
	}
	// opencode 1 kept MCP servers in mcp itself, opencode 2 keeps them in
	// mcp.servers and takes both: a servers with a command is shown as
	// either.
	server := func(name string, s object) {
		add("MCP server "+name, strings.Join(strs(s["command"]), " "), as[string](s["url"]))
	}
	mcp := as[object](c["mcp"])
	for _, name := range sorted(mcp) {
		s := as[object](mcp[name])
		server(name, s)
		if name == "servers" {
			for _, in := range sorted(s) {
				server(in, as[object](s[in]))
			}
		}
	}
	add("Allowed without asking", allowed(c)...)
	for _, key := range []string{"agent", "mode", "agents"} {
		agents := as[object](c[key])
		for _, name := range sorted(agents) {
			add("Agent "+name+" allowed without asking", allowed(as[object](agents[name]))...)
		}
	}
	add("Shell that commands run in", as[string](c["shell"]))
	for _, kind := range [][2]string{{"formatter", "Formatter "}, {"lsp", "LSP server "}} {
		programs := as[object](c[kind[0]])
		for _, name := range sorted(programs) {
			add(kind[1]+name, strings.Join(strs(as[object](programs[name])["command"]), " "))
		}
	}
	for _, key := range []string{"command", "commands"} {
		commands := as[object](c[key])
		for _, name := range sorted(commands) {
			template := as[string](as[object](commands[name])["template"])
			lines := shellLines(template)
			if copied(template) { // whatever that file or variable holds
				lines = append(lines, template)
			}
			add("Command /"+name+" runs in the shell", lines...)
		}
	}
	add("Instructions read from", strs(c["instructions"])...)
	skills := as[object](c["skills"]) // a list, or opencode 1's {paths, urls}
	add("Skills read from", slices.Concat(strs(c["skills"]), strs(skills["paths"]), strs(skills["urls"]))...)
	add("Files copied into its settings", fileRefs(string(text))...)
	add("Environment variables copied into its settings", distinct(envRef.FindAllStringSubmatch(string(text), -1))...)
	return out
}

// commandRuns is what a command's Markdown runs in the shell when the
// command is used, to show above the file.
func commandRuns(path string, text []byte) []model.FolderRun {
	lines := shellLines(string(text))
	if len(lines) == 0 {
		return nil
	}
	return []model.FolderRun{{File: path, What: "Runs in the shell when the command is used", Command: strings.Join(lines, "\n")}}
}

func shellLines(template string) []string {
	var out []string
	for _, m := range shellLine.FindAllStringSubmatch(template, -1) {
		out = append(out, m[1])
	}
	return out
}

// plugin is the plugin an entry of plugins names: a string, {package}, or
// opencode 1's [name, options].
func plugin(entry any) string {
	switch e := entry.(type) {
	case object:
		return as[string](e["package"])
	case []any:
		if len(e) > 0 {
			return as[string](e[0])
		}
	}
	return as[string](entry)
}

// allowed is the rules of a config, or of one of its agents, that let a
// tool run without asking, each as "action resource": opencode 2's
// permissions, and opencode 1's tools and permission (one word for
// everything, or by action a word or a word by resource).
func allowed(g object) []string {
	var out []string
	for _, r := range as[[]any](g["permissions"]) {
		if r := as[object](r); allows(r["effect"]) {
			out = append(out, as[string](r["action"])+" "+as[string](r["resource"]))
		}
	}
	tools := as[object](g["tools"])
	for _, tool := range sorted(tools) {
		if as[bool](tools[tool]) {
			out = append(out, tool+" *")
		}
	}
	if allows(g["permission"]) {
		out = append(out, "* *")
	}
	byAction := as[object](g["permission"])
	for _, action := range sorted(byAction) {
		if allows(byAction[action]) {
			out = append(out, action+" *")
		}
		byResource := as[object](byAction[action])
		for _, resource := range sorted(byResource) {
			if allows(byResource[resource]) {
				out = append(out, action+" "+resource)
			}
		}
	}
	return out
}

// allows says whether a rule's effect is allow, or may be: one copied
// from a file or a variable is whatever that holds.
func allows(effect any) bool {
	word := as[string](effect)
	return word == "allow" || copied(word)
}

// copied says whether opencode puts a file's text or a variable's value
// into s before reading it.
func copied(s string) bool { return strings.Contains(s, "{file:") || strings.Contains(s, "{env:") }

// copiedName says whether a key anywhere in v is one opencode copies
// text into: "{file:k}", where k holds "plugins", is a key Nushi reads
// nothing from and opencode its plugins.
func copiedName(v any) bool {
	switch v := v.(type) {
	case object:
		for name, in := range v {
			if copied(name) || copiedName(in) {
				return true
			}
		}
	case []any:
		return slices.ContainsFunc(v, copiedName)
	}
	return false
}

// fileRefs is the paths text's {file:…} name, as written. opencode leaves
// alone one in a line comment.
func fileRefs(text string) []string {
	var found [][]string
	for _, m := range fileRef.FindAllStringSubmatchIndex(text, -1) {
		line := text[strings.LastIndexByte(text[:m[0]], '\n')+1 : m[0]]
		if !strings.HasPrefix(strings.TrimSpace(line), "//") {
			found = append(found, []string{"", text[m[2]:m[3]]})
		}
	}
	return distinct(found)
}

// distinct is the first group of each of matches, sorted, each once.
func distinct(matches [][]string) []string {
	var out []string
	for _, m := range matches {
		out = append(out, m[1])
	}
	slices.Sort(out)
	return slices.Compact(out)
}
