package chats

import (
	"maps"
	"slices"
	"strconv"

	"github.com/afrase/nushi/internal/model"
)

// A daemon that crashes leaves its agents to end on their input's end,
// which can leave what a clean stop would have ended: opencode's shells
// (docs/facts/opencode.md), a hung agent's group. As each agent starts,
// and each minute after, the chats record what a clean stop of it would
// end, for the next daemon to stop (proctree.Record), and drop it once
// the agent ends. What outlives a clean stop isn't recorded, so a crash
// ends no more than a stop does: Claude's and Ante's background commands
// each lead a group of their own, and outlive their agent (ADR 0032,
// 0130).

// Record keeps the processes the daemon owns, by owner, for the next
// daemon to stop after a crash (proctree.Record).
type Record interface {
	Put(owner string, ps []model.Process)
	Drop(owner string)
}

// stopEnder is an agent that says whether its clean stop ends p, its own
// process or one below it (agentproc.Agent's StopEnds).
type stopEnder interface {
	StopEnds(p model.Process) bool
}

// recordAgents puts in the record what a clean stop of each live agent
// would end, as it is now.
func (s *Service) recordAgents() {
	if s.record == nil || s.procs == nil {
		return
	}
	s.mu.Lock()
	live := slices.Collect(maps.Keys(s.live))
	s.mu.Unlock()
	for _, agent := range live {
		s.recordAgent(agent)
	}
}

// recordAgent puts in the record what a clean stop of agent would end, as
// it is now: on each tick, and as it starts (started), so one a crash
// takes before the next tick is swept too.
func (s *Service) recordAgent(agent Agent) {
	ender, ok := agent.(stopEnder)
	pid := agent.Pid()
	if s.record == nil || s.procs == nil || !ok || pid <= 0 {
		return
	}
	self, err := s.procs.Get(pid)
	if err != nil {
		return // it ended: dropAgent drops it
	}
	below, err := s.procs.Under(pid)
	if err != nil {
		return
	}
	var ends []model.Process
	for _, p := range append([]model.Process{self}, below...) {
		if ender.StopEnds(p) {
			ends = append(ends, p)
		}
	}
	s.record.Put(agentOwner(pid), ends)
	select {
	case <-agent.Done(): // it ended as it was read: dropAgent may have run first
		s.record.Drop(agentOwner(pid))
	default:
	}
}

// dropAgent forgets an agent's processes in the record, once it ended.
func (s *Service) dropAgent(agent Agent) {
	if s.record != nil && agent.Pid() > 0 {
		s.record.Drop(agentOwner(agent.Pid()))
	}
}

// agentOwner is the record's owner of the agent whose process is pid.
func agentOwner(pid int) string { return "agent " + strconv.Itoa(pid) }
