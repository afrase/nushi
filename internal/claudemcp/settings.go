package claudemcp

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/jsonsettings"
)

// A .mcp.json server is approved or rejected per project through two
// lists in Claude's settings files, enabledMcpjsonServers and
// disabledMcpjsonServers. A rejection in any settings file (or in the
// project's entry in ~/.claude.json, where the terminal records its
// choices) keeps the server out; an approval in the project's
// .claude/settings.local.json counts once the folder is trusted. Nushi
// changes only those two lists, and only in that file (ADR 0021): unlike
// ~/.claude.json, Claude writes it only when you pick "don't ask again".

type lists struct {
	Enabled  names `json:"enabledMcpjsonServers"`
	Disabled names `json:"disabledMcpjsonServers"`
}

// names is a list of server names, which Claude also takes as one name
// alone, a string.
type names []string

func (n *names) UnmarshalJSON(b []byte) error {
	var one string
	if json.Unmarshal(b, &one) == nil {
		*n = names{one}
		return nil
	}
	return json.Unmarshal(b, (*[]string)(n))
}

// rejected returns, by name, the files that reject a .mcp.json server in
// folder, whose project is key (the settings files, and ~/.claude.json's
// entry for the project), and the servers the project's local settings
// approve.
func rejected(folder, key string, terminal []string) (out map[string][]string, approved []string) {
	out = map[string][]string{}
	for i, path := range claude.SettingsFiles(folder, key) {
		var l lists
		_ = jsonsettings.Read(path, &l) // an unreadable settings file rejects nothing here
		for _, name := range l.Disabled {
			out[name] = append(out[name], path)
		}
		if i == 0 {
			approved = l.Enabled
		}
	}
	for _, name := range terminal {
		out[name] = append(out[name], claude.ConfigFile())
	}
	return out, approved
}

// SetOn turns a server on or off for folder's project: a project server
// (.mcp.json) through the approval lists below, a user or local one
// through Claude's own toggle (Toggle).
func (c Claude) SetOn(ctx context.Context, folder, scope, name string, on bool) error {
	if scope == "project" {
		return approve(ctx, folder, name, on)
	}
	return c.Toggle(ctx, folder, name, on)
}

// approve approves (on) or rejects a .mcp.json server for folder's
// project, in its .claude/settings.local.json.
func approve(ctx context.Context, folder, name string, on bool) error {
	return claude.EditLocal(ctx, claude.Project(folder), func(settings map[string]json.RawMessage) error {
		add, drop := "enabledMcpjsonServers", "disabledMcpjsonServers"
		if !on {
			add, drop = drop, add
		}
		for key, keep := range map[string]bool{add: true, drop: false} {
			list := names{}
			raw, had := settings[key]
			if had && string(raw) != "null" && json.Unmarshal(raw, &list) != nil {
				return fmt.Errorf("%s isn't a list of names", key)
			}
			list = slices.DeleteFunc(list, func(n string) bool { return n == name })
			if keep {
				list = append(list, name)
			}
			if len(list) > 0 || had {
				settings[key], _ = json.Marshal(list)
			}
		}
		return nil
	})
}
