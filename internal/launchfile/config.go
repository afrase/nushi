package launchfile

import (
	"encoding/json"
	"errors"
	"fmt"
)

// config is one entry of configurations as written. Each key is read by
// its exact name, as Claude reads it: encoding/json would match a
// struct's field whatever the key's case.
type config struct {
	name, runtimeExecutable, program, cwd string
	runtimeArgs, args                     []string
	env                                   map[string]string
	// port, autoPort and url are kept as written, each with rules of its
	// own (nil when the key is absent).
	port, autoPort, url json.RawMessage
	// vsCode says the entry has a "type" or a "command": VS Code's shapes.
	vsCode bool
}

// decodeConfig reads raw, one of configurations.
func decodeConfig(raw json.RawMessage) (config, error) {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &fields); err != nil || fields == nil {
		return config{}, errors.New("not a JSON object")
	}
	var c config
	for _, f := range []struct {
		key  string
		into any
		want string
	}{
		{"name", &c.name, "a string"},
		{"runtimeExecutable", &c.runtimeExecutable, "a string"},
		{"runtimeArgs", &c.runtimeArgs, "a list of strings"},
		{"program", &c.program, "a string"},
		{"args", &c.args, "a list of strings"},
		{"cwd", &c.cwd, "a string"},
		{"env", &c.env, "an object of strings"},
	} {
		if v, ok := fields[f.key]; ok {
			if err := json.Unmarshal(v, f.into); err != nil {
				return c, fmt.Errorf("%q must be %s", f.key, f.want)
			}
		}
	}
	c.port, c.autoPort, c.url = fields["port"], fields["autoPort"], fields["url"]
	_, typed := fields["type"]
	_, command := fields["command"]
	c.vsCode = typed || command
	return c, nil
}

// command is what the entry runs, unresolved: runtimeExecutable with
// runtimeArgs, program and args, or node with program and args; empty
// when it names neither.
func (c config) command() (string, []string) {
	switch {
	case c.runtimeExecutable != "":
		args := append([]string{}, c.runtimeArgs...)
		if c.program != "" {
			args = append(args, c.program)
		}
		return c.runtimeExecutable, append(args, c.args...)
	case c.program != "":
		return "node", append([]string{c.program}, c.args...)
	}
	return "", nil
}
