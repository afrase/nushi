package pigmcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"

	"github.com/afrase/nushi/internal/jsonsettings"
)

// Nushi changes PiG's files itself (ADR 0021: only on the user's own
// action in Settings), a key at a time: jsonsettings keeps every other
// byte (keys Nushi doesn't know, their order, the indentation, the mode)
// and replaces the file at once. Yours is followed through a link, as
// PiG does; the project's is written inside its folder only (EditIn), so
// a repository's .pig can't lead the write elsewhere.

// errUnchanged stops a change that leaves the servers as they were, so
// nothing is written: no file, no folder, no added mcpServers key.
var errUnchanged = errors.New("unchanged")

// edit changes the servers of scope's file in folder; one that leaves
// them as they were writes nothing.
func (c PiG) edit(folder, scope string, change func(servers map[string]json.RawMessage) error) error {
	apply := func(m map[string]json.RawMessage) error {
		servers := map[string]json.RawMessage{}
		if raw, ok := m["mcpServers"]; ok && string(raw) != "null" {
			if err := json.Unmarshal(raw, &servers); err != nil {
				return errors.New("mcpServers isn't an object")
			}
		}
		before := decoded(servers)
		if err := change(servers); err != nil {
			return err
		}
		if reflect.DeepEqual(decoded(servers), before) {
			return errUnchanged
		}
		b, err := json.Marshal(servers)
		m["mcpServers"] = b
		return err
	}
	var err error
	switch scope {
	case "user":
		_, err = jsonsettings.Edit(c.userFile(), apply)
	case "project":
		_, err = jsonsettings.EditIn(folder, c.projectName(), apply)
	default:
		err = errNoLocal
	}
	if errors.Is(err, errUnchanged) {
		return nil
	}
	return err
}

// decoded is servers as values, to compare by what they say rather than
// how they're spelled.
func decoded(servers map[string]json.RawMessage) map[string]any {
	out := make(map[string]any, len(servers))
	for name, raw := range servers {
		var v any
		if json.Unmarshal(raw, &v) != nil {
			v = string(raw)
		}
		out[name] = v
	}
	return out
}

// Add adds a server to your file or the project's; a name already there
// is refused (PiG's own add would replace it).
func (c PiG) Add(_ context.Context, folder, scope, name, config string) error {
	raw, err := normalize(config)
	if err != nil {
		return err
	}
	return c.edit(folder, scope, func(servers map[string]json.RawMessage) error {
		if _, ok := servers[name]; ok {
			return fmt.Errorf("PiG already has a server named %s there", name)
		}
		servers[name] = raw
		return nil
	})
}

// Replace changes a server's config in one write, so nothing between a
// remove and an add can lose it.
func (c PiG) Replace(_ context.Context, folder, scope, name, config string) error {
	raw, err := normalize(config)
	if err != nil {
		return err
	}
	return c.edit(folder, scope, func(servers map[string]json.RawMessage) error {
		if _, ok := servers[name]; !ok {
			return fmt.Errorf("PiG has no %s server named %s", scope, name)
		}
		servers[name] = raw
		return nil
	})
}

// Remove takes a server out of its file.
func (c PiG) Remove(_ context.Context, folder, scope, name string) error {
	return c.edit(folder, scope, func(servers map[string]json.RawMessage) error {
		if _, ok := servers[name]; !ok {
			return fmt.Errorf("PiG has no %s server named %s", scope, name)
		}
		delete(servers, name)
		return nil
	})
}

// normalize checks a server's config as PiG would: an object with a
// command (stdio) or a URL (Streamable HTTP), not both, and no type but
// PiG's (Nushi's form says "http", which PiG takes); the legacy SSE
// transport is refused, as PiG refuses it.
func normalize(config string) (json.RawMessage, error) {
	var cfg map[string]json.RawMessage
	if err := json.Unmarshal([]byte(config), &cfg); err != nil || cfg == nil {
		return nil, errors.New("the config isn't a JSON object")
	}
	var typ string
	if raw, ok := cfg["type"]; ok && json.Unmarshal(raw, &typ) != nil {
		return nil, errors.New("type isn't text")
	}
	_, command := cfg["command"]
	_, url := cfg["url"]
	switch {
	case typ == "sse":
		return nil, errors.New("PiG doesn't speak the legacy SSE transport: use the server's Streamable HTTP URL")
	case typ != "" && typ != "stdio" && typ != "http" && typ != "streamable-http":
		return nil, fmt.Errorf("PiG doesn't know the transport %q", typ)
	case command == url:
		return nil, errors.New("PiG needs a command or a URL, not both")
	}
	return json.RawMessage(config), nil
}

// heldHere is why the switch on one of yours can't act in a folder whose
// trusted .pig/mcp.json overrides its "enabled": that holds there,
// whatever your file says, and Nushi writes no override.
const heldHere = "Set by this folder's .pig/mcp.json"

// SetOn turns a server off or on as PiG's own "enabled" means, in the
// file that has it: a project server in the project's file, one of yours
// in your own mcp.json, so on or off everywhere (no trust needed, no
// repository touched). One of yours that a trusted folder's override
// holds there is refused with why (Servers' Held), as is the project's
// override entry itself: Nushi writes no override, whoever asks. An
// entry that says "enabled": true is on already and stays as written.
func (c PiG) SetOn(_ context.Context, folder, scope, name string, on bool) error {
	switch scope {
	case "project", "user":
	default:
		return errNoLocal
	}
	var yours file
	if scope == "project" {
		if err := jsonsettings.Read(c.userFile(), &yours); err != nil {
			return err
		}
	}
	if scope == "user" {
		servers, err := c.Servers(folder)
		if err != nil {
			return err
		}
		for _, sv := range servers {
			if sv.Scope == "user" && sv.Name == name && sv.Held != "" {
				return errors.New(sv.Held)
			}
		}
	}
	return c.edit(folder, scope, func(servers map[string]json.RawMessage) error {
		raw, ok := servers[name]
		if !ok {
			return fmt.Errorf("PiG has no %s server named %s", scope, name)
		}
		if _, mine := yours.Servers[name]; mine && parse(raw).override() {
			return fmt.Errorf("%s here only changes one of your servers: Nushi writes no override", name)
		}
		obj, err := object(raw)
		if err != nil {
			return err
		}
		if on && parse(raw).Enabled != nil && *parse(raw).Enabled {
			return nil // "enabled": true is on already: left as written
		}
		delete(obj, "enabled")
		if !on {
			obj["enabled"] = json.RawMessage("false")
		}
		servers[name], err = json.Marshal(obj)
		return err
	})
}

func object(raw json.RawMessage) (map[string]json.RawMessage, error) {
	var obj map[string]json.RawMessage
	if err := json.Unmarshal(raw, &obj); err != nil || obj == nil {
		return nil, errors.New("its entry isn't an object")
	}
	return obj, nil
}
