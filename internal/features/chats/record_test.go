package chats

import (
	"log/slog"
	"slices"
	"sync"
	"testing"
	"testing/synctest"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// memRecord is a Record kept in memory.
type memRecord struct {
	mu    sync.Mutex
	owned map[string][]model.Process
}

func (r *memRecord) Put(owner string, ps []model.Process) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.owned[owner] = ps
}

func (r *memRecord) Drop(owner string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.owned, owner)
}

// pids is owner's processes' pids; nil when it has none recorded.
func (r *memRecord) pids(owner string) []int {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []int
	for _, p := range r.owned[owner] {
		out = append(out, p.Pid)
	}
	return out
}

// groupAgent is an agent whose clean stop ends its process group, as
// agentproc's does for every agent not stopped by signal.
type groupAgent struct{ Agent }

func (a groupAgent) StopEnds(p model.Process) bool { return p.Pgid == a.Pid() }

// What a clean stop of a live agent would end is recorded, its own group,
// and not a background command leading a group of its own below it,
// which outlives the stop (ADR 0032, 0130); it is dropped as the agent
// ends.
func TestTheRecordHoldsWhatAStopWouldEnd(t *testing.T) {
	agent := &fakeAgent{pid: agentPid}
	member := model.Process{Pid: agentPid + 1, Pgid: agentPid}      // an MCP server, in its group
	command := model.Process{Pid: agentPid + 2, Pgid: agentPid + 2} // a Bash command, Claude's way
	procs := &fakeProcesses{below: map[int][]model.Process{agentPid: {member, command}}}
	rec := &memRecord{owned: map[string][]model.Process{}}
	launch := func(h acp.Client, log *slog.Logger) (Agent, error) {
		a, err := agent.launch(h, log)
		if err != nil {
			return nil, err
		}
		return groupAgent{a}, nil
	}
	synctest.Test(t, func(t *testing.T) { // the record is looked at each sleepCheck: a minute of the bubble's clock
		svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: launch}}, Options{Processes: procs, Record: rec})
		t.Cleanup(svc.Close)
		startChat(t, svc, t.TempDir())
		owner := agentOwner(agentPid)
		pass(time.Minute)
		if got := rec.pids(owner); !slices.Equal(got, []int{agentPid, member.Pid}) {
			t.Errorf("recorded %v, want the agent and its group's member", got)
		}
		agent.quit()
		synctest.Wait()
		if got := rec.pids(owner); got != nil {
			t.Errorf("the ended agent's processes stay recorded: %v", got)
		}
	})
}

// An agent is recorded as it starts, not first at the next minute's tick:
// a daemon that crashes before then leaves it to the next one's sweep too.
func TestAnAgentIsRecordedAsItStarts(t *testing.T) {
	agent := &fakeAgent{pid: agentPid}
	procs := &fakeProcesses{below: map[int][]model.Process{}}
	rec := &memRecord{owned: map[string][]model.Process{}}
	launch := func(h acp.Client, log *slog.Logger) (Agent, error) {
		a, err := agent.launch(h, log)
		if err != nil {
			return nil, err
		}
		return groupAgent{a}, nil
	}
	synctest.Test(t, func(t *testing.T) { // the bubble's clock never moves: no tick comes
		svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: launch}}, Options{Processes: procs, Record: rec})
		t.Cleanup(svc.Close)
		startChat(t, svc, t.TempDir())
		owner := agentOwner(agentPid)
		synctest.Wait()
		if got := rec.pids(owner); !slices.Equal(got, []int{agentPid}) {
			t.Errorf("recorded before any tick: %v", got)
		}
		agent.quit()
		synctest.Wait()
		if got := rec.pids(owner); got != nil {
			t.Errorf("the ended agent stays recorded: %v", got)
		}
	})
}
