package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"maps"
	"os"
	"slices"
	"strings"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// schemaDiff is claude-tee -schema-diff [-missing] <schemas.jsonl>
// <cassette>…: the drift check. It compares the frames recorded in the
// cassettes with the schemas claude's version had when the schemas were
// taken (a line a message kind: its type, subtype or request_subtype,
// and its top-level fields, as testdata/schemas-2.1.312.jsonl has them),
// and reports the kinds the schemas don't have and the fields they don't
// list; with -missing, also the fields they list that no frame had. It
// is a report, not a check: it exits 0 whatever it finds, and non-zero
// only when it can't read its files.
func schemaDiff(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("claude-tee -schema-diff", flag.ContinueOnError)
	fs.SetOutput(stderr)
	missing := fs.Bool("missing", false, "also list the fields the schemas have that no frame had")
	if fs.Parse(args) != nil || fs.NArg() < 2 {
		_, _ = fmt.Fprintln(stderr, "usage: claude-tee -schema-diff [-missing] <schemas.jsonl> <cassette>...")
		return 2
	}
	schemas, err := readSchemas(fs.Arg(0))
	if err != nil {
		_, _ = fmt.Fprintln(stderr, "claude-tee:", err)
		return 1
	}
	seen := map[string]map[string]bool{} // a kind's fields seen
	frames := 0
	for _, path := range fs.Args()[1:] {
		f, err := os.Open(path) //nolint:gosec // a cassette the caller names
		if err != nil {
			_, _ = fmt.Fprintln(stderr, "claude-tee:", err)
			return 1
		}
		c, err := claudetest.ReadCassette(f)
		_ = f.Close()
		if err != nil {
			_, _ = fmt.Fprintf(stderr, "claude-tee: %s: %v\n", path, err)
			return 1
		}
		for _, fr := range c.Frames {
			for kind, fields := range kinds(fr.Frame, schemas) {
				if seen[kind] == nil {
					seen[kind] = map[string]bool{}
				}
				for _, k := range fields {
					seen[kind][k] = true
				}
			}
			frames++
		}
	}
	report(stdout, schemas, seen, frames, *missing)
	return 0
}

// readSchemas reads a schemas file: a kind's fields by its key (kindKey).
func readSchemas(path string) (map[string][]string, error) {
	b, err := os.ReadFile(path) //nolint:gosec // the schemas the caller names
	if err != nil {
		return nil, err
	}
	out := map[string][]string{}
	for line := range strings.Lines(string(b)) {
		if strings.TrimSpace(line) == "" {
			continue
		}
		var row struct {
			Type           string   `json:"type"`
			Subtype        string   `json:"subtype"`
			RequestSubtype string   `json:"request_subtype"`
			Fields         []string `json:"fields"`
		}
		if err := json.Unmarshal([]byte(line), &row); err != nil {
			return nil, fmt.Errorf("%s: %w", path, err)
		}
		key := kindKey(row.Type, row.Subtype)
		if row.RequestSubtype != "" {
			key = "request " + row.RequestSubtype
		}
		out[key] = row.Fields
	}
	return out, nil
}

// kindKey names a message kind: "type", or "type/subtype".
func kindKey(typ, subtype string) string {
	if subtype == "" {
		return typ
	}
	return typ + "/" + subtype
}

// kinds are the kinds a frame is, with its fields for each: its own
// type (and subtype, when the schemas know it by that), and for a control
// request or response, also its request's or response's subtype.
func kinds(frame json.RawMessage, schemas map[string][]string) map[string][]string {
	var top map[string]json.RawMessage
	if json.Unmarshal(frame, &top) != nil { // a line that wasn't JSON
		return nil
	}
	str := func(m map[string]json.RawMessage, k string) string {
		var s string
		_ = json.Unmarshal(m[k], &s)
		return s
	}
	typ, subtype := str(top, "type"), str(top, "subtype")
	key := kindKey(typ, subtype)
	if _, ok := schemas[key]; !ok && subtype != "" {
		if _, ok := schemas[typ]; ok { // the schemas' row for the type's other subtypes
			key = typ
		}
	}
	out := map[string][]string{key: slices.Collect(maps.Keys(top))}
	for _, inner := range []string{"request", "response"} {
		var m map[string]json.RawMessage
		if (typ == "control_request" || typ == "control_response") && json.Unmarshal(top[inner], &m) == nil {
			out["request "+str(m, "subtype")] = slices.Collect(maps.Keys(m))
		}
	}
	return out
}

// report writes what the frames show that the schemas don't.
func report(w io.Writer, schemas map[string][]string, seen map[string]map[string]bool, frames int, missing bool) {
	p := func(format string, a ...any) { _, _ = fmt.Fprintf(w, format, a...) }
	p("schema drift: %d frames, %d kinds\n", frames, len(seen))
	drift := false
	for _, kind := range slices.Sorted(maps.Keys(seen)) {
		listed, ok := schemas[kind]
		fields := slices.Sorted(maps.Keys(seen[kind]))
		if !ok {
			p("  new kind %s: %s\n", kind, strings.Join(fields, ", "))
			drift = true
			continue
		}
		if extra := slices.DeleteFunc(slices.Clone(fields), func(f string) bool { return slices.Contains(listed, f) }); len(extra) > 0 {
			p("  %s: new fields %s\n", kind, strings.Join(extra, ", "))
			drift = true
		}
		if missing {
			if gone := slices.DeleteFunc(slices.Clone(listed), func(f string) bool { return seen[kind][f] }); len(gone) > 0 {
				p("  %s: never seen %s\n", kind, strings.Join(gone, ", "))
			}
		}
	}
	if !drift {
		p("  nothing new\n")
	}
}
