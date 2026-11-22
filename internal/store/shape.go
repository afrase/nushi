package store

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"strconv"
	"strings"
)

// maxDropped bounds how many values of another shape one decode leaves
// out before the file counts as one that doesn't parse.
const maxDropped = 64

// errNotItsShape is a file whose whole value has another shape than the
// one read (an array where an object goes, a number for a list), or one
// whose mismatched value can't be found: nothing can be kept, so it's a
// file that doesn't parse.
var errNotItsShape = errors.New("not of its shape")

// decodeKeeping decodes b into v, a pointer, leaving out each value of
// another shape (a newer build's, read going back: ADR 0108) so that it
// reads as not set, its default, never as a zero the decoder made up:
// encoding/json fills a mismatched *int with a pointer to 0, and a
// mismatched *struct with an empty one, which a write then keeps. Each
// *json.UnmarshalTypeError's value is removed from the raw JSON at the
// error's path and the whole decoded again, at most maxDropped times. It
// returns the paths left out; an error is a file that doesn't parse, of
// another shape as a whole included, and leaves v as it was.
func decodeKeeping(b []byte, v any) ([]string, error) {
	t := reflect.TypeOf(v).Elem()
	var raw any // decoded only once a value has another shape
	var dropped []string
	for {
		fresh := reflect.New(t)
		err := json.Unmarshal(b, fresh.Interface())
		if err == nil {
			reflect.ValueOf(v).Elem().Set(fresh.Elem())
			return dropped, nil
		}
		shape := (*json.UnmarshalTypeError)(nil)
		if !errors.As(err, &shape) {
			return nil, err
		}
		if shape.Field == "" || len(dropped) == maxDropped {
			return nil, fmt.Errorf("%w: %w", errNotItsShape, err)
		}
		if raw == nil {
			d := json.NewDecoder(bytes.NewReader(b))
			d.UseNumber() // numbers kept as written: an int64 stays exact
			if err := d.Decode(&raw); err != nil {
				return nil, err
			}
		}
		var removed bool
		if raw, removed = remove(raw, strings.Split(shape.Field, ".")); !removed {
			return nil, fmt.Errorf("%w: %w", errNotItsShape, err)
		}
		dropped = append(dropped, shape.Field)
		if b, err = json.Marshal(raw); err != nil {
			return nil, err
		}
	}
}

// remove takes the value at path out of raw, JSON as decoded into an any,
// and returns what's left and whether it was there. path is a
// *json.UnmarshalTypeError's Field, the JSON pointer of the value split
// at its dots: object keys and array indices. A key may hold a dot
// itself, so the shortest run of path elements that names a key and
// leads on to the value is taken. A path that leads nowhere (an older
// encoding/json's, which names struct fields, not the JSON) removes
// nothing.
func remove(raw any, path []string) (any, bool) {
	switch node := raw.(type) {
	case map[string]any:
		for n := 1; n <= len(path); n++ {
			key := strings.Join(path[:n], ".")
			child, ok := node[key]
			switch {
			case !ok:
				continue
			case n == len(path):
				delete(node, key)
				return node, true
			}
			if child, ok := remove(child, path[n:]); ok {
				node[key] = child
				return node, true
			}
		}
	case []any:
		i, err := strconv.Atoi(path[0])
		if err != nil || i < 0 || i >= len(node) {
			return raw, false
		}
		if len(path) == 1 {
			return append(node[:i:i], node[i+1:]...), true
		}
		if child, ok := remove(node[i], path[1:]); ok {
			node[i] = child
			return node, true
		}
	}
	return raw, false
}
