package chats

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeacp"
	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
	"github.com/afrase/nushi/claudeagent/sessions"
	"github.com/afrase/nushi/internal/testcheck"
)

// The Go agent's side of the parity and merge tests: it runs on a
// scenario's cassettes as its claudes and is sent what the recording's
// client sent (claude_parity_test.go).

// replays are a scenario's cassettes as fake claudes, the nth for the
// nth claude the agent starts.
type replays struct {
	mu    sync.Mutex
	fakes []*claudetest.Fake
	next  int
}

// readReplays reads dir's cli.jsonl, cli-2.jsonl and on, as claude-tee
// names them.
func readReplays(t *testing.T, dir string) *replays {
	t.Helper()
	r := &replays{}
	for n := 1; ; n++ {
		name := "cli.jsonl"
		if n > 1 {
			name = fmt.Sprintf("cli-%d.jsonl", n)
		}
		f, err := os.Open(filepath.Join(dir, name))
		if errors.Is(err, os.ErrNotExist) {
			return r
		}
		testcheck.NoErr(t, err)
		c, err := claudetest.ReadCassette(f)
		_ = f.Close()
		testcheck.NoErr(t, err)
		// The Go agent asks claude for a title after a turn, on a
		// goroutine of its own, so when it asks isn't in a cassette's
		// order: it is answered (with none) whenever it comes, and a
		// recording's ask isn't expected.
		r.fakes = append(r.fakes, claudetest.Replay(forGoAgent(c)).Respond(`{"type":"control_request","request":{"subtype":"generate_session_title"}}`,
			`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{"title":null}}}`))
	}
}

// Spawn starts the next claude.
func (r *replays) Spawn(ctx context.Context, s claudeagent.Spec) (*claudeagent.Proc, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.next == len(r.fakes) {
		return nil, fmt.Errorf("the Go agent started claude %d times, the adapter %d", r.next+1, len(r.fakes))
	}
	r.next++
	return r.fakes[r.next-1].Spawn(ctx, s)
}

// Err is what went wrong with the claudes' scripts.
func (r *replays) Err() error {
	r.mu.Lock()
	defer r.mu.Unlock()
	var errs []error
	for _, f := range r.fakes {
		errs = append(errs, f.Err())
	}
	return errors.Join(errs...)
}

