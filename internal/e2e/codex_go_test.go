package e2e

import (
	"context"
	"encoding/json"
	"io"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"

	"connectrpc.com/connect"
	"github.com/afrase/codex-acp-go/appserver/appservertest"
	"github.com/afrase/codex-acp-go/codexacp"

	"github.com/afrase/nushi/internal/acptest"
	"github.com/afrase/nushi/internal/codex"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

// codexGo is Codex's harness on the Go agent (codex-acp-go's codexacp), as
// "codex-go", beside "codex" on the fake shaped like codex-acp: the two
// must give Nushi the same chat.
type codexGo struct{ codex.Harness }

func (codexGo) Info() model.HarnessInfo {
	info := codex.Harness{}.Info()
	info.Name, info.Title = "codex-go", "Codex through Nushi's Go agent"
	return info
}

// codexes are the fake app-servers the Go agent started, one an agent,
// and the threads' items they keep, as Codex's rollouts would, for a
// daemon started again on the same data folder (codexStores).
type codexes struct {
	mu      sync.Mutex
	fakes   []*appservertest.Fake
	items   map[string][]map[string]any // thread/items/list's entries by thread
	running map[string]string           // each thread's turn being started, by thread
	threads atomic.Int64                // thread ids, unique across agents
	turns   atomic.Int64                // turn (and its items') numbers, unique across agents
}

// codexFakes are the fake Codexes' threads by data folder, under fakesMu.
var codexFakes = map[string]*codexes{}

// codexStores is the fake Codexes for a data folder, as anteStores.
func codexStores(dataDir string) *codexes {
	fakesMu.Lock()
	defer fakesMu.Unlock()
	if codexFakes[dataDir] == nil {
		codexFakes[dataDir] = &codexes{items: map[string][]map[string]any{}, running: map[string]string{}}
	}
	return codexFakes[dataDir]
}

// keep records a thread's items as its turn makes them.
func (c *codexes) keep(thread, turn string, items ...map[string]any) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, it := range items {
		c.items[thread] = append(c.items[thread], map[string]any{"turnId": turn, "item": it})
	}
}

// history scripts f's thread/resume, thread/read, thread/items/list and
// thread/fork from the threads kept; a fork with a last turn keeps the
// items up to that turn's last, as Codex cuts one.
func (c *codexes) history(f *appservertest.Fake) {
	f.On("thread/read", func(params json.RawMessage) (any, error) {
		var p struct {
			ThreadID string `json:"threadId"`
		}
		_ = json.Unmarshal(params, &p)
		return map[string]any{"thread": appservertest.Thread(p.ThreadID, "")}, nil
	})
	f.On("thread/fork", func(params json.RawMessage) (any, error) {
		var p struct {
			ThreadID   string `json:"threadId"`
			LastTurnID string `json:"lastTurnId"`
			Cwd        string `json:"cwd"`
		}
		_ = json.Unmarshal(params, &p)
		id := "thr_" + strconv.FormatInt(c.threads.Add(1), 10)
		c.mu.Lock()
		var kept []map[string]any
		seen := false
		for _, e := range c.items[p.ThreadID] {
			if p.LastTurnID != "" && seen && e["turnId"] != p.LastTurnID {
				break
			}
			seen = seen || e["turnId"] == p.LastTurnID
			kept = append(kept, e)
		}
		c.items[id] = kept
		c.mu.Unlock()
		return appservertest.Opened(appservertest.Thread(id, p.Cwd)), nil
	})
	f.On("thread/resume", func(params json.RawMessage) (any, error) {
		var p struct {
			ThreadID string `json:"threadId"`
			Cwd      string `json:"cwd"`
		}
		_ = json.Unmarshal(params, &p)
		opened := appservertest.Opened(appservertest.Thread(p.ThreadID, p.Cwd))
		opened["itemsBackwardsCursor"] = "end"
		return opened, nil
	})
	f.On("thread/items/list", func(params json.RawMessage) (any, error) {
		var p struct {
			ThreadID string `json:"threadId"`
			Sort     string `json:"sortDirection"`
		}
		_ = json.Unmarshal(params, &p)
		c.mu.Lock()
		items := append([]map[string]any(nil), c.items[p.ThreadID]...)
		c.mu.Unlock()
		if p.Sort == "desc" && len(items) > 0 {
			items = items[len(items)-1:]
		}
		return map[string]any{"data": items, "nextCursor": nil, "backwardsCursor": nil}, nil
	})
}

