package codexskills

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"maps"
	"path/filepath"
	"reflect"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync"

	"github.com/BurntSushi/toml"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/jsonsettings"
)

// Codex's switch for a skill is a [[skills.config]] entry in its
// config.toml: `path = "<SKILL.md>"` (or `name = "<name>"`) and `enabled`.
// Nushi edits the file's text, as Codex's own skills/config/write does, so
// comments, order and everything else stay: off sets enabled = false on
// the skill's path entries (or adds one at the end), on removes them (or
// sets enabled = true on one with more in it, and adds one when a name
// entry would still keep the skill off). The result is decoded and
// compared with the change made to the decoded file; anything else (an
// inline array, a value Nushi can't read) is refused with "change it in
// config.toml". Only that list changes, and the file is replaced at once.

// configFile is Codex's config.toml.
func configFile() string { return filepath.Join(home(), "config.toml") }

// entry is one [[skills.config]] entry.
type entry struct {
	Path    *string `toml:"path"`
	Name    *string `toml:"name"`
	Enabled *bool   `toml:"enabled"`
}

// readEntries reads the [[skills.config]] entries of Codex's config.toml
// (none when there is no file).
func readEntries() ([]entry, error) {
	b, err := jsonsettings.ReadFile(configFile())
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	var cfg struct {
		Skills struct {
			Config []entry `toml:"config"`
		} `toml:"skills"`
	}
	if err == nil {
		_, err = toml.Decode(string(b), &cfg)
	}
	if err != nil {
		return nil, fmt.Errorf("Codex's config.toml doesn't read: %w", err)
	}
	return cfg.Skills.Config, nil
}

// enabled says whether a skill (its resolved SKILL.md, its name) is on:
// the last entry that names it decides; an entry with both selectors is
// ignored, as Codex ignores it.
func enabled(entries []entry, file, name string) bool {
	on := true
	for _, e := range entries {
		if e.Path != nil && e.Name != nil {
			continue
		}
		if e.Path != nil && realPath(*e.Path) == file || e.Name != nil && *e.Name == name {
			on = e.Enabled == nil || *e.Enabled
		}
	}
	return on
}

var (
	header   = regexp.MustCompile(`^\s*\[`)
	ourTable = regexp.MustCompile(`^\s*\[\[\s*skills\s*\.\s*config\s*\]\]\s*(#.*)?$`)
	keyLine  = regexp.MustCompile(`^(\s*)(path|name|enabled)\s*=`)
	boolWord = regexp.MustCompile(`=\s*(true|false)`)
)

// block is one [[skills.config]] table in the file's lines.
type block struct {
	start, end int // its header's line, and the line after its last
	path       string
	enabled    int  // its enabled line, or -1
	pathLine   int  // its path line, or -1
	simple     bool // nothing in it but path and enabled (and blank lines)
}

// blocks finds the [[skills.config]] tables in lines.
func blocks(lines []string) []block {
	var out []block
	for i := 0; i < len(lines); i++ {
		if !ourTable.MatchString(lines[i]) {
			continue
		}
		b := block{start: i, enabled: -1, pathLine: -1, simple: true}
		for b.end = i + 1; b.end < len(lines) && !header.MatchString(lines[b.end]); b.end++ {
			line := lines[b.end]
			m := keyLine.FindStringSubmatch(line)
			switch {
			case strings.TrimSpace(line) == "":
			case len(m) < 3 || m[2] == "name":
				b.simple = false
			case m[2] == "path":
				var v struct{ Path string }
				if _, err := toml.Decode(strings.TrimSpace(line), &v); err == nil {
					b.path, b.pathLine = realPath(v.Path), b.end
				} else {
					b.simple = false
				}
			case m[2] == "enabled":
				b.enabled = b.end
			}
		}
		out = append(out, b)
		i = b.end - 1
	}
	return out
}

// errUnsafe is the refusal when an edit can't be made safely.
func errUnsafe(why string) error {
	return fmt.Errorf("Nushi can't change this skill safely (%s): change it in config.toml", why)
}

// setMu is held from config.toml's read to its write, so two changes
// can't lose one another (Codex's own write still can: it doesn't ask).
var setMu sync.Mutex

