package ompskills

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"maps"
	"os"
	"path"
	"path/filepath"
	"reflect"
	"slices"
	"sync"

	"gopkg.in/yaml.v3"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/omp"
)

// omp's settings are YAML: your <agent dir>/config.yml, and the
// project's nearest .omp/config.yml over it. Nushi changes only your
// disabledExtensions list, and only in a file yaml.v3 writes back exactly
// as it read it (comments and layout included): anything else is refused
// with "change it in config.yml".

func userConfig() string { return filepath.Join(omp.AgentDir(), "config.yml") }

// config is your settings and the project's.
type config struct {
	project, user         map[string]any
	projectPath, userPath string
}

// readConfig reads your config.yml and the project's: the nearest .omp
// folder's, from the folder up to the repository's root.
func readConfig(folder string) (config, error) {
	c := config{userPath: userConfig()}
	var errs []error
	c.user, errs = readYAML(c.userPath, errs)
	for _, d := range walk(folder) {
		if fi, err := os.Stat(filepath.Join(d, ".omp")); err == nil && fi.IsDir() {
			c.projectPath = filepath.Join(d, ".omp", "config.yml")
			c.project, errs = readYAML(c.projectPath, errs)
			break
		}
	}
	return c, errors.Join(errs...)
}

func readYAML(file string, errs []error) (map[string]any, []error) {
	m := map[string]any{}
	b, err := jsonsettings.ReadFile(file)
	if err == nil {
		err = yaml.Unmarshal(b, &m)
	}
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		errs = append(errs, fmt.Errorf("%s doesn't read: %w", file, err))
	}
	return m, errs
}

// skills is a file's skills settings.
func skills(m map[string]any) map[string]any {
	s, _ := m["skills"].(map[string]any)
	return s
}

// on is a skills.<key> switch, the project's over yours.
func (c config) on(key string, def bool) bool {
	for _, m := range []map[string]any{c.project, c.user} {
		if v, ok := skills(m)[key].(bool); ok {
			return v
		}
	}
	return def
}

// off says omp leaves the skill named name out, and the file that does
// when it isn't your disabledExtensions.
func (c config) off(name string) (bool, string) {
	for _, f := range []struct {
		m    map[string]any
		path string
	}{{c.project, c.projectPath}, {c.user, c.userPath}} {
		if v, ok := skills(f.m)["enabled"].(bool); ok && !v {
			return true, f.path
		}
		list, _ := f.m["disabledExtensions"].([]any)
		if slices.Contains(list, any("skill:"+name)) {
			if f.path == c.userPath {
				return true, ""
			}
			return true, f.path
		}
		globs, _ := skills(f.m)["ignoredSkills"].([]any)
		for _, g := range globs {
			if s, ok := g.(string); ok {
				if m, _ := path.Match(s, name); m {
					return true, f.path
				}
			}
		}
	}
	return false, ""
}

// encode writes doc as yaml.v3 does, two spaces a level.
func encode(doc *yaml.Node) ([]byte, error) {
	var b bytes.Buffer
	e := yaml.NewEncoder(&b)
	e.SetIndent(2)
	if err := e.Encode(doc); err != nil {
		return nil, err
	}
	return b.Bytes(), e.Close()
}

func errUnsafe(why string) error {
	return fmt.Errorf("Nushi can't change omp's settings safely (%s): change it in config.yml", why)
}

// setMu is held from config.yml's read to its write, so two changes can't
// lose one another (omp's own write still can: it doesn't ask).
var setMu sync.Mutex

// setDisabled adds item to (or takes it out of) disabledExtensions in the
// config.yml at file (a link followed: atomicfile.Rewrite).
func setDisabled(file, item string, add bool) error {
	setMu.Lock()
	defer setMu.Unlock()
	b, err := jsonsettings.ReadFile(file)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	var doc yaml.Node
	if len(bytes.TrimSpace(b)) > 0 {
		if err := yaml.Unmarshal(b, &doc); err != nil {
			return errUnsafe(err.Error())
		}
		if again, err := encode(&doc); err != nil || !bytes.Equal(again, b) {
			return errUnsafe("it wouldn't be written back as it is")
		}
	} else {
		doc = yaml.Node{Kind: yaml.DocumentNode, Content: []*yaml.Node{{Kind: yaml.MappingNode, Tag: "!!map"}}}
	}
	top := doc.Content[0]
	if top.Kind != yaml.MappingNode {
		return errUnsafe("it isn't a map")
	}
	i := slices.IndexFunc(top.Content, func(n *yaml.Node) bool { return n.Value == "disabledExtensions" })
	if i%2 == 1 {
		return errUnsafe("disabledExtensions isn't a key")
	}
	if i < 0 {
		top.Content = append(top.Content, &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: "disabledExtensions"},
			&yaml.Node{Kind: yaml.SequenceNode, Tag: "!!seq"})
		i = len(top.Content) - 2
	}
	seq := top.Content[i+1]
	if seq.Kind != yaml.SequenceNode {
		return errUnsafe("disabledExtensions isn't a list")
	}
	seq.Content = slices.DeleteFunc(seq.Content, func(n *yaml.Node) bool { return n.Kind == yaml.ScalarNode && n.Value == item })
	if add {
		seq.Content = append(seq.Content, &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: item})
		seq.Style = 0 // a block list for a new item, as omp writes
	}
	if len(seq.Content) == 0 {
		top.Content = slices.Delete(top.Content, i, i+2)
	}
	out, err := encode(&doc)
	if err != nil {
		return err
	}
	if !only(b, out, item, add) {
		return errUnsafe("more than disabledExtensions would change")
	}
	return atomicfile.Rewrite(file, out)
}

// only says after decodes to before with item added to or taken out of
// disabledExtensions, and nothing else changed.
func only(before, after []byte, item string, add bool) bool {
	b, a := map[string]any{}, map[string]any{}
	if yaml.Unmarshal(before, &b) != nil || yaml.Unmarshal(after, &a) != nil {
		return false
	}
	list, _ := b["disabledExtensions"].([]any)
	list = slices.DeleteFunc(slices.Clone(list), func(v any) bool { return v == item })
	if add {
		list = append(list, item)
	}
	want := maps.Clone(b)
	delete(want, "disabledExtensions")
	if len(list) > 0 {
		want["disabledExtensions"] = list
	}
	return reflect.DeepEqual(a, want)
}
