package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"maps"
	"slices"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/claude"
)

// player plays a client script on a connection.
type player struct {
	c       *conn
	cwd     string // the folder the sessions run in
	timeout time.Duration
	ids     map[string]string     // sessions' names to their ids, and other captured values
	vars    map[string]string     // more "$<name>" values: mcp-echo's path
	async   map[string]<-chan msg // the Async requests not yet awaited
	waited  int                   // where the next waitFor looks from

	// snapshot, when set, is called before each request that reads
	// claude's history of a session (a load, a resume, a fork).
	snapshot func() error
	// kill, when set, stops the process group below the agent whose
	// command line has the text.
	kill func(ctx context.Context, text string) error
}

// play plays steps, and stops at the first that fails or when ctx is
// done (the recorder interrupted), so a run cut short never passes.
func (p *player) play(ctx context.Context, steps []step) error {
	for i := range steps {
		s := &steps[i]
		if s.verb() == "end" { // the client goes now, waiting for nothing more
			clear(p.async)
			break
		}
		err := ctx.Err()
		if err == nil {
			err = p.step(ctx, s)
		}
		if err != nil {
			return fmt.Errorf("step %d (%s): %w", i+1, s.verb(), err)
		}
	}
	for _, name := range slices.Sorted(maps.Keys(p.async)) { // what the script didn't await
		if _, err := p.c.await(ctx, name, p.async[name], p.timeout); err != nil {
			return err
		}
	}
	if left := p.c.unanswered(); len(left) > 0 {
		return fmt.Errorf("the agent's requests no step answered: %s", strings.Join(left, ", "))
	}
	return nil
}