// serve runs the Go agent on r and w with a fake app-server scripted as
// a signed-in Codex whose every turn runs `echo hi` and says "Ran it.".
func (c *codexes) serve(r io.Reader, w io.Writer) {
	f := appservertest.New()
	f.Codex()
	f.On("thread/start", func(params json.RawMessage) (any, error) {
		var p struct {
			Cwd string `json:"cwd"`
		}
		_ = json.Unmarshal(params, &p)
		return appservertest.Opened(appservertest.Thread("thr_"+strconv.FormatInt(c.threads.Add(1), 10), p.Cwd)), nil
	})
	f.On("turn/start", func(params json.RawMessage) (any, error) {
		var p struct {
			ThreadID string `json:"threadId"`
		}
		_ = json.Unmarshal(params, &p)
		n := strconv.FormatInt(c.turns.Add(1), 10)
		c.mu.Lock()
		c.running[p.ThreadID] = n
		c.mu.Unlock()
		return map[string]any{"turn": appservertest.TurnOf("turn_"+n, "inProgress")}, nil
	})
	f.Then("turn/start", func(params json.RawMessage) {
		var p struct {
			ThreadID string          `json:"threadId"`
			Input    json.RawMessage `json:"input"`
		}
		_ = json.Unmarshal(params, &p)
		c.mu.Lock()
		n := c.running[p.ThreadID]
		c.mu.Unlock()
		turn, call, msg := "turn_"+n, "call_"+n, "msg_"+n
		command := func(status string, output, exit any) map[string]any {
			return map[string]any{"type": "commandExecution", "id": call,
				"command": "/bin/zsh -lc 'echo hi'", "cwd": "/w", "processId": nil, "source": "agent", "status": status,
				"commandActions": []any{map[string]any{"type": "unknown", "command": "echo hi"}}, "aggregatedOutput": output, "exitCode": exit, "durationMs": nil}
		}
		item := func(status string, output, exit any) map[string]any {
			return map[string]any{"threadId": p.ThreadID, "turnId": turn, "item": command(status, output, exit)}
		}
		c.keep(p.ThreadID, turn, map[string]any{"type": "userMessage", "id": "u_" + n, "clientId": nil, "content": p.Input},
			command("completed", "hi\n", 0), map[string]any{"type": "agentMessage", "id": msg, "text": "Ran it."})
		f.Notify("turn/started", map[string]any{"threadId": p.ThreadID, "turn": appservertest.TurnOf(turn, "inProgress")})
		f.Notify("item/started", item("inProgress", nil, nil))
		f.Notify("item/commandExecution/outputDelta", map[string]any{"threadId": p.ThreadID, "turnId": turn, "itemId": call, "delta": "hi\n"})
		f.Notify("item/completed", item("completed", "hi\n", 0))
		f.Notify("item/agentMessage/delta", map[string]any{"threadId": p.ThreadID, "turnId": turn, "itemId": msg, "delta": "Ran it."})
		f.Notify("turn/completed", map[string]any{"threadId": p.ThreadID, "turn": appservertest.TurnOf(turn, "completed")})
	})
	c.history(f)
	f.On("thread/archive", appservertest.Reply(map[string]any{}))
	c.mu.Lock()
	c.fakes = append(c.fakes, f)
	c.mu.Unlock()
	_ = codexacp.Serve(context.Background(), r, w, codexacp.Config{CodexPath: "/fake/codex", Spawn: f.Spawn})
}

