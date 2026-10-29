package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSchemaDiff(t *testing.T) {
	dir := t.TempDir()
	cassette := filepath.Join(dir, "cli.jsonl")
	lines := []string{
		`{"argv":[],"envKeys":[],"cli":"9.9.9"}`,
		`{"dir":"in","ms":0,"frame":{"type":"control_request","request_id":"1","request":{"subtype":"initialize","hooks":null,"brandNew":true}}}`,
		`{"dir":"out","ms":1,"frame":{"type":"control_response","response":{"subtype":"success","request_id":"1","response":{}}}}`,
		`{"dir":"out","ms":2,"frame":{"type":"system","subtype":"init","session_id":"s","cwd":"/w","newField":1}}`,
		`{"dir":"out","ms":3,"frame":{"type":"result","subtype":"error_during_execution","is_error":true,"session_id":"s"}}`,
		`{"dir":"out","ms":4,"frame":{"type":"system","subtype":"brand_new","session_id":"s"}}`,
		`{"dir":"out","ms":5,"frame":"[SandboxDebug] not JSON"}`,
	}
	if err := os.WriteFile(cassette, []byte(strings.Join(lines, "\n")+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	schemas := filepath.Join("testdata", "schemas-2.1.312.jsonl")
	tests := []struct {
		name string
		args []string
		code int
		want []string
		not  []string
	}{
		{"drift", []string{schemas, cassette}, 0, []string{
			"schema drift: 6 frames, 7 kinds",
			"  request initialize: new fields brandNew\n",
			"  system/init: new fields newField\n",
			"  new kind system/brand_new: session_id, subtype, type\n",
		}, []string{"never seen", "result", "control_response", "request success"}},
		{"missing", []string{"-missing", schemas, cassette}, 0, []string{"  system/init: never seen ", "  result: never seen "}, nil},
		{"no drift", []string{schemas, writeCassette(t, dir, `{"type":"keep_alive"}`)}, 0, []string{"  nothing new\n"}, []string{"new kind", "new fields"}},
		{"usage", []string{schemas}, 2, nil, nil},
		{"unreadable", []string{schemas, filepath.Join(dir, "none.jsonl")}, 1, nil, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var out, errs bytes.Buffer
			if code := schemaDiff(tt.args, &out, &errs); code != tt.code {
				t.Fatalf("exit %d, want %d: %s", code, tt.code, errs.String())
			}
			for _, w := range tt.want {
				if !strings.Contains(out.String(), w) {
					t.Errorf("no %q in\n%s", w, out.String())
				}
			}
			for _, n := range tt.not {
				if strings.Contains(out.String(), n) {
					t.Errorf("%q in\n%s", n, out.String())
				}
			}
		})
	}
}

// writeCassette writes a cassette of one frame out.
func writeCassette(t *testing.T, dir, frame string) string {
	t.Helper()
	p := filepath.Join(dir, "one.jsonl")
	if err := os.WriteFile(p, []byte(`{"argv":[],"envKeys":[],"cli":""}`+"\n"+`{"dir":"out","ms":0,"frame":`+frame+"}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	return p
}

// The schemas checked in are a kind and its field names a row, nothing
// more: the repo is public, and the full dump (descriptions, the CLI's
// internal kinds and their flag) is a private reference.
func TestSchemasArePublicOnly(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("testdata", "schemas-2.1.312.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	allowed := map[string]bool{"type": true, "subtype": true, "request_subtype": true, "fields": true}
	for line := range bytes.Lines(b) {
		var row map[string]json.RawMessage
		if err := json.Unmarshal(line, &row); err != nil {
			t.Fatalf("%v: %s", err, line)
		}
		for k := range row {
			if !allowed[k] {
				t.Errorf("a row has %q: %s", k, line)
			}
		}
	}
}
