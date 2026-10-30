package chats

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// A chat put to sleep and woken shows Nushi's copy of its transcript
// merged with the agent's replay (session/load, ADR 0047). The Go
// agent's replay must merge with no divider, the copy having been made
// live with the adapter (a chat that changed agent between sleeps) or
// with the Go agent: its ids and texts are the ones Nushi saw live.
//
// A scenario that loads a session is merged at its load: the copy is the
// chat until then, the replay what the load sent. Any other recorded
// scenario with claude's history at its end has the Go agent load its
// first session after the recording, from that history, and is merged
// with the whole run's chat.
func TestClaudeMerge(t *testing.T) {
	// A copy whose client went mid-turn (eof-mid-tool) keeps a turn no
	// answer ends, and closing its chat would wait out the agent's grace.
	grace := stopGrace
	t.Cleanup(func() { stopGrace = grace })
	stopGrace = 10 * time.Millisecond
	for _, dir := range scenarios(t) {
		t.Run(filepath.Base(dir), func(t *testing.T) {
			skipUnrecorded(t, dir)
			node, sent := readACP(t, filepath.Join(dir, "acp-node.jsonl"))
			var loads []string
			for _, e := range node {
				if e.method == "session/load" && !e.done && !slices.Contains(loads, e.session) {
					loads = append(loads, e.session)
				}
			}
			var more []acpLine
			if len(loads) == 0 {
				sid, load := loadAfter(t, dir, node, sent)
				loads, more = []string{sid}, load
			}
			goRun := runGoAgent(t, dir, sent, more)
			copies := map[string][]event{"the adapter's": node, "the Go agent's": goRun}
			replays := map[string][]event{"the Go agent's": goRun}
			if more == nil {
				replays["the adapter's"] = node
			}
			for _, sid := range loads {
				for cname, copied := range copies {
					c := copyOf(t, copied, sid)
					for rname, replayed := range replays {
						r := replayOf(t, replayed, sid)
						if len(r) == 0 {
							t.Errorf("%s replay of %s is empty", rname, sid)
						}
						merged := merge(c, r, testDialect.Compacted)
						if slices.ContainsFunc(merged, func(it model.Item) bool { return it.Kind == model.Notice && it.Status == differsNotice }) {
							t.Errorf("%s copy and %s replay of %s merge with a divider:\ncopy:   %s\nreplay: %s\nmerged: %s",
								cname, rname, sid, short(c), short(r), short(merged))
						}
						// Claude's mark of a stopped turn isn't the user's.
						if slices.ContainsFunc(merged, func(it model.Item) bool {
							return it.Kind == model.UserMessage && strings.Contains(it.Text, "[Request interrupted by user")
						}) {
							t.Errorf("%s copy and %s replay of %s show claude's interrupt mark: %s", cname, rname, sid, short(merged))
						}
					}
				}
			}
		})
	}
}

// loadAfter is the session a scenario without a load of its own has
// loaded after its recording, the first it opened, and the lines that
// load it: a session/load and its answer. It skips a scenario without
// claude's history at its end, or that ends the session.
func loadAfter(t *testing.T, dir string, node []event, sent []acpLine) (string, []acpLine) {
	t.Helper()
	if _, err := os.Stat(filepath.Join(dir, "history", "end")); err != nil {
		t.Skip("no load, and no history of claude's to load from")
	}
	var sid string
	for _, e := range node {
		if e.method == "session/prompt" {
			sid = e.session
			break
		}
	}
	if sid == "" {
		t.Skip("no prompt: nothing to merge")
	}
	var cwd string
	for _, l := range sent {
		var m rpc
		testcheck.NoErr(t, json.Unmarshal(l.Msg, &m))
		var p struct {
			SessionID string `json:"sessionId"`
			Cwd       string `json:"cwd"`
		}
		_ = json.Unmarshal(m.Params, &p)
		if l.Dir == "in" && p.SessionID == sid && (m.Method == "session/close" || m.Method == "session/delete") {
			t.Skipf("the scenario ends session %s", sid)
		}
		if l.Dir == "in" && m.Method == "session/new" && cwd == "" {
			cwd = p.Cwd
		}
	}
	load, err := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": "merge-load", "method": "session/load",
		"params": acp.LoadSessionRequest{SessionID: acp.SessionID(sid), Cwd: cwd, MCPServers: []acp.MCPServer{}}})
	testcheck.NoErr(t, err)
	return sid, []acpLine{{Dir: "in", Msg: load}, {Dir: "out", Msg: json.RawMessage(`{"jsonrpc":"2.0","id":"merge-load","result":{}}`)}}
}

// copyOf is Nushi's copy of session sid's transcript: its chat as it
// stood before the session's first load, with the prompts it sent and
// the agent's requests (permissions, questions) it showed and answered.
func copyOf(t *testing.T, events []event, sid string) []model.Item {
	t.Helper()
	p := newPlayer(t, true)
	for _, e := range events {
		if e.session == sid && e.method == "session/load" {
			break
		}
		p.play(e)
	}
	p.end()
	_, c, _ := p.chatOf(sid)
	return chatItems(c)
}

// replayOf is what session sid's last load replayed, as the chat sets it
// aside to merge (Service.open).
func replayOf(t *testing.T, events []event, sid string) []model.Item {
	t.Helper()
	start, end := -1, len(events)
	for i, e := range events {
		if e.session == sid && e.method == "session/load" {
			if !e.done {
				start = i
			} else if i > start {
				end = i
			}
		}
	}
	if start < 0 {
		return nil
	}
	_, _, c := newChat(t, claudeSession, &memModes{})
	c.mu.Lock()
	c.busy, c.replaying = true, true
	c.mu.Unlock()
	children := map[string]bool{}
	for _, e := range events[start:end] {
		if e.note != nil {
			sessionNote(c, *e.note, sid, children)
		}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	out := make([]model.Item, 0, len(c.replay))
	for _, it := range c.replay {
		out = append(out, timeless(it))
	}
	return out
}

// sessionNote feeds c an update of session sid's (as its own) or of one
// of its subagents' sessions, which children keeps; others are passed
// over.
func sessionNote(c *chat, n acp.SessionNotification, sid string, children map[string]bool) {
	switch {
	case children[string(n.SessionID)]:
	case string(n.SessionID) == sid:
		if su := n.Update.SubagentUpdate; su != nil {
			children[string(su.SessionID)] = true
		}
		n.SessionID = "s1" // newChat's
	default:
		return
	}
	feed(c, []acp.SessionNotification{n})
}

// chatItems are the chat's items, without the times of this run.
func chatItems(c *chat) []model.Item {
	c.mu.Lock()
	defer c.mu.Unlock()
	out := make([]model.Item, 0, len(c.items))
	for _, it := range c.items {
		out = append(out, timeless(it))
	}
	return out
}
