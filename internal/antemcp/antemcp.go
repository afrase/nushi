// Package antemcp reads and changes the MCP servers Ante uses: yours,
// "mcp_servers" in $ANTE_HOME/settings.json, the only ones it reads (a
// project's .ante/settings.json can't add any). Ante 0.2.14's format (see
// docs/facts/ante.md): a server by name, with "command", "args", "env"
// (stdio) or "url" (Streamable HTTP; "headers" from Ante 0.2.15), and
// "transport" ("stdio", "streamable-http" or "http"; inferred when
// missing) and "enabled_tools" (an allowlist). It has no off switch, no
// legacy SSE, and no sign-in before 0.2.15 (login.go). A running session
// keeps the servers it started with; a new or resumed one reads them again.
package antemcp

import (
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/model"
)

// Ante is Ante's MCP config.
type Ante struct {
	// Spawn gives what starts `ante serve --stdio` for Check, or why Ante
	// can't run.
	Spawn func() (ante.Spawn, error)
	// Run finds the ante the chats run and their environment, for what
	// signs in; or why Ante can't run.
	Run func() (model.AgentRun, error)
}

// checkFor is the longest a check waits: Ante gives a server 15 s to
// connect and 15 more to list its tools.
const checkFor = 45 * time.Second

// read returns your servers by name, as stored; none without the file or
// the key. A file that isn't JSON, or a key that isn't an object, is an
// error.
func read() (map[string]json.RawMessage, error) {
	var s struct {
		Servers map[string]json.RawMessage `json:"mcp_servers"`
	}
	err := jsonsettings.Read(ante.SettingsFile(), &s)
	return s.Servers, err
}

// Servers returns your servers, sorted by name, in user scope: Ante's
// are the same in every folder. Each config is in the shape Nushi's form
// writes (shown), which Add turns back into Ante's.
func (Ante) Servers(string) ([]model.MCPServer, error) {
	servers, err := read()
	if err != nil {
		return nil, err
	}
	out := make([]model.MCPServer, 0, len(servers))
	for name, raw := range servers {
		out = append(out, model.MCPServer{Name: name, Scope: "user", Source: ante.SettingsFile(), Config: shown(raw)})
	}
	slices.SortFunc(out, func(a, b model.MCPServer) int { return cmp.Compare(a.Name, b.Name) })
	return out, nil
}

// Check has a throwaway Ante host connect to your servers (ante.CheckMCP)
// and returns each one's state: "connected", "failed" with Ante's words,
// "unknown" for one it didn't report on, or "needs_auth" for one that
// wants a sign-in this Ante can do (one that can't stays "failed", in
// Ante's words). A new host reads what's stored each time, so a check
// after a sign-in sees it; nothing here is kept between checks.
func (a Ante) Check(ctx context.Context, folder string) ([]model.MCPServer, error) {
	servers, err := a.Servers(folder)
	if err != nil || len(servers) == 0 {
		return nil, err
	}
	spawn, err := a.Spawn()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, checkFor)
	defer cancel()
	got, err := ante.CheckMCP(ctx, spawn)
	if err != nil {
		return nil, err
	}
	canSignIn := sync.OnceValue(func() bool { _, _, err := a.signIn(ctx); return err == nil })
	out := make([]model.MCPServer, len(servers))
	for i, sv := range servers {
		out[i] = model.MCPServer{Name: sv.Name, State: "unknown", Detail: "Ante didn't say"}
		why, ok := got[sv.Name]
		switch {
		case ok && why == "":
			out[i].State, out[i].Detail = "connected", ""
		case ok && strings.Contains(why, needsSignIn) && canSignIn():
			out[i].State, out[i].Detail = "needs_auth", ""
		case ok:
			out[i].State, out[i].Detail = "failed", why
		}
	}
	return out, nil
}

// errScope is why another scope than yours is refused.
var errScope = errors.New("Ante reads no project's MCP servers: add it for you (user)")

// Add adds a server to your settings. Nushi's form says "type" as
// Claude does: it's turned into Ante's way (a command is stdio, a URL
// Streamable HTTP), and SSE is refused, which Ante doesn't speak.
func (Ante) Add(_ context.Context, _, scope, name, config string) error {
	if scope != "user" {
		return errScope
	}
	raw, err := normalize(config)
	if err != nil {
		return err
	}
	return change(func(servers map[string]json.RawMessage) error {
		if _, ok := servers[name]; ok {
			return fmt.Errorf("Ante already has a server named %s", name)
		}
		servers[name] = raw
		return nil
	})
}

