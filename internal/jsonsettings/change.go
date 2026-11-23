package jsonsettings

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"maps"
	"reflect"
	"slices"
	"strings"

	"github.com/tailscale/hujson"
)

// A change to a settings file is made in its text (text.go), never by
// writing the whole file again: each key whose value changed, at any depth
// of objects, has its value's bytes replaced, is added as its object's
// last member, or is cut with its comma. Every other byte stays: comments,
// key order, indentation, line endings, a final line break or none.

// step is one key's change: set (value nil: cut) at path, keys from the
// top.
type step struct {
	path  []string
	value json.RawMessage
}

// changed is b, a JSON object as read, with settings (the decoded
// object after change) written in, each changed key alone. A change the
// text can't take that way (a changed key named twice in its object)
// is refused, as is any result that doesn't read back as settings.
func changed(b []byte, settings map[string]json.RawMessage) ([]byte, error) {
	var before map[string]json.RawMessage
	if err := json.Unmarshal(b, &before); err != nil {
		return nil, err
	}
	var steps []step
	diff(nil, before, settings, &steps)
	out := b
	for _, s := range steps {
		var err error
		if out, err = s.apply(out); err != nil {
			return nil, fmt.Errorf("Nushi can't change %s alone (%w)", strings.Join(s.path, "."), err)
		}
	}
	if !same(out, settings) {
		return nil, errors.New("Nushi can't change it alone (the rest would change)")
	}
	return out, nil
}

// diff adds to steps what turns the object before into after: a key
// added, cut or set, or, where both hold an object, the keys in it.
func diff(path []string, before, after map[string]json.RawMessage, steps *[]step) {
	for _, k := range slices.Sorted(maps.Keys(before)) {
		if _, ok := after[k]; !ok {
			*steps = append(*steps, step{path: append(slices.Clip(path), k)})
		}
	}
	for _, k := range slices.Sorted(maps.Keys(after)) {
		old, had := before[k]
		p := append(slices.Clip(path), k)
		switch {
		case had && equal(old, after[k]):
		case had && isObject(old) && isObject(after[k]):
			var o, n map[string]json.RawMessage
			if json.Unmarshal(old, &o) == nil && json.Unmarshal(after[k], &n) == nil {
				diff(p, o, n, steps)
				continue
			}
			fallthrough
		default:
			*steps = append(*steps, step{path: p, value: cmpOr(after[k])})
		}
	}
}

// cmpOr is v, or null for a nil value (a key set to nothing): a step
// with no value cuts its key.
func cmpOr(v json.RawMessage) json.RawMessage {
	if v == nil {
		return json.RawMessage("null")
	}
	return v
}

func isObject(v json.RawMessage) bool {
	t := bytes.TrimLeft(v, " \t\r\n")
	return len(t) > 0 && t[0] == '{'
}

// equal says two values read alike, however they're written.
func equal(a, b json.RawMessage) bool {
	var x, y any
	return json.Unmarshal(a, &x) == nil && json.Unmarshal(cmpOr(b), &y) == nil && reflect.DeepEqual(x, y)
}

// same says b reads as settings.
func same(b []byte, settings map[string]json.RawMessage) bool {
	var got, want any
	w, err := json.Marshal(settings)
	return err == nil && json.Unmarshal(b, &got) == nil && json.Unmarshal(w, &want) == nil && reflect.DeepEqual(got, want)
}

// apply makes the step in b.
func (s step) apply(b []byte) ([]byte, error) {
	root, err := hujson.Parse(b)
	if err != nil {
		return nil, err
	}
	obj, end := &root, root.EndOffset
	for _, k := range s.path[:len(s.path)-1] {
		m, err := member(obj, k)
		if err != nil {
			return nil, err
		}
		obj, end = &m.Value, m.Value.EndOffset
	}
	o, ok := obj.Value.(*hujson.Object)
	if !ok {
		return nil, errors.New("not an object")
	}
	key := s.path[len(s.path)-1]
	i, err := index(o, key)
	if err != nil {
		return nil, err
	}
	items := ObjectItems(o, end)
	switch {
	case s.value == nil && i < 0:
		return b, nil
	case s.value == nil:
		return items.Drop(b, i), nil
	case i < 0:
		return items.Add(b, func(indent string, lines bool) string {
			return quote(key) + ": " + written(s.value, b, indent, lines)
		}), nil
	}
	v := &o.Members[i].Value
	lead := b[lineStart(b, o.Members[i].Name.StartOffset):o.Members[i].Name.StartOffset]
	lines := blank(lead) && bytes.ContainsRune(b[v.StartOffset:v.EndOffset], '\n')
	return splice(b, cut{at: v.StartOffset, del: v.EndOffset - v.StartOffset, ins: written(s.value, b, string(lead), lines)}), nil
}

// member is obj's member called key, an object's.
func member(obj *hujson.Value, key string) (*hujson.ObjectMember, error) {
	o, ok := obj.Value.(*hujson.Object)
	if !ok {
		return nil, errors.New("not an object")
	}
	i, err := index(o, key)
	if err != nil {
		return nil, err
	}
	if i < 0 {
		return nil, fmt.Errorf("no %s", key)
	}
	return &o.Members[i], nil
}

// index is where o's member called key is, -1 when it has none; o
// naming it twice is an error (a JSON reader keeps the last, a person
// might mean either).
func index(o *hujson.Object, key string) (int, error) {
	at := -1
	for i := range o.Members {
		var name string
		lit, _ := o.Members[i].Name.Value.(hujson.Literal)
		if json.Unmarshal(lit, &name) != nil || name != key {
			continue
		}
		if at >= 0 {
			return 0, fmt.Errorf("%s is there twice", key)
		}
		at = i
	}
	return at, nil
}

// written is value as it goes into b: on lines of its own, a level
// deeper than indent, when lines; else on one line. & < > stay as they
// are (encoding/json escapes them).
func written(value json.RawMessage, b []byte, indent string, lines bool) string {
	var out bytes.Buffer
	if err := json.Compact(&out, value); err != nil {
		return string(value) // same refuses it
	}
	if lines {
		flat := out.Bytes()
		out = bytes.Buffer{}
		_ = json.Indent(&out, flat, indent, Unit(b)) // valid: just compacted
	}
	s := unescapeHTML(out.String())
	if eol := EOL(b); eol != "\n" {
		s = strings.ReplaceAll(s, "\n", eol)
	}
	return s
}

// unescapeHTML is the JSON text s with encoding/json's escapes of & < >
// (&, <, >) written as the characters; a backslash in
// JSON only ever starts an escape, so each is read whole.
func unescapeHTML(s string) string {
	if !strings.Contains(s, `\u00`) {
		return s
	}
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] != '\\' || i+1 == len(s) {
			b.WriteByte(s[i])
			continue
		}
		switch esc := strings.ToLower(s[i:min(i+6, len(s))]); esc {
		case `&`, `<`, `>`:
			b.WriteString(map[string]string{`&`: "&", `<`: "<", `>`: ">"}[esc])
			i += 5
		default:
			b.WriteString(s[i : i+2])
			i++
		}
	}
	return b.String()
}

// quote is s as a JSON string, & < > as they are.
func quote(s string) string {
	b, _ := json.Marshal(s) // a string always encodes
	return unescapeHTML(string(b))
}
