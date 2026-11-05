package launchfile

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

// decoded is decodeConfig of configuration, or the test fails.
func decoded(t *testing.T, configuration string) config {
	t.Helper()
	c, err := decodeConfig(json.RawMessage(configuration))
	if err != nil {
		t.Fatalf("%s: %v", configuration, err)
	}
	return c
}

// Keys are read by their exact names, the last of one written twice
// counting; a key of the wrong type is an error naming it.
func TestDecodeConfig(t *testing.T) {
	c := decoded(t, `{"name": "a", "Name": "b", "runtimeExecutable": "npm", "runtimeArgs": ["run", "dev"],
		"program": "p.js", "args": ["x"], "PORT": 1, "port": 2, "port": 3, "nushi": {}}`)
	command, args := c.command()
	if c.name != "a" || string(c.port) != "3" || c.vsCode || command != "npm" || !reflect.DeepEqual(args, []string{"run", "dev", "p.js", "x"}) {
		t.Errorf("decoded %+v: %s %v", c, command, args)
	}
	if command, args := decoded(t, `{"program": "server.js", "args": ["--verbose"]}`).command(); command != "node" || !reflect.DeepEqual(args, []string{"server.js", "--verbose"}) {
		t.Errorf("program: %s %v", command, args)
	}
	if command, _ := decoded(t, `{"Program": "a.js", "runtimeExecutable": ""}`).command(); command != "" {
		t.Errorf("a key in another case: %s", command)
	}
	if !decoded(t, `{"type": null}`).vsCode || !decoded(t, `{"command": "npm run dev"}`).vsCode {
		t.Error("VS Code's keys")
	}
	for _, c := range []struct{ configuration, err string }{
		{`"npm run dev"`, "not a JSON object"},
		{`null`, "not a JSON object"},
		{`[{}]`, "not a JSON object"},
		{`{"name": 5}`, `"name" must be a string`},
		{`{"runtimeArgs": "dev"}`, `"runtimeArgs" must be a list of strings`},
		{`{"args": [1]}`, `"args" must be a list of strings`},
		{`{"cwd": {}}`, `"cwd" must be a string`},
		{`{"env": {"PORT": 3000}}`, `"env" must be an object of strings`},
	} {
		if _, err := decodeConfig(json.RawMessage(c.configuration)); err == nil || !strings.Contains(err.Error(), c.err) {
			t.Errorf("%s: %v, want %q", c.configuration, err, c.err)
		}
	}
}

// A port is a number from 1 to 65535 or a string of one; 0, "", false
// and null are unset; anything else is refused, as by Claude.
func TestDecodePort(t *testing.T) {
	for _, c := range []struct {
		raw  string
		port int
		err  bool
	}{
		{"", 0, false}, {"null", 0, false}, {"0", 0, false}, {`""`, 0, false}, {"false", 0, false},
		{"3000", 3000, false}, {"3000.0", 3000, false}, {"1e3", 1000, false}, {`"5173"`, 5173, false}, {`" 5173\n"`, 5173, false},
		{"65535", 65535, false}, {"1", 1, false},
		{"65536", 0, true}, {"-1", 0, true}, {"30.5", 0, true}, {"true", 0, true}, {`"0"`, 0, true}, {`"070000"`, 0, true},
		{`"web"`, 0, true}, {`"3000px"`, 0, true}, {"[3000]", 0, true}, {"{}", 0, true},
	} {
		var raw json.RawMessage
		if c.raw != "" {
			raw = json.RawMessage(c.raw)
		}
		port, err := decodePort(raw)
		if port != c.port || (err != nil) != c.err {
			t.Errorf("%s: %d, %v; want %d, error %v", c.raw, port, err, c.port, c.err)
		}
	}
}

// autoPort is unset, true or false; nothing else, null included.
func TestDecodeAutoPort(t *testing.T) {
	if v, err := decodeAutoPort(nil); v != nil || err != nil {
		t.Errorf("unset: %v, %v", v, err)
	}
	if v, err := decodeAutoPort(json.RawMessage("false")); v == nil || *v || err != nil {
		t.Errorf("false: %v, %v", v, err)
	}
	for _, raw := range []string{"null", `"true"`, "1", "{}"} {
		if _, err := decodeAutoPort(json.RawMessage(raw)); err == nil {
			t.Errorf("%s taken", raw)
		}
	}
}

// The command's port as Claude reads it: env PORT, then a --port or -p
// word, then the patterns, word by word; none is 0.
func TestCommandPort(t *testing.T) {
	for _, c := range []struct {
		configuration string
		port          int
	}{
		{`{"program": "a.js"}`, 0},
		{`{"env": {"PORT": "5000"}, "args": ["--port", "6000"]}`, 5000},
		{`{"env": {"PORT": " 5000x"}}`, 5000},
		{`{"env": {"PORT": "auto"}, "args": ["--port", "6000"]}`, 0},
		{`{"env": {"PORT": "-5"}}`, -5},
		{`{"env": {"PORT": ""}, "args": ["--port", "6000"]}`, 6000},
		{`{"runtimeArgs": ["vite", "--port", "5174"]}`, 5174},
		{`{"runtimeArgs": ["vite", "-p", "5175"]}`, 5175},
		{`{"runtimeArgs": ["vite", "--port=5176"]}`, 5176},
		{`{"runtimeArgs": ["vite", "-p=5177"]}`, 5177},
		{`{"program": "--port=4001", "runtimeArgs": ["--port", "4002"]}`, 4001},
		{`{"runtimeArgs": ["--port", "0"], "args": ["-p", "9"]}`, 0},
		{`{"runtimeArgs": ["--port", "x", "-p", "4003"]}`, 4003},
		{`{"runtimeArgs": ["-c", "vite --port 5178"]}`, 5178},
		{`{"runtimeArgs": ["-c", "vite --PORT 5180"]}`, 5180},
		{`{"runtimeArgs": ["-c", "open http://localhost:5179/app"]}`, 5179},
		{`{"runtimeArgs": ["-c", "serve 0.0.0.0:8081"], "args": ["localhost:9"]}`, 9},
		{`{"runtimeArgs": ["-c", "serve 0.0.0.0:8081"]}`, 8081},
		{`{"runtimeArgs": ["-c", "serve :80"]}`, 0},
		{`{"runtimeArgs": ["-c", "serve :8082/app"]}`, 0},
		{`{"runtimeArgs": ["--port", "99999999999"]}`, 1 << 20},
	} {
		if port := decoded(t, c.configuration).commandPort(); port != c.port {
			t.Errorf("%s: %d, want %d", c.configuration, port, c.port)
		}
	}
}