// runGoAgent runs the Go agent on the cassettes in dir and sends it what
// the recording's client sent, then more's lines, waiting where the
// recording's agent answered or asked; it returns the Go agent's events,
// its sessions under the recording's ids. Before each request that reads
// claude's history (a load, resume or fork) the Go agent's config folder
// gets the history claude had then: history/1 and on, and history/end
// for one of more's.
func runGoAgent(t *testing.T, dir string, rec, more []acpLine) []event {
	t.Helper()
	fake := readReplays(t, dir)
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	served := make(chan struct{})
	configDir, cwd := t.TempDir(), t.TempDir()
	go func() {
		claudeacp.Serve(toAgentR, fromAgentW, claudeacp.Config{CLIPath: "/claude", ConfigDir: configDir, Spawn: fake.Spawn})
		_ = fromAgentW.Close()
		close(served)
	}()
	msgs := make(chan rpc)
	go func() {
		defer close(msgs)
		sc := bufio.NewScanner(fromAgentR)
		sc.Buffer(nil, 64<<20)
		for sc.Scan() {
			var m rpc
			if json.Unmarshal(sc.Bytes(), &m) == nil {
				msgs <- m
			}
		}
	}()
	var events []event
	keep := func(m rpc) bool {
		if m.Method != sessionUpdate {
			return false
		}
		var n acp.SessionNotification
		testcheck.NoErr(t, json.Unmarshal(m.Params, &n))
		events = append(events, event{note: &n})
		return true
	}
	// next is the Go agent's next message other than a session update,
	// which it keeps.
	next := func(what string) rpc {
		for {
			select {
			case m, ok := <-msgs:
				if !ok {
					t.Fatalf("the Go agent ended before %s (claude's script: %v)", what, fake.Err())
				}
				if !keep(m) {
					return m
				}
			case <-time.After(5 * time.Second): // bounds a hang, orders nothing
				t.Fatalf("the Go agent never sent %s", what)
			}
		}
	}
	ids := map[string]string{} // the recorded sessions' ids to the live ones
	// sessions is a recorded message with the live sessions' ids.
	sessions := func(msg json.RawMessage) string { return liveIDs(ids).Replace(string(msg)) }
	agentReqs := map[string]agentReq{} // the agent's requests, by the recorded id
	asked := map[string]event{}        // the marked requests, by recorded id
	reads := 0                         // the requests that read claude's history so far
	for i, l := range append(slices.Clone(rec), more...) {
		var m rpc
		testcheck.NoErr(t, json.Unmarshal(l.Msg, &m))
		switch {
		case l.Dir == "in":
			if slices.Contains([]string{"session/load", "session/resume", "session/fork"}, m.Method) {
				reads++
				history := strconv.Itoa(reads)
				if i >= len(rec) {
					history = "end"
				}
				installHistory(t, filepath.Join(dir, "history", history), configDir, cwd, ids)
			}
			msg, id := l.Msg, json.RawMessage(nil)
			if m.Method == "" { // an answer to the agent's request: under the Go agent's id, in its terms
				req := agentReqs[string(m.ID)]
				id = req.id
				if result := req.answer(m.Result); m.Error == nil {
					msg, _ = json.Marshal(map[string]any{"jsonrpc": "2.0", "id": m.ID, "result": result})
					events = append(events, event{reply: result, id: string(m.ID)})
				}
			}
			if marked(m.Method) {
				e := request(m)
				asked[string(m.ID)] = e
				events = append(events, e)
			}
			_, err := io.WriteString(toAgentW, rewrite(t, sessions(msg), id, cwd)+"\n")
			testcheck.NoErr(t, err)
		case m.Method == sessionUpdate: // the adapter's, read by readACP
		case m.Method != "" && m.ID == nil: // another notification (the adapter's _auth/status_update): Nushi reads none
		case m.Method != "": // a request of the agent's
			got := next(m.Method)
			if got.Method != m.Method {
				t.Fatalf("the Go agent sent %s %s, the adapter %s", got.Method, got.Params, m.Method)
			}
			agentReqs[string(m.ID)] = agentReq{id: got.ID, method: got.Method, recorded: m.Params, live: got.Params}
			params := recordedIDs(ids).Replace(string(got.Params))
			events = append(events, event{ask: got.Method, params: json.RawMessage(params), id: string(m.ID)})
		default: // the agent's answer to the request with this id
			got := next("the answer to " + string(m.ID))
			if string(got.ID) != string(m.ID) || (got.Error == nil) != (m.Error == nil) {
				t.Fatalf("the Go agent answered %s with %s %s, the adapter with %s %s", m.ID, got.Result, got.Error, m.Result, m.Error)
			}
			var recS, liveS struct {
				SessionID string `json:"sessionId"`
			}
			_, _ = json.Unmarshal(m.Result, &recS), json.Unmarshal(got.Result, &liveS)
			if recS.SessionID != "" && liveS.SessionID != "" {
				ids[recS.SessionID] = liveS.SessionID
			}
			if e, ok := asked[string(m.ID)]; ok {
				e.done = true
				events = append(events, e)
			}
		}
	}
	_ = toAgentW.Close() // the client goes: the agent closes its sessions, and claude ends
	for m := range msgs {
		if !keep(m) {
			t.Errorf("the Go agent sent %s %s after the recording ended", m.Method, m.ID)
		}
	}
	<-served
	_ = toAgentR.Close()
	if err := fake.Err(); err != nil {
		t.Errorf("claude's script: %v", err)
	}
	recorded := map[string]string{} // the live ids back to the recorded
	for r, l := range ids {
		recorded[l] = r
	}
	for _, e := range events {
		if e.note != nil && recorded[string(e.note.SessionID)] != "" {
			e.note.SessionID = acp.SessionID(recorded[string(e.note.SessionID)])
		}
	}
	return events
}