func (p *player) step(ctx context.Context, s *step) error {
	switch s.verb() {
	case "pause":
		d, _ := time.ParseDuration(s.Pause)
		t := time.NewTimer(d)
		defer t.Stop()
		select {
		case <-t.C:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	case "await":
		ch := p.async[s.Await]
		if ch == nil {
			return fmt.Errorf("no request named %q", s.Await)
		}
		delete(p.async, s.Await)
		m, err := p.c.await(ctx, s.Await, ch, p.timeout)
		if err == nil {
			err = answerErr(s, m)
		}
		return err
	case "waitFor":
		var want any
		if err := json.Unmarshal(s.WaitFor, &want); err != nil {
			return err
		}
		i, m, err := p.c.first(ctx, string(s.WaitFor), p.waited, func(_ int, m msg) bool {
			var got any
			return json.Unmarshal(m.raw, &got) == nil && matches(want, got)
		}, p.timeout)
		if err != nil {
			return err
		}
		p.waited = i + 1
		return p.capture(s.Capture, m)
	case "kill":
		if p.kill == nil {
			return errors.New("this run can't stop processes")
		}
		return p.kill(ctx, s.Kill)
	case "answer":
		return p.answer(ctx, s)
	case "cancel":
		return p.c.notify("session/cancel", acp.CancelNotification{SessionID: acp.SessionID(p.ids[s.Cancel])})
	case "notify":
		params, err := p.params(s.Params)
		if err != nil {
			return err
		}
		return p.c.notify(s.Notify, params)
	}
	method, params, err := p.build(s)
	if err != nil {
		return err
	}
	if p.snapshot != nil && slices.Contains([]string{"session/load", "session/resume", "session/fork"}, method) {
		if err := p.snapshot(); err != nil {
			return fmt.Errorf("claude's history before %s: %w", method, err)
		}
	}
	ch, err := p.c.call(method, params)
	if err != nil {
		return err
	}
	if s.Async != "" {
		p.async[s.Async] = ch
		return nil
	}
	m, err := p.c.await(ctx, method, ch, p.timeout)
	if err != nil {
		return err
	}
	if err := answerErr(s, m); err != nil {
		return err
	}
	return p.name(s, m)
}

// capture keeps the values at paths (dotted, into objects) in m under
// their names, as sessions' ids are kept: a subagent's session, say,
// which a later step cancels.
func (p *player) capture(paths map[string]string, m msg) error {
	for name, path := range paths {
		var v any
		_ = json.Unmarshal(m.raw, &v)
		for key := range strings.SplitSeq(path, ".") {
			obj, _ := v.(map[string]any)
			v = obj[key]
		}
		s, ok := v.(string)
		if !ok || s == "" {
			return fmt.Errorf("capture %s: no string at %s in %s", name, path, m.raw)
		}
		p.ids[name] = s
	}
	return nil
}

// answerErr says what is wrong with a request's answer m, if anything.
func answerErr(s *step, m msg) error {
	switch {
	case m.Error != nil && !s.ExpectError:
		return fmt.Errorf("the agent answered with an error: %s", m.Error)
	case m.Error == nil && s.ExpectError:
		return errors.New("the agent answered, not with an error")
	}
	return nil
}

// name keeps a new session's id under its name.
func (p *player) name(s *step, m msg) error {
	name := s.New
	if s.Fork != "" {
		name = s.As
	}
	if name == "" || m.Error != nil {
		return nil
	}
	var r struct {
		SessionID string `json:"sessionId"`
	}
	if json.Unmarshal(m.Result, &r) != nil || r.SessionID == "" {
		return fmt.Errorf("the answer has no sessionId: %s", m.Result)
	}
	p.ids[name] = r.SessionID
	return nil
}

// build is a request step's method and params: Nushi's, as
// internal/features/chats sends them, for the named verbs.
func (p *player) build(s *step) (string, any, error) {
	meta, err := p.meta(s.Meta)
	if err != nil {
		return "", nil, err
	}
	sid := func(name string) (acp.SessionID, error) {
		id, ok := p.ids[name]
		if !ok {
			return "", fmt.Errorf("no session named %q", name)
		}
		return acp.SessionID(id), nil
	}
	text := func(t string) []acp.ContentBlock { return []acp.ContentBlock{{Text: &acp.TextContent{Text: t}}} }
	servers := []acp.MCPServer{} // Nushi sends [], never null
	if s.MCPServers != nil {
		v, err := p.params(s.MCPServers)
		if err != nil {
			return "", nil, err
		}
		b, _ := json.Marshal(v) //nolint:errchkjson // it was JSON
		if err := json.Unmarshal(b, &servers); err != nil {
			return "", nil, fmt.Errorf("mcpServers: %w", err)
		}
	}
	var id acp.SessionID
	for _, name := range []string{s.Load, s.Resume, s.Fork, s.Close, s.Delete, s.Session} {
		if name != "" {
			if id, err = sid(name); err != nil {
				return "", nil, err
			}
			break
		}
	}
	switch s.verb() {
	case "initialize":
		if string(s.Initialize) != "{}" {
			return "initialize", s.Initialize, nil
		}
		caps := &acp.ClientCapabilities{Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}}, Meta: claude.InitMeta}
		if claude.Subagents {
			caps.Subagents = &acp.SubagentCapabilities{}
		}
		return "initialize", acp.InitializeRequest{ProtocolVersion: acp.LatestProtocolVersion, ClientCapabilities: caps,
			ClientInfo: &acp.Implementation{Name: "nushi", Title: "Nushi"}}, nil
	case "new":
		return "session/new", acp.NewSessionRequest{Cwd: p.cwd, MCPServers: servers, Meta: meta}, nil
	case "load":
		return "session/load", acp.LoadSessionRequest{SessionID: id, Cwd: p.cwd, MCPServers: servers, Meta: meta}, nil
	case "resume":
		return "session/resume", acp.ResumeSessionRequest{SessionID: id, Cwd: p.cwd, MCPServers: servers, Meta: meta}, nil
	case "fork":
		return "session/fork", acp.ForkSessionRequest{SessionID: id, Cwd: p.cwd, MCPServers: servers, Meta: meta}, nil
	case "list":
		return "session/list", acp.ListSessionsRequest{Cwd: p.cwd}, nil
	case "close":
		return "session/close", acp.CloseSessionRequest{SessionID: id}, nil
	case "delete":
		return "session/delete", acp.DeleteSessionRequest{SessionID: id}, nil
	case "prompt":
		return "session/prompt", acp.PromptRequest{SessionID: id, Prompt: text(s.Prompt)}, nil
	case "steer":
		// As acp-go's steering.Steer asks, which Nushi uses.
		return "_session/steering", map[string]any{"sessionId": id, "prompt": text(s.Steer),
			"_meta": map[string]any{"steering": map[string]any{"idleBehavior": "promptRequired"}}}, nil
	default: // request
		params, err := p.params(s.Params)
		return s.Request, params, err
	}
}

