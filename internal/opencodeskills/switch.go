package opencodeskills

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"maps"
	"os"
	"reflect"
	"slices"
	"strings"
	"sync"

	"github.com/tailscale/hujson"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/jsonsettings"
)

// opencode's one switch for a skill is a policy in the global config
// (docs/facts/opencode.md). Nushi turns a skill off by adding the entry
// below as the last of "policies" in the first global file opencode
// reads (opencode.json, else an opencode.jsonc that is there), where it
// decides whatever else the files say; and on by taking its own entries
// for the id out of both. The file's text is changed in place (edit.go):
// nothing is written again but the entry, so comments, order and layout
// stay, and turning a skill off and on leaves the file as it was.

// entry is the policy that turns the skill id off, as Nushi writes it.
func entry(id string) string {
	q, _ := json.Marshal(id)
	return `{"action": "skill.use", "resource": ` + string(q) + `, "effect": "deny"}`
}

// SetSkillOn turns a skill off by its id in your global config's policies
// (wherever it comes from, in every folder), or on by taking that entry
// out; refused where a policy Nushi didn't write decides, and while a
// global config file doesn't read.
func (o OpenCode) SetSkillOn(ctx context.Context, folder, source, name string, on bool) error {
	l, _ := o.List(ctx, folder)
	s, ok := l.Find(source, name)
	switch {
	case !ok:
		return fmt.Errorf("opencode has no %s skill %q here", source, name)
	case l.NoSwitch != "":
		return errors.New(l.NoSwitch)
	case s.SetIn != "":
		return fmt.Errorf("it's off in %s; change it there", s.SetIn)
	case (s.State == "off") != on:
		return nil // as asked already
	case strings.ContainsAny(name, `*?\{`):
		// The entry would be a pattern, or a {env:} or {file:} opencode
		// fills in before it reads the file.
		return fmt.Errorf("a policy can't name the skill %q alone", name)
	}
	return setDenied(name, !on)
}

// setMu is held from a config file's read to its write, so two changes
// can't lose one another (opencode's own write still can: it doesn't
// ask).
var setMu sync.Mutex

// setDenied adds the entry for id to the global config, or takes every
// one of Nushi's for it out.
func setDenied(id string, deny bool) error {
	setMu.Lock()
	defer setMu.Unlock()
	files := globalFiles()
	if !deny {
		for _, file := range files {
			if err := rewrite(file, id, false); err != nil {
				return err
			}
		}
		return nil
	}
	file := files[0]
	if _, err := os.Stat(file); errors.Is(err, fs.ErrNotExist) {
		if _, err := os.Stat(files[1]); err == nil {
			file = files[1]
		}
	}
	return rewrite(file, id, true)
}

// rewrite changes the config file at file (a link followed:
// atomicfile.Rewrite) and nothing in it but the entry for id. What it
// can't change that way it leaves alone, and says what to change by hand.
func rewrite(file, id string, add bool) error {
	b, err := jsonsettings.ReadFile(file)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	out, err := edited(b, id, add)
	if err == nil && !only(b, out, id, add) {
		err = errors.New("more than that entry would change")
	}
	switch {
	case err != nil && add:
		return fmt.Errorf(`Nushi can't change %s safely (%w): add %s to its "policies" yourself`, file, err, entry(id))
	case err != nil:
		return fmt.Errorf(`Nushi can't change %s safely (%w): take %s out of its "policies" yourself`, file, err, entry(id))
	case bytes.Equal(out, b):
		return nil
	}
	return atomicfile.Rewrite(file, out)
}

// edited is a config file's text with the entry for id added, or with
// each of Nushi's entries for it taken out.
func edited(b []byte, id string, add bool) ([]byte, error) {
	for {
		top, end, err := parse(b)
		if err != nil {
			return nil, err
		}
		if add {
			return added(b, top, end, entry(id))
		}
		out := dropped(b, top, end, id)
		if out == nil {
			return b, nil
		}
		b = out
	}
}

