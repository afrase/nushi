package claudehistory

import (
	"encoding/json"
	"math"
	"strconv"
	"time"
)

// maxSnapshot is the most of a workflow's snapshot read: the largest seen
// was under 2 MB.
const maxSnapshot = 16 << 20

// snapshot is what Claude writes of a workflow as it ends
// (workflows/<run>.json; docs/facts/claude.md): only once it ended, so its
// being there is the end. Every field is read loosely: a number may be a
// string, a missing one is zero.
type snapshot struct {
	Status, TaskID, Name, Summary, Error string
	Started                              time.Time
	Duration                             time.Duration
	AgentCount                           int
	Tokens                               int64 // totalTokens: its agents' tokens
	Phases                               []snapshotPhase
	Agents                               []snapshotAgent
}

type snapshotPhase struct{ Title, Detail string }

// snapshotAgent is a workflow_agent row of the snapshot's workflowProgress.
// Cached says a resume served its result from an earlier launch's.
type snapshotAgent struct {
	ID, Label, Phase, State, Model, Prompt, Result string
	Started                                        time.Time
	Duration                                       time.Duration
	Tokens, ToolCalls                              int
	Cached                                         bool
}

// readSnapshot reads a snapshot's JSON; an error only when it isn't a JSON
// object (one being written, say). One with no status is completed, or
// failed when it has an error, as Claude 2.1.325's own loader reads it.
func readSnapshot(data []byte) (snapshot, error) {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return snapshot{}, err
	}
	s := snapshot{Status: str(raw["status"]), TaskID: str(raw["taskId"]), Name: str(raw["workflowName"]), Summary: str(raw["summary"]),
		Error: str(raw["error"]), Started: ms(raw["startTime"]), Duration: time.Duration(num(raw["durationMs"])) * time.Millisecond,
		AgentCount: int(num(raw["agentCount"])), Tokens: num(raw["totalTokens"])}
	if _, ok := raw["status"]; !ok { // as Claude's own reader takes one without
		s.Status = "completed"
		if s.Error != "" {
			s.Status = "failed"
		}
	}
	var phases []map[string]json.RawMessage
	_ = json.Unmarshal(raw["phases"], &phases)
	for _, p := range phases {
		if t := str(p["title"]); t != "" {
			s.Phases = append(s.Phases, snapshotPhase{Title: t, Detail: str(p["detail"])})
		}
	}
	var progress []map[string]json.RawMessage
	_ = json.Unmarshal(raw["workflowProgress"], &progress)
	for _, p := range progress {
		if str(p["type"]) != "workflow_agent" {
			continue
		}
		s.Agents = append(s.Agents, snapshotAgent{ID: str(p["agentId"]), Label: str(p["label"]), Phase: str(p["phaseTitle"]),
			State: str(p["state"]), Model: str(p["model"]), Prompt: str(p["promptPreview"]), Result: str(p["resultPreview"]),
			Started: ms(p["startedAt"]), Duration: time.Duration(num(p["durationMs"])) * time.Millisecond,
			Tokens: int(num(p["tokens"])), ToolCalls: int(num(p["toolCalls"])), Cached: string(p["cached"]) == "true"})
	}
	return s, nil
}

// str is a JSON string's value; "" for anything else.
func str(raw json.RawMessage) string {
	var s string
	if json.Unmarshal(raw, &s) != nil {
		return ""
	}
	return s
}

// num is a JSON number's value, or a string's that holds one; 0 for
// anything else, a negative one, or one too large to be a count.
func num(raw json.RawMessage) int64 {
	var f float64
	if json.Unmarshal(raw, &f) != nil {
		if n, err := strconv.ParseFloat(str(raw), 64); err == nil {
			f = n
		}
	}
	if f < 0 || f > 1e15 || math.IsNaN(f) {
		return 0
	}
	return int64(f)
}

// ms is a time in Unix milliseconds, or an RFC 3339 string; zero for
// anything else.
func ms(raw json.RawMessage) time.Time {
	if n := num(raw); n > 0 {
		return time.UnixMilli(n)
	}
	if t, err := time.Parse(time.RFC3339Nano, str(raw)); err == nil {
		return t
	}
	return time.Time{}
}
