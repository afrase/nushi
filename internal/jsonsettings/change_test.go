package jsonsettings

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// set is a change that sets key (dotted: a key in objects) to value, or
// cuts it when value is "".
func set(key, value string) func(map[string]json.RawMessage) error {
	return func(m map[string]json.RawMessage) error {
		path := strings.Split(key, ".")
		if len(path) == 1 {
			if value == "" {
				delete(m, key)
			} else {
				m[key] = json.RawMessage(value)
			}
			return nil
		}
		var top map[string]any
		if err := json.Unmarshal(m[path[0]], &top); err != nil {
			return err
		}
		obj := top
		for _, k := range path[1 : len(path)-1] {
			obj = obj[k].(map[string]any)
		}
		var v any
		if err := json.Unmarshal([]byte(value), &v); err != nil {
			return err
		}
		obj[path[len(path)-1]] = v
		b, err := json.Marshal(top) // escapes & < >, sorts keys: none of it may show
		m[path[0]] = b
		return err
	}
}

// A change writes the keys it changed and keeps every other byte of the
// file, however it's written.
func TestEditKeepsEveryOtherByte(t *testing.T) {
	for _, c := range []struct {
		name, in, key, value, want string
	}{
		{
			"tabs, order and && kept",
			"{\n\t\"z\": 1,\n\t\"hooks\": \"make lint && make test\",\n\t\"a\": [1, 2]\n}",
			"a", `[1,2,3]`,
			"{\n\t\"z\": 1,\n\t\"hooks\": \"make lint && make test\",\n\t\"a\": [1,2,3]\n}",
		},
		{
			"CRLF, no final line break, a key added on its own lines",
			"{\r\n  \"a\": 1\r\n}",
			"b", `{"c":"x<y"}`,
			"{\r\n  \"a\": 1,\r\n  \"b\": {\r\n    \"c\": \"x<y\"\r\n  }\r\n}",
		},
		{
			"unicode escapes kept",
			`{"name": "café 😀", "on": true}` + "\n",
			"on", `false`,
			`{"name": "café 😀", "on": false}` + "\n",
		},
		{
			"a key named twice, unchanged, kept",
			`{"x": 1, "x": 2, "y": 1}`,
			"y", `2`,
			`{"x": 1, "x": 2, "y": 2}`,
		},
		{
			"a key deep in objects: only its value",
			"{\n    \"permissions\": {\n        \"allow\": [\"Bash(x 2>&1)\"],\n        \"deep\": {\"a\": {\"b\": 1, \"c\": [ 1 ]}}\n    },\n    \"other\": \"&\"\n}\n",
			"permissions.deep.a.b", `2`,
			"{\n    \"permissions\": {\n        \"allow\": [\"Bash(x 2>&1)\"],\n        \"deep\": {\"a\": {\"b\": 2, \"c\": [ 1 ]}}\n    },\n    \"other\": \"&\"\n}\n",
		},
		{
			"a key added deep in objects",
			"{\n  \"p\": {\n    \"a\": 1\n  }\n}\n",
			"p.b", `"v"`,
			"{\n  \"p\": {\n    \"a\": 1,\n    \"b\": \"v\"\n  }\n}\n",
		},
		{
			"a key cut with its line",
			"{\n  \"a\": 1,\n  \"b\": 2,\n  \"c\": 3\n}\n",
			"b", "",
			"{\n  \"a\": 1,\n  \"c\": 3\n}\n",
		},
		{
			"the last key cut with the comma before it",
			"{\n  \"a\": 1,\n  \"c\": 3\n}\n",
			"c", "",
			"{\n  \"a\": 1\n}\n",
		},
		{
			"a list on lines stays on lines",
			"{\n  \"list\": [\n    \"a\"\n  ],\n  \"k\": 1\n}",
			"list", `["a","b&c"]`,
			"{\n  \"list\": [\n    \"a\",\n    \"b&c\"\n  ],\n  \"k\": 1\n}",
		},
		{
			"an empty object",
			"{}\n",
			"a", `1`,
			"{\"a\": 1}\n",
		},
		{
			"nothing changed: nothing written",
			"{ \"a\" : 1 }",
			"a", `1.0`,
			"{ \"a\" : 1 }",
		},
	} {
		t.Run(c.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "settings.json")
			testcheck.Write(t, path, c.in)
			if _, err := Edit(path, set(c.key, c.value)); err != nil {
				t.Fatal(err)
			}
			if b, _ := os.ReadFile(path); string(b) != c.want {
				t.Errorf("wrote\n%q\nwant\n%q", b, c.want)
			}
		})
	}
}

// A file that isn't JSON, or a change the text can't take alone, is
// refused, and the file is left as it was.
func TestEditRefusesAndLeavesTheFile(t *testing.T) {
	for _, c := range []struct{ name, in, key, reason string }{
		{"a trailing comma", `{"a": 1,}`, "a", "reading"},
		{"a comment", "{\n  // mine\n  \"a\": 1\n}", "a", "reading"},
		{"not an object", `[1]`, "a", "reading"},
		{"a changed key named twice", `{"x": 1, "x": 2}`, "x", "x is there twice"},
		{"a changed key's object named twice", `{"p": {"a": 1}, "p": {"a": 1}}`, "p.a", "p is there twice"},
	} {
		t.Run(c.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "settings.json")
			testcheck.Write(t, path, c.in)
			_, err := Edit(path, set(c.key, `5`))
			if err == nil || !strings.Contains(err.Error(), c.reason) {
				t.Errorf("err %v, want %q", err, c.reason)
			}
			if b, _ := os.ReadFile(path); string(b) != c.in {
				t.Errorf("the file became %q", b)
			}
		})
	}
}

// encoding/json's escapes of & < > are written as the characters, an
// escaped backslash before a u left alone.
func TestUnescapeHTML(t *testing.T) {
	for in, want := range map[string]string{
		`"a&b<c>d"`: `"a&b<c>d"`,
		`"\\u0026"`: `"\\u0026"`,
		`"é\n"`:     `"é\n"`,
		`"\\&"`:     `"\\&"`,
	} {
		if got := unescapeHTML(in); got != want {
			t.Errorf("unescapeHTML(%s) = %s, want %s", in, got, want)
		}
	}
}