// named is how many of obj's members are called name: a file may say
// one twice, and a JSON reader keeps the last.
func named(obj *hujson.Object, name string) int {
	n := 0
	for i := range obj.Members {
		if s, _ := text(&obj.Members[i].Name); s == name {
			n++
		}
	}
	return n
}

// added is b with item as the last of top's policies, in a policies of
// its own when there is none.
func added(b []byte, top *hujson.Object, end int, item string) ([]byte, error) {
	if len(bytes.TrimSpace(b)) == 0 {
		return []byte("{\n  \"policies\": [\n    " + item + "\n  ]\n}\n"), nil
	}
	v, n := member(top, "policies"), named(top, "policies")
	switch {
	case n > 1:
		return nil, errors.New(`it has "policies" twice`)
	case n == 0:
		return objectItems(top, end).add(b, func(indent string, lines bool) string {
			if !lines {
				return `"policies": [` + item + `]`
			}
			return `"policies": [` + eol(b) + indent + unit(b) + item + eol(b) + indent + `]`
		}), nil
	}
	if _, ok := v.Value.(*hujson.Array); !ok {
		return nil, errors.New(`its "policies" isn't a list`)
	}
	return arrayItems(v).add(b, func(string, bool) string { return item }), nil
}

// dropped is b without the first of Nushi's entries for id in top's
// policies, and without policies when that leaves it empty and no
// comment is in it; nil when there is no such entry.
func dropped(b []byte, top *hujson.Object, end int, id string) []byte {
	v := member(top, "policies")
	if named(top, "policies") != 1 {
		return nil
	}
	arr, ok := v.Value.(*hujson.Array)
	if !ok {
		return nil
	}
	at := slices.IndexFunc(arr.Elements, func(e hujson.Value) bool {
		s, ok := statementOf(&e)
		return ok && s.ours && s.resource == id
	})
	if at < 0 {
		return nil
	}
	i := slices.IndexFunc(top.Members, func(m hujson.ObjectMember) bool { return m.Value.StartOffset == v.StartOffset })
	alone := len(arr.Elements) == 1 && !slices.ContainsFunc([]hujson.Extra{
		arr.AfterExtra, arr.Elements[0].BeforeExtra, arr.Elements[0].AfterExtra, top.Members[i].Name.AfterExtra, v.BeforeExtra,
	}, hasComment)
	if alone {
		return objectItems(top, end).drop(b, i)
	}
	return arrayItems(v).drop(b, at)
}

// only says after reads as before with the entry for id added to
// policies (or each such entry taken out, and policies with the last),
// nothing else changed, and no comment gone: each has a slash, and the
// entry has none.
func only(before, after []byte, id string, add bool) bool {
	b, okB := decoded(before)
	a, okA := decoded(after)
	if !okB || !okA || bytes.Count(before, []byte("/")) != bytes.Count(after, []byte("/")) {
		return false
	}
	item := map[string]any{"action": "skill.use", "resource": id, "effect": "deny"}
	had, _ := b["policies"].([]any)
	left := slices.DeleteFunc(slices.Clone(had), func(v any) bool { return reflect.DeepEqual(v, any(item)) })
	_, kept := a["policies"]
	want := maps.Clone(b)
	switch {
	case add:
		want["policies"] = append(slices.Clone(had), any(item))
	case len(left) == len(had): // none of Nushi's in it
	case len(left) > 0 || kept:
		want["policies"] = left
	default:
		delete(want, "policies")
	}
	return reflect.DeepEqual(a, want)
}

// decoded is a config file's text as plain JSON reads.
func decoded(text []byte) (map[string]any, bool) {
	m := map[string]any{}
	if len(bytes.TrimSpace(text)) == 0 {
		return m, true
	}
	std, err := hujson.Standardize(append(slices.Clip(text), '\n')) // a copy, and parse's line break
	return m, err == nil && json.Unmarshal(std, &m) == nil
}