// Remove takes a server out of your settings.
func (Ante) Remove(_ context.Context, _, scope, name string) error {
	if scope != "user" {
		return errScope
	}
	return change(func(servers map[string]json.RawMessage) error {
		if _, ok := servers[name]; !ok {
			return fmt.Errorf("Ante has no server named %s", name)
		}
		delete(servers, name)
		return nil
	})
}

// change changes mcp_servers alone, under Ante's lock (ante.EditSettings).
func change(edit func(map[string]json.RawMessage) error) error {
	return ante.EditSettings(func(m map[string]json.RawMessage) error {
		servers := map[string]json.RawMessage{}
		if raw, ok := m["mcp_servers"]; ok && string(raw) != "null" {
			if err := json.Unmarshal(raw, &servers); err != nil {
				return errors.New("mcp_servers isn't an object")
			}
		}
		if err := edit(servers); err != nil {
			return err
		}
		b, err := json.Marshal(servers)
		m["mcp_servers"] = b
		return err
	})
}

// normalize is a server's config as Ante takes it: "type" (Nushi's and
// Claude's word) dropped with "transport", so Ante infers it from the
// command or URL; exactly one of them. A type that is the config's own
// "transport" (one shown kept, such as "sse") stays as Ante stored it,
// so what Servers lists always goes back, as Edit's put-back needs; a new
// SSE server is refused. A null key is left out, as unset:
// Ante writes null for every key it knows that a server hasn't.
func normalize(config string) (json.RawMessage, error) {
	var cfg map[string]any
	if err := json.Unmarshal([]byte(config), &cfg); err != nil || cfg == nil {
		return nil, errors.New("the config isn't a JSON object")
	}
	for k, v := range cfg {
		if v == nil {
			delete(cfg, k)
		}
	}
	if t, ok := cfg["type"]; ok {
		delete(cfg, "type")
		own, _ := cfg["transport"].(string)
		switch {
		case own != "" && t == own: // Ante's own transport, which shown kept as the type
		case t == "sse":
			return nil, errors.New("Ante doesn't speak the legacy SSE transport: use the server's Streamable HTTP URL")
		default:
			delete(cfg, "transport")
		}
	}
	_, command := cfg["command"]
	_, url := cfg["url"]
	if command == url {
		return nil, errors.New("Ante needs a command or a URL, not both")
	}
	return json.Marshal(cfg)
}

// shown is a server's config in the shape Nushi's form writes, as Claude
// says it: Ante's "transport" goes, and a URL's server says "type"
// "http" (Ante's "streamable-http" or "http", or none, which Ante infers
// from the URL); a command's says none, as stdio. Any other transport
// (one Ante refuses, such as "sse") is also the type, and "transport"
// stays, so normalize puts it back as it was. Empty "args" and
// "env", which Ante writes for every server, go as the form leaves them
// out, and so does a null key, which Ante writes for each one it knows
// that a server hasn't (docs/facts/ante.md): a null "url" isn't a URL.
// What isn't an object is left as stored. normalize is the way back.
func shown(raw json.RawMessage) string {
	var cfg map[string]json.RawMessage
	if err := json.Unmarshal(raw, &cfg); err != nil || cfg == nil {
		return string(raw)
	}
	for k, v := range cfg {
		if string(v) == "null" { // Unmarshal keeps a value's bytes as written: null is just that
			delete(cfg, k)
		}
	}
	for _, key := range []string{"args", "env"} {
		if v, ok := cfg[key]; ok && jsonEmpty(v) {
			delete(cfg, key)
		}
	}
	var transport string
	_ = json.Unmarshal(cfg["transport"], &transport) // not text: inferred, as Ante does
	switch _, url := cfg["url"]; {
	case transport == "streamable-http" || transport == "http" || transport == "" && url:
		delete(cfg, "transport")
		cfg["type"] = json.RawMessage(`"http"`)
	case transport == "" || transport == "stdio":
		delete(cfg, "transport")
	default:
		cfg["type"] = cfg["transport"]
	}
	b, err := json.Marshal(cfg)
	if err != nil {
		return string(raw)
	}
	return string(b)
}

// jsonEmpty says v is [] or {} (or null).
func jsonEmpty(v json.RawMessage) bool {
	var a []any
	if json.Unmarshal(v, &a) == nil && len(a) == 0 {
		return true
	}
	var m map[string]any
	return json.Unmarshal(v, &m) == nil && len(m) == 0
}

// Project is folder: Ante's servers don't depend on it.
func (Ante) Project(folder string) string { return folder }

// SetOn is refused: Ante has no off switch for a server.
func (Ante) SetOn(context.Context, string, string, string, bool) error {
	return errors.New("Ante can't turn a server off: remove it instead")
}

// UserOnly is true: yours are all it reads, and it has no off switch
// (mcp.Config).
func (Ante) UserOnly() bool { return true }
