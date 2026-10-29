package chats

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// What Nushi shows of an agent's events, for the parity and merge tests
// (claude_parity_test.go): its updates and requests played into chats,
// one for each session the client opened, a subagent's session (announced
// by subagent_update) in its parent's.

// player plays events into chats.
type player struct {
	t       *testing.T
	prompts bool // a prompt shows as the user's message, as Service.Prompt shows it
	order   []string
	svcs    map[string]*Service
	chats   map[string]*chat
	owner   map[string]string   // subagents' sessions to their parents'
	asks    map[string]*pending // the agent's requests not yet answered, by id
}

func newPlayer(t *testing.T, prompts bool) *player {
	t.Helper()
	return &player{t: t, prompts: prompts, svcs: map[string]*Service{}, chats: map[string]*chat{}, owner: map[string]string{}, asks: map[string]*pending{}}
}

// chatOf is the chat of session sid and its service, made when it is
// new; and the session's id there: "s1" (newChat's) for a session of the
// client's, its own for a subagent's.
func (p *player) chatOf(sid string) (*Service, *chat, acp.SessionID) {
	if parent, ok := p.owner[sid]; ok {
		return p.svcs[parent], p.chats[parent], acp.SessionID(sid)
	}
	if p.chats[sid] == nil {
		p.svcs[sid], _, p.chats[sid] = newChat(p.t, claudeSession, &memModes{})
		p.order = append(p.order, sid)
	}
	return p.svcs[sid], p.chats[sid], "s1"
}

// play plays an event.
func (p *player) play(e event) {
	switch {
	case e.note != nil:
		n := *e.note
		_, c, sid := p.chatOf(string(n.SessionID))
		if su := n.Update.SubagentUpdate; su != nil && sid == "s1" {
			p.owner[string(su.SessionID)] = string(n.SessionID)
		}
		n.SessionID = sid
		feed(c, []acp.SessionNotification{n})
	case e.method == "session/prompt" && p.prompts:
		_, c, _ := p.chatOf(e.session)
		c.mu.Lock()
		if e.done {
			c.busy, c.started = false, time.Time{}
		} else {
			c.busy, c.started, c.done = true, time.Now(), make(chan struct{}) // done: what a held turn's release closes
			c.addLocked(model.Item{Kind: model.UserMessage, Text: e.text})
		}
		c.mu.Unlock()
	case e.ask != "":
		p.asks[e.id] = p.ask(e)
	case e.reply != nil || e.id != "":
		if r := p.asks[e.id]; r != nil {
			r.answer(p.t, e.reply)
			delete(p.asks, e.id)
		}
	}
}

// end ends what is still asked, as a chat's requests end when its agent
// goes.
func (p *player) end() {
	for id, r := range p.asks {
		r.cancel()
		<-r.done
		delete(p.asks, id)
	}
}

// pending is a request of the agent's that a chat shows, a permission
// prompt or a question, waiting for its answer.
type pending struct {
	method string
	svc    *Service
	c      *chat
	item   string // its item in the chat
	cancel context.CancelFunc
	done   chan struct{}
}

// ask shows the agent's request e in its session's chat.
func (p *player) ask(e event) *pending {
	var params struct {
		SessionID string `json:"sessionId"`
	}
	_ = json.Unmarshal(e.params, &params)
	svc, c, sid := p.chatOf(params.SessionID)
	ctx, cancel := context.WithCancel(context.Background())
	r := &pending{method: e.ask, svc: svc, c: c, cancel: cancel, done: make(chan struct{})}
	c.mu.Lock()
	known := map[string]bool{}
	for id := range c.waiting {
		known[id] = true
	}
	for id := range c.questions {
		known[id] = true
	}
	c.mu.Unlock()
	go func() {
		defer close(r.done)
		switch e.ask {
		case "session/request_permission":
			var req acp.RequestPermissionRequest
			if json.Unmarshal(e.params, &req) == nil {
				req.SessionID = sid
				_, _ = c.RequestPermission(ctx, &req)
			}
		case "elicitation/create":
			var req acp.CreateElicitationRequest
			if json.Unmarshal(e.params, &req) == nil {
				if req.Form != nil {
					req.Form.SessionID = sid
				}
				_, _ = c.CreateElicitation(ctx, &req)
			}
		}
	}()
	eventually(p.t, c, func() bool {
		select {
		case <-r.done: // one Nushi doesn't show
			return true
		default:
		}
		for id := range c.waiting {
			if !known[id] {
				r.item = id
			}
		}
		for id := range c.questions {
			if !known[id] {
				r.item = id
			}
		}
		return r.item != ""
	})
	return r
}

