package jsonsettings

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"reflect"
	"slices"
)

// SetKeyIn changes one top-level key of the JSON settings file name (a
// relative path) inside base, through an os.Root as EditIn, keeping every
// other byte of the file: only that key's value is replaced (or the key
// added at the end of the object). change gets the key's value (nil when
// absent) and returns the new one. The result is decoded and must be the
// original with only that key changed; a file Nushi can't edit that way
// (not an object, the key twice) is refused with "change it in <file>".
// For a file the repository may commit, where a rewrite of the rest would
// be a diff nobody asked for.
func SetKeyIn(base, name, key string, change func(old json.RawMessage) (json.RawMessage, error)) error {
	root, err := os.OpenRoot(base)
	if err != nil {
		return err
	}
	defer root.Close() //nolint:errcheck // done with it
	refuse := func(why string) error {
		return fmt.Errorf("Nushi can't change %s alone (%s): change it in %s", key, why, name)
	}
	mu.Lock()
	defer mu.Unlock()
	b, err := readIn(root, name)
	created := errors.Is(err, os.ErrNotExist)
	if err != nil && !created {
		return err
	}
	if created {
		b = []byte("{}\n")
	}
	start, end, last, err := locate(b, key)
	if err != nil {
		return refuse(err.Error())
	}
	var old json.RawMessage
	if start >= 0 {
		old = json.RawMessage(b[start:end])
	}
	value, err := change(old)
	if err != nil {
		return err
	}
	var out []byte
	switch {
	case start >= 0:
		out = slices.Concat(b[:start], value, b[end:])
	case last < 0: // an empty object: { and } around nothing
		i := bytes.IndexByte(b, '{') + 1
		out = slices.Concat(b[:i], []byte("\n  "+quote(key)+": "+string(value)+"\n"), bytes.TrimLeft(b[i:], " \t\r\n"))
	default:
		out = slices.Concat(b[:last], []byte(",\n  "+quote(key)+": "+string(value)), b[last:])
	}
	if !only(b, out, key, value) {
		return refuse("the rest would change")
	}
	return writeIn(root, name, out)
}

func quote(s string) string {
	b, _ := json.Marshal(s) // a string always encodes
	return string(b)
}

// locate finds key's value in the top-level object b: its bytes
// [start, end) (start -1 when absent), and where the last value ends
// (-1 for an empty object).
func locate(b []byte, key string) (start, end, last int, err error) {
	start, last = -1, -1
	dec := json.NewDecoder(bytes.NewReader(b))
	if t, err := dec.Token(); err != nil || t != json.Delim('{') {
		return 0, 0, 0, errors.New("it isn't a JSON object")
	}
	for dec.More() {
		t, err := dec.Token()
		if err != nil {
			return 0, 0, 0, err
		}
		k, _ := t.(string)
		afterKey := int(dec.InputOffset())
		var v json.RawMessage
		if err := dec.Decode(&v); err != nil {
			return 0, 0, 0, err
		}
		last = int(dec.InputOffset())
		if k == key {
			if start >= 0 {
				return 0, 0, 0, fmt.Errorf("%s is there twice", key)
			}
			colon := bytes.IndexByte(b[afterKey:], ':')
			start = afterKey + colon + 1
			for start < last && (b[start] == ' ' || b[start] == '\t' || b[start] == '\n' || b[start] == '\r') {
				start++
			}
			end = last
		}
	}
	if t, err := dec.Token(); err != nil || t != json.Delim('}') {
		return 0, 0, 0, errors.New("it isn't one JSON object")
	}
	if _, err := dec.Token(); err == nil {
		return 0, 0, 0, errors.New("more follows the object")
	}
	return start, end, last, nil
}

// only says after decodes to before with key set to value and nothing else
// changed.
func only(before, after []byte, key string, value json.RawMessage) bool {
	var b, a map[string]any
	var v any
	if json.Unmarshal(before, &b) != nil || json.Unmarshal(after, &a) != nil || json.Unmarshal(value, &v) != nil {
		return false
	}
	if b == nil {
		b = map[string]any{}
	}
	b[key] = v
	return reflect.DeepEqual(a, b)
}