// agentReq is a request of the Go agent's: its id, and what it and the
// adapter's request asked.
type agentReq struct {
	id             json.RawMessage
	method         string
	recorded, live json.RawMessage
}

// answer is the recorded client's answer to the adapter's request as an
// answer to the Go agent's: a permission option of the same kind, the
// options' ids being each agent's own (Nushi only passes back the one
// picked).
func (r agentReq) answer(result json.RawMessage) json.RawMessage {
	var res acp.RequestPermissionResponse
	if r.method != "session/request_permission" || json.Unmarshal(result, &res) != nil || res.Outcome.Selected == nil {
		return result
	}
	var rec, live acp.RequestPermissionRequest
	_, _ = json.Unmarshal(r.recorded, &rec), json.Unmarshal(r.live, &live)
	i := slices.IndexFunc(rec.Options, func(o acp.PermissionOption) bool { return o.OptionID == res.Outcome.Selected.OptionID })
	if i < 0 {
		return result
	}
	j := slices.IndexFunc(live.Options, func(o acp.PermissionOption) bool { return o.Kind == rec.Options[i].Kind })
	if j < 0 {
		return result
	}
	res.Outcome.Selected.OptionID = live.Options[j].OptionID
	b, err := json.Marshal(res)
	if err != nil {
		return result
	}
	return b
}

// recordedIDs replaces live sessions' ids with the recorded ones, as
// liveIDs the other way.
func recordedIDs(ids map[string]string) *strings.Replacer {
	back := make(map[string]string, len(ids))
	for rec, live := range ids {
		back[live] = rec
	}
	return liveIDs(back)
}

// liveIDs replaces recorded sessions' ids with the live ones, as whole
// JSON strings, never part of one.
func liveIDs(ids map[string]string) *strings.Replacer {
	pairs := make([]string, 0, 2*len(ids))
	for rec, live := range ids {
		pairs = append(pairs, `"`+rec+`"`, `"`+live+`"`)
	}
	return strings.NewReplacer(pairs...)
}

// installHistory gives the Go agent claude's history as the recording
// had it (from, if there is one): the transcripts go into cwd's project
// folder in configDir, under the live sessions' ids.
func installHistory(t *testing.T, from, configDir, cwd string, ids map[string]string) {
	t.Helper()
	if _, err := os.Stat(from); errors.Is(err, fs.ErrNotExist) {
		return // not recorded: none
	}
	to := sessions.ProjectDir(configDir, cwd)
	recorded := os.DirFS(from)
	err := fs.WalkDir(recorded, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		parts := strings.Split(path, "/")
		for i, p := range parts {
			base, ext := strings.CutSuffix(p, ".jsonl")
			if live := ids[base]; live != "" {
				parts[i] = live
				if ext {
					parts[i] += ".jsonl"
				}
			}
		}
		b, err := fs.ReadFile(recorded, path)
		if err != nil {
			return err
		}
		testcheck.Write(t, filepath.Join(append([]string{to}, parts...)...), liveIDs(ids).Replace(string(b)))
		return nil
	})
	testcheck.NoErr(t, err)
}

// rewrite is a recorded message to send the Go agent: under id when given,
// and with cwd for a session request's folder, which must exist here.
func rewrite(t *testing.T, msg string, id json.RawMessage, cwd string) string {
	t.Helper()
	var m map[string]any
	testcheck.NoErr(t, json.Unmarshal([]byte(msg), &m))
	if id != nil {
		m["id"] = id
	}
	if p, _ := m["params"].(map[string]any); p["cwd"] != nil {
		p["cwd"] = cwd
	}
	b, err := json.Marshal(m)
	testcheck.NoErr(t, err)
	return string(b)
}