// A Codex chat through Nushi's Go agent on a fake app-server, with no
// Node and no adapter, reads as one through codex-acp (TestACodexChat):
// the mode, model and effort options (and Codex's collaboration mode), a
// mode picked kept for the next chat, a command's output, the turn's end;
// a rewind forks the thread at a message, cut by Codex; it all comes back
// after a daemon restart, through session/load, and Delete archives the
// thread and its fork; the daemon's stop ends Codex.
func TestACodexChatThroughTheGoAgent(t *testing.T) {
	ctx := context.Background()
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	first := a.start(&nushiv1.StartChatRequest{Agent: "codex-go", Folder: t.TempDir()})
	var ids []string
	for _, o := range a.get(first).Config {
		ids = append(ids, o.Id+"/"+o.Category)
	}
	if got := strings.Join(ids, " "); got != "mode/mode collaboration_mode/collaboration_mode model/model reasoning_effort/thought_level" {
		t.Errorf("options = %s", got)
	}
	must(a.c.SetConfigOption(ctx, connect.NewRequest(&nushiv1.SetConfigOptionRequest{ChatId: first, ConfigId: "mode", Value: "workspace-write"})))
	if mode := modeOf(a.get(a.start(&nushiv1.StartChatRequest{Agent: "codex-go", Folder: t.TempDir()})).Config); mode != "workspace-write" {
		t.Errorf("a new chat starts in %q, want the mode picked last", mode)
	}

	a.send(first, "run it")
	a.waitFor("the turn to end", turnEnded(first))
	want := "USER_MESSAGE:run it:\nTOOL_CALL:```\nhi\n```:completed\nAGENT_MESSAGE:Ran it.:"
	if got := transcript(a.get(first).Items); got != want {
		t.Errorf("transcript:\n%s\nwant:\n%s", got, want)
	}
	d.codexes.mu.Lock()
	fakes := d.codexes.fakes
	d.codexes.mu.Unlock()
	turn := fakes[0].Calls("turn/start")
	if len(turn) != 1 || !strings.Contains(string(turn[0]), `"sandboxPolicy":{"excludeSlashTmp":false,"excludeTmpdirEnvVar":false,"networkAccess":false,"type":"workspaceWrite","writableRoots":[]}`) ||
		!strings.Contains(string(turn[0]), `"approvalsReviewer":"user"`) {
		t.Errorf("turn/start %s, want the workspace-write mode's", turn)
	}
	// A rewind to a second message forks at the first turn's reply: the Go
	// agent asks Codex for the thread up to that reply's turn, and the
	// replay below is the cut thread's.
	a.send(first, "run it again")
	a.waitFor("the second turn to end", turnEnded(first))
	var second string
	for _, it := range a.get(first).Items {
		if it.Kind == nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE && it.Text == "run it again" {
			second = it.Id
		}
	}
	must(a.c.RewindChat(ctx, connect.NewRequest(&nushiv1.RewindChatRequest{ChatId: first, ItemId: second})))
	a.waitFor("the rewind", idle)
	if got := transcript(a.get(first).Items); got != want {
		t.Errorf("rewound:\n%s\nwant:\n%s", got, want)
	}
	if fork := fakes[0].Calls("thread/fork"); len(fork) != 1 || !strings.Contains(string(fork[0]), `"lastTurnId":"turn_`) {
		t.Errorf("thread/fork %s, want one cut at a turn", fork)
	}

	a = d.reopen(t)
	snap := a.get(first)
	if got := transcript(a.follow(first, snap)); got != want {
		t.Errorf("replayed:\n%s\nwant:\n%s", got, want)
	}
	until(t, "the chat to settle", func() bool { return !a.get(first).Status.Busy })
	if st := a.get(first).Status; !st.CanFork || !st.CanRewind { // a fork at a message, as codex-acp (which the fake doesn't play)
		t.Errorf("status = %v, want fork and rewind", st)
	}
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: first})))
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: first})))
	d.stop()
	d.codexes.mu.Lock()
	fakes = d.codexes.fakes
	d.codexes.mu.Unlock()
	resumed, archived := 0, 0
	for _, f := range fakes {
		<-f.Exited()
		resumed += len(f.Calls("thread/resume"))
		archived += len(f.Calls("thread/archive"))
	}
	if resumed == 0 {
		t.Error("the chat came back without session/load")
	}
	if !plan.DeletesHistory || archived != 2 { // the thread and its fork
		t.Errorf("Delete archived %d threads (plan %v)", archived, plan)
	}
}