// setOn turns the skill whose resolved SKILL.md is file (named name) on
// or off in the config.toml at path (a link followed: atomicfile.Rewrite).
func setOn(path, file, name string, on bool) error {
	setMu.Lock()
	defer setMu.Unlock()
	b, err := jsonsettings.ReadFile(path)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	before, err := decode(b)
	if err != nil {
		return errUnsafe(fmt.Sprintf("it doesn't read as TOML: %v", err))
	}
	after := edit(string(b), file, name, on)
	got, err := decode([]byte(after))
	if err != nil {
		return errUnsafe(fmt.Sprintf("the edit wouldn't read: %v", err))
	}
	if !only(before, got, file, name, on) {
		return errUnsafe("its skills.config isn't [[skills.config]] tables Nushi can edit")
	}
	return atomicfile.Rewrite(path, []byte(after))
}

// edit changes the file's text for the skill (file, name) going on or
// off: its path entries' enabled set (a plain one dropped for on), then
// an entry added at the end if the skill isn't yet as asked.
func edit(text, file, name string, on bool) string {
	lines := strings.SplitAfter(text, "\n")
	var drop []block
	for _, b := range slices.Backward(blocks(lines)) {
		switch {
		case b.path != file:
		case on && b.simple:
			drop = append(drop, b)
		case b.enabled >= 0:
			lines[b.enabled] = boolWord.ReplaceAllString(lines[b.enabled], "= "+strconv.FormatBool(on))
		default:
			indent := keyLine.FindStringSubmatch(lines[b.pathLine])[1]
			lines = slices.Insert(lines, b.pathLine+1, indent+"enabled = "+strconv.FormatBool(on)+"\n")
		}
	}
	for _, b := range drop { // last first, so the earlier lines stay where they were
		lines = slices.Delete(lines, b.start, b.end)
	}
	out := strings.Join(lines, "")
	if m, err := decode([]byte(out)); err == nil && enabled(entriesOf(m), file, name) != on {
		out = appendEntry(out, file, on)
	}
	return out
}

// appendEntry adds a [[skills.config]] table for file at the end.
func appendEntry(text, file string, on bool) string {
	var key bytes.Buffer
	_ = toml.NewEncoder(&key).Encode(map[string]string{"path": file}) // a string always encodes
	if text != "" && !strings.HasSuffix(text, "\n") {
		text += "\n"
	}
	if text != "" {
		text += "\n"
	}
	return text + "[[skills.config]]\n" + key.String() + "enabled = " + strconv.FormatBool(on) + "\n"
}

// decode reads TOML into plain values.
func decode(b []byte) (map[string]any, error) {
	m := map[string]any{}
	_, err := toml.Decode(string(b), &m)
	return m, err
}

// list is a decoded file's skills.config, as tables.
func list(m map[string]any) []map[string]any {
	skills, _ := m["skills"].(map[string]any)
	l, _ := skills["config"].([]map[string]any)
	return l
}

// entriesOf is a decoded file's [[skills.config]] entries.
func entriesOf(m map[string]any) []entry {
	var out []entry
	for _, raw := range list(m) {
		var e entry
		if p, ok := raw["path"].(string); ok {
			e.Path = &p
		}
		if n, ok := raw["name"].(string); ok {
			e.Name = &n
		}
		if v, ok := raw["enabled"].(bool); ok {
			e.Enabled = &v
		}
		out = append(out, e)
	}
	return out
}

// only says after is before with nothing changed but the skill's own path
// entries (each now enabled = on, or gone) and the skill now as asked.
func only(before, after map[string]any, file, name string, on bool) bool {
	rest := func(m map[string]any) (map[string]any, []map[string]any, []map[string]any) {
		out := maps.Clone(m)
		var others, ours []map[string]any
		if skills, ok := m["skills"].(map[string]any); ok {
			s := map[string]any{}
			for k, v := range skills {
				if k != "config" {
					s[k] = v
				}
			}
			delete(out, "skills")
			if len(s) > 0 {
				out["skills"] = s
			}
		}
		for _, e := range list(m) {
			if p, ok := e["path"].(string); ok && realPath(p) == file {
				ours = append(ours, e)
			} else {
				others = append(others, e)
			}
		}
		return out, others, ours
	}
	b, bOthers, bOurs := rest(before)
	a, aOthers, aOurs := rest(after)
	if !reflect.DeepEqual(a, b) || !reflect.DeepEqual(aOthers, bOthers) || len(aOurs) > len(bOurs)+1 {
		return false
	}
	for _, e := range aOurs {
		if v, ok := e["enabled"].(bool); !ok || v != on {
			return false
		}
	}
	return enabled(entriesOf(after), file, name) == on
}