// answer answers the request as the recording's client did: the option
// it picked, or the form's answers, or none (cancelled).
func (r *pending) answer(t *testing.T, result json.RawMessage) {
	t.Helper()
	defer func() { <-r.done }()
	if r.item == "" {
		return
	}
	switch r.method {
	case "session/request_permission":
		var res acp.RequestPermissionResponse
		if json.Unmarshal(result, &res) == nil && res.Outcome.Selected != nil {
			testcheck.NoErr(t, r.svc.AnswerPermission(r.c.id, r.item, string(res.Outcome.Selected.OptionID)))
			return
		}
	case "elicitation/create":
		var res struct {
			Action  string         `json:"action"`
			Content map[string]any `json:"content"`
		}
		_ = json.Unmarshal(result, &res)
		switch res.Action {
		case "accept":
			values := map[string][]string{}
			for k, v := range res.Content {
				if list, ok := v.([]any); ok {
					for _, x := range list {
						values[k] = append(values[k], fmt.Sprint(x))
					}
				} else {
					values[k] = []string{fmt.Sprint(v)}
				}
			}
			testcheck.NoErr(t, r.svc.AnswerQuestion(r.c.id, r.item, values))
			return
		case "decline":
			testcheck.NoErr(t, r.svc.AnswerQuestion(r.c.id, r.item, nil))
			return
		}
	}
	r.cancel()
}

// parity is what Nushi makes of a session's events: a chat's items,
// usage and status, without the times of this run.
type parity struct {
	Session           string
	Items             []model.Item
	Usage             model.Usage
	Busy, Waiting     bool
	BackgroundRunning int
}

// views are the chats Nushi makes of an agent's events, in the order
// their sessions first had one; prompts aren't shown, since when the
// Go agent's updates came against the prompts the test sent isn't in a
// recording's order.
func views(t *testing.T, events []event) []parity {
	t.Helper()
	p := newPlayer(t, false)
	for _, e := range events {
		p.play(e)
	}
	p.end()
	out := make([]parity, 0, len(p.order))
	for _, sid := range p.order {
		v := view(p.chats[sid])
		v.Session = sid
		out = append(out, v)
	}
	return out
}

// view is a chat's items, usage and status, without the times of this
// run and the ids an agent gives a permission prompt's options, which
// Nushi only passes back: the kind of option picked stands for its id.
// "Don't ask again" goes without its name too: the Go agent words it
// the same for every tool (claudeacp/permission.go), where the adapter
// ports claude's own labels ("…for mkdir commands"), a difference in
// wording only, chosen.
func view(c *chat) parity {
	c.mu.Lock()
	defer c.mu.Unlock()
	st := c.statusLocked()
	p := parity{Usage: c.usage, Busy: st.Busy, Waiting: st.Waiting, BackgroundRunning: st.Background}
	for _, it := range c.items {
		it = timeless(it)
		if it.Kind == model.Permission {
			opts := make([]model.Option, 0, len(it.Options))
			for _, o := range it.Options {
				if o.ID == it.Answer {
					it.Answer = o.Kind
				}
				o.ID = ""
				if o.Kind == string(acp.PermissionOptionKindAllowAlways) {
					o.Name = ""
				}
				opts = append(opts, o)
			}
			it.Options = opts
		}
		p.Items = append(p.Items, it)
	}
	return p
}

// timeless is an item without the times of this run.
func timeless(it model.Item) model.Item {
	it.Sent = time.Time{}
	if it.Subagent != nil {
		sa := *it.Subagent
		sa.Started, sa.Ended = time.Time{}, time.Time{}
		it.Subagent = &sa
	}
	if it.BackgroundCommand != nil {
		bc := *it.BackgroundCommand
		bc.Started, bc.Ended = time.Time{}, time.Time{}
		it.BackgroundCommand = &bc
	}
	return it
}
