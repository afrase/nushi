package ante

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"

	"github.com/afrase/nushi/acp"
)

func resume(id acp.SessionID) map[string]any {
	return map[string]any{"ResumeSession": map[string]any{"session_id": id, "unattended": false}}
}

// openTimeout bounds a host's start, and a resume's replay.
var openTimeout = time.Minute

// open starts a host in cwd and opens a session on it with op
// (StartSession or ResumeSession); a resumed one's saved conversation goes
// to the client first, with replay.
func (b *bridge) open(ctx context.Context, cwd string, op any, replay bool) (any, error) {
	h, err := startHost(b.spawn, cwd)
	if err != nil {
		return nil, fmt.Errorf("couldn't start ante: %w", err)
	}
	s, err := b.start(ctx, h, op, replay)
	if err != nil {
		h.stop(time.Second)
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if replay {
		return acp.LoadSessionResponse{Modes: modes(s.info.PermissionMode), ConfigOptions: b.options(s.info)}, nil
	}
	return acp.NewSessionResponse{SessionID: acp.SessionID(s.id), Modes: modes(s.info.PermissionMode), ConfigOptions: b.options(s.info)}, nil
}

// start sends op to h and waits for the session it starts, then for the
// replay, which Ante ends with no marker: a ContextReport sent right after
// op marks it, since the host answers ops in order. The replayed events
// go to the client when replay, else only their turns are noted.
func (b *bridge) start(ctx context.Context, h *host, op any, replay bool) (*session, error) {
	opid, fence := opID(), opID()
	if err := h.write(opid, op); err != nil {
		return nil, err
	}
	if err := h.write(fence, "ContextReport"); err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, openTimeout)
	defer cancel()
	var s *session
	for {
		var ev event
		var ok bool
		select {
		case ev, ok = <-h.events:
		case <-ctx.Done():
			return nil, errors.New("Ante didn't open the session in time")
		}
		switch {
		case !ok:
			return nil, errors.New("ante stopped before the session opened")
		case ev.Name == "Error" && (s == nil || ev.Parent == fence):
			var msg string
			json.Unmarshal(ev.Payload, &msg)
			return nil, errors.New(msg)
		case ev.Name == "SessionStart" && s == nil:
			var in info
			json.Unmarshal(ev.Payload, &in)
			s = newSession(b, h, in)
		case s == nil:
		case ev.Name == "ContextReport" && ev.Parent == fence:
			var c struct {
				Used  int64 `json:"used_tokens"`
				Limit int64 `json:"limit_tokens"`
			}
			json.Unmarshal(ev.Payload, &c)
			s.mu.Lock()
			s.turn, s.tools = nil, map[string]string{} // the saved turns are over
			s.mu.Unlock()
			b.mu.Lock()
			b.sessions[s.id] = s
			b.mu.Unlock()
			if replay && c.Limit > 0 {
				b.update(s.id, usageUpdate(c.Used, c.Limit))
			}
			go s.pump()
			return s, nil
		default:
			s.mu.Lock()
			out := s.replayLocked(ev)
			s.mu.Unlock()
			for _, u := range out {
				if replay {
					b.update(s.id, u)
				}
			}
		}
	}
}

// replayLocked turns a saved event into what the client shows of the
// conversation: the user's inputs (each under its op's id), the replies,
// the calls; not what was asked or reported along the way.
func (s *session) replayLocked(ev event) []acp.SessionUpdate {
	switch ev.Name {
	case "TurnStart":
		var p struct {
			TurnID string `json:"turn_id"`
		}
		json.Unmarshal(ev.Payload, &p)
		s.turn = &turn{id: p.TurnID, started: true, result: make(chan turnResult, 1)}
		s.turns, s.msg = append(s.turns, p.TurnID), 0
	case "TurnEnd":
		s.turn = nil
	case "UserInput":
		var text string
		json.Unmarshal(ev.Payload, &text)
		if text != "" {
			c := &acp.ContentChunk{Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: text}}, MessageID: acp.MessageID(ev.Parent)}
			return []acp.SessionUpdate{{SessionUpdate: "user_message_chunk", UserMessageChunk: c}}
		}
	case "AgentMessage", "Thinking":
		return s.textLocked(ev)
	case "ToolStart", "ToolEnd":
		return s.toolLocked(ev, nil)
	}
	return nil
}

