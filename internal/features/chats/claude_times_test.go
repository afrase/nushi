package chats

import (
	"path/filepath"
	"strings"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// A reopened Claude chat dates each replayed message, the user's and the
// agent's, from the replay alone: the time claude's transcript gives it,
// which the Go agent sends on the message's first chunk (a thought's,
// when the message begins with thinking: load's msg_fake_0001). A copy
// merged with the replay takes the times too, for its rows that had none
// (a copy from before Nushi kept times). ADR 0076.
//
// The times are what claude's transcript of each scenario (history/1, as
// its load read it) says of each message: its record's timestamp, the
// first record's for an agent message split over several, as
// claudehistory's MessageTimes read them before the replay told them.
func TestClaudeReplayDatesItsMessages(t *testing.T) {
	at := func(s string) time.Time {
		w, err := time.Parse(time.RFC3339Nano, s)
		testcheck.NoErr(t, err)
		return w
	}
	transcripts := map[string]map[string]time.Time{
		"load": {
			"a689e8e3-9294-421f-9d8d-b0abd8acd531": at("2026-11-24T22:23:18.367Z"),
			"msg_fake_0001":                        at("2026-11-24T22:23:18.385Z"),
			"msg_fake_0003":                        at("2026-11-24T22:23:18.447Z"),
		},
		"plan": {
			"49ecd2ae-fa04-493e-a01f-94ab19adf4dd": at("2026-11-24T22:24:34.096Z"),
			"msg_fake_0001":                        at("2026-11-24T22:24:34.115Z"),
			"msg_fake_0007":                        at("2026-11-24T22:24:34.153Z"),
			"msg_fake_0010":                        at("2026-11-24T22:24:34.165Z"),
		},
	}
	for _, name := range []string{"load", "plan"} {
		dir := filepath.Join("testdata", "claude-parity", name)
		rec, _ := readACP(t, filepath.Join(dir, "acp.jsonl"))
		sid, history := recordedLoad(t, rec)
		want := transcripts[name]
		byText := map[string]time.Time{} // a message's time by its whole text, for a copy's rows under ids of Nushi's
		texts := map[string]string{}
		var order []string
		for _, u := range history {
			c := u.UserMessageChunk
			if c == nil {
				c = u.AgentMessageChunk
			}
			if c == nil || c.Content.Text == nil {
				continue
			}
			id := string(c.MessageID)
			if _, ok := texts[id]; !ok {
				order = append(order, id)
			}
			texts[id] += c.Content.Text.Text
		}
		for _, id := range order {
			if want[id].IsZero() {
				t.Fatalf("%s: the transcript has no time for message %s", name, id)
			}
			byText[texts[id]] = want[id]
		}
		for _, copied := range []bool{false, true} {
			t.Run(name+map[bool]string{false: "/replay", true: "/merged"}[copied], func(t *testing.T) {
				_, agent, c, store, _ := newCopyingChat(t)
				agent.history = history
				if copied {
					var items []model.Item
					for _, it := range copyOf(t, rec, sid) {
						it.Sent = time.Time{} // as from before Nushi kept times
						items = append(items, it)
					}
					testcheck.NoErr(t, store.Replace(c.id, items))
					c.mu.Lock()
					c.record.Updated = time.Now() // used lately: it reopens rather than sleeps (dormant)
					c.mu.Unlock()
				}
				back := reopened(t, restarted(t, agent, c, store), c.id)
				back.mu.Lock()
				defer back.mu.Unlock()
				dated := map[model.ItemKind]int{}
				for _, it := range back.items {
					if it.Kind != model.UserMessage && it.Kind != model.AgentMessage {
						continue
					}
					at, ok := byText[it.Text]
					if !ok {
						t.Errorf("%v %s %q is no replayed message", it.Kind, it.ID, it.Text)
						continue
					}
					if !copied && !want[it.ID].Equal(at) {
						t.Errorf("%v %q has id %s, whose time is %v, want %v", it.Kind, it.Text, it.ID, want[it.ID], at)
					}
					if !it.Sent.Equal(at) {
						t.Errorf("%v %s %q sent %v, want the transcript's %v", it.Kind, it.ID, strings.TrimSpace(it.Text), it.Sent, at)
					}
					dated[it.Kind]++
				}
				if dated[model.UserMessage] == 0 || dated[model.AgentMessage] == 0 {
					t.Errorf("messages checked: %v, want users' and the agent's (%s)", dated, describe(back.items))
				}
			})
		}
	}
}

// recordedLoad is the session a recording loads and the updates the load
// replayed on it, in order.
func recordedLoad(t *testing.T, rec []event) (string, []acp.SessionUpdate) {
	t.Helper()
	var sid string
	var out []acp.SessionUpdate
	for _, e := range rec {
		switch {
		case e.method == "session/load" && !e.done:
			sid = e.session
		case e.method == "session/load":
			return sid, out
		case sid != "" && e.note != nil && string(e.note.SessionID) == sid:
			out = append(out, e.note.Update)
		}
	}
	t.Fatal("the recording loads no session")
	return "", nil
}

// A replayed chunk's time that is no time dates nothing, a message keeps
// the time of the first chunk to tell one, and the times gathered go with
// the replay: none is held once the chat has reopened.
func TestReplayTimesGoWithTheReplay(t *testing.T) {
	_, agent, c, store, _ := newCopyingChat(t)
	meta := func(at string) map[string]any { return map[string]any{"claudeCode": map[string]any{"timestamp": at}} }
	bad, first, later := chunk("m0", "no time"), chunk("m1", "a"), chunk("m1", "b")
	bad.AgentMessageChunk.Meta = meta("yesterday")
	first.AgentMessageChunk.Meta = meta("2026-11-24T22:23:18.385Z")
	later.AgentMessageChunk.Meta = meta("2026-11-25T00:00:00Z")
	agent.history = []acp.SessionUpdate{bad, first, later}
	back := reopened(t, restarted(t, agent, c, store), c.id)
	back.mu.Lock()
	defer back.mu.Unlock()
	if back.replaySent != nil {
		t.Errorf("the replay's times outlive it: %v", back.replaySent)
	}
	sent := map[string]time.Time{}
	for _, it := range back.items {
		sent[it.ID] = it.Sent
	}
	if !sent["m0"].IsZero() {
		t.Errorf("a message whose time is no time sent at %v", sent["m0"])
	}
	if want := time.Date(2026, 11, 24, 22, 23, 18, 385000000, time.UTC); !sent["m1"].Equal(want) {
		t.Errorf("m1 sent at %v, want its first chunk's %v", sent["m1"], want)
	}
}