// meta is a session request's _meta: Nushi's for Claude, extra's keys
// merged in, objects key by key.
func (p *player) meta(extra json.RawMessage) (map[string]any, error) {
	b, _ := json.Marshal(claude.SessionMeta) //nolint:errchkjson // plain values
	var meta map[string]any
	_ = json.Unmarshal(b, &meta)
	if extra == nil {
		return meta, nil
	}
	var add map[string]any
	if err := json.Unmarshal(extra, &add); err != nil {
		return nil, fmt.Errorf("meta: %w", err)
	}
	return merged(meta, add), nil
}

// merged is b merged into a, objects key by key, b winning otherwise.
func merged(a, b map[string]any) map[string]any {
	for k, v := range b {
		am, aok := a[k].(map[string]any)
		bm, bok := v.(map[string]any)
		if aok && bok {
			a[k] = merged(am, bm)
		} else {
			a[k] = v
		}
	}
	return a
}

// params are raw with "$<name>" strings put to the sessions' ids (and
// other captured values or vars) and "$cwd" to the sessions' folder.
func (p *player) params(raw json.RawMessage) (any, error) {
	if raw == nil {
		return map[string]any{}, nil
	}
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return nil, fmt.Errorf("params: %w", err)
	}
	var walk func(any) any
	walk = func(v any) any {
		switch t := v.(type) {
		case string:
			if t == "$cwd" {
				return p.cwd
			}
			if name, ok := strings.CutPrefix(t, "$"); ok {
				if id, ok := p.ids[name]; ok {
					return id
				}
				if v, ok := p.vars[name]; ok {
					return v
				}
			}
		case map[string]any:
			for k, e := range t {
				t[k] = walk(e)
			}
		case []any:
			for i, e := range t {
				t[i] = walk(e)
			}
		}
		return v
	}
	return walk(v), nil
}

// answer answers the agent's next request of the step's method.
func (p *player) answer(ctx context.Context, s *step) error {
	m, err := p.c.request(ctx, s.Answer, p.timeout)
	if err != nil {
		return err
	}
	var result any
	switch {
	case s.Option != "":
		if result, err = permission(m, s.Option); err != nil {
			return err
		}
	case s.Result != nil:
		result = s.Result
	default:
		return errors.New("an answer needs an option or a result")
	}
	return p.c.send(map[string]any{"id": m.ID, "result": result})
}

// permission is the answer to a permission request choosing option: an
// option's kind (allow_once, allow_always, reject_once…) or id, or
// "cancelled".
func permission(m msg, option string) (any, error) {
	if option == "cancelled" {
		return map[string]any{"outcome": map[string]any{"outcome": "cancelled"}}, nil
	}
	var req struct {
		Options []struct {
			OptionID string `json:"optionId"`
			Kind     string `json:"kind"`
		} `json:"options"`
	}
	if err := json.Unmarshal(m.Params, &req); err != nil {
		return nil, err
	}
	for _, o := range req.Options {
		if o.Kind == option || o.OptionID == option {
			return map[string]any{"outcome": map[string]any{"outcome": "selected", "optionId": o.OptionID}}, nil
		}
	}
	return nil, fmt.Errorf("the request has no option %q: %s", option, m.Params)
}