// fork copies a session into a new one, whole or up to the end of the
// turn that has message after, and opens it: on a host of its own, which
// first opens the source when this bridge doesn't have it open.
func (b *bridge) fork(ctx context.Context, from acp.SessionID, cwd, after string) (any, error) {
	if !isSessionID(string(from)) {
		return nil, fmt.Errorf("%q isn't one of Ante's sessions", from)
	}
	src, err := b.session(from)
	if err != nil { // not open here: open it, unseen
		h, err := startHost(b.spawn, cwd)
		if err != nil {
			return nil, fmt.Errorf("couldn't start ante: %w", err)
		}
		if src, err = b.start(ctx, h, resume(from), false); err != nil {
			h.stop(time.Second)
			return nil, err
		}
		defer func() { src.h.stop(5 * time.Second); <-src.ended }()
	}
	src.mu.Lock()
	op := map[string]any{}
	if t := turnOf(after); t != "" {
		i := slicesIndex(src.turns, t)
		if i < 0 {
			src.mu.Unlock()
			return nil, fmt.Errorf("no message %q in the session", after)
		}
		if i+1 < len(src.turns) {
			op["at"] = src.turns[i+1]
		}
	}
	src.mu.Unlock()
	ev, err := src.await(ctx, map[string]any{"ForkSession": op}, "SessionForked")
	if err != nil {
		return nil, fmt.Errorf("Ante couldn't fork the session: %w", err)
	}
	var forked struct {
		ID string `json:"session_id"`
	}
	json.Unmarshal(ev.Payload, &forked)
	resp, err := b.open(ctx, cwd, resume(acp.SessionID(forked.ID)), false)
	if err != nil {
		return nil, err
	}
	n := resp.(acp.NewSessionResponse)
	return acp.ForkSessionResponse{SessionID: acp.SessionID(forked.ID), Modes: n.Modes, ConfigOptions: n.ConfigOptions}, nil
}

func slicesIndex(s []string, v string) int {
	for i, x := range s {
		if x == v {
			return i
		}
	}
	return -1
}

// list reads Ante's saved sessions (it has no op for them): each one's
// meta.json, newest first, only those in cwd when given.
func (b *bridge) list(cwd string) acp.ListSessionsResponse {
	out := acp.ListSessionsResponse{Sessions: []acp.SessionInfo{}}
	dirs, _ := os.ReadDir(filepath.Join(b.home, "sessions"))
	for _, d := range dirs {
		raw, err := os.ReadFile(filepath.Join(b.home, "sessions", d.Name(), "meta.json"))
		var m struct {
			ID, Dir, Title string
			Active         string `json:"last_active_time"`
		}
		if err != nil || json.Unmarshal(raw, &m) != nil || !isSessionID(m.ID) || cwd != "" && m.Dir != cwd {
			continue
		}
		title := m.Title
		if title == "" {
			var f struct {
				First string `json:"first_user_message"`
			}
			json.Unmarshal(raw, &f)
			title = f.First
		}
		out.Sessions = append(out.Sessions, acp.SessionInfo{SessionID: acp.SessionID(m.ID), Cwd: m.Dir, Title: title, UpdatedAt: m.Active})
	}
	sort.Slice(out.Sessions, func(i, j int) bool { return out.Sessions[i].UpdatedAt > out.Sessions[j].UpdatedAt })
	return out
}

// delete removes a saved session: its folder, as Ante has no op for it,
// after its host (if open here) has ended, which would save it again.
func (b *bridge) delete(id acp.SessionID) error {
	if !isSessionID(string(id)) {
		return fmt.Errorf("%q isn't one of Ante's sessions", id)
	}
	if s, err := b.session(id); err == nil {
		s.h.stop(5 * time.Second)
		<-s.ended
	}
	return os.RemoveAll(filepath.Join(b.home, "sessions", string(id)))
}
