package claudehistory

import (
	"fmt"
	"io/fs"
	"os"
	"path"
	"slices"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/regularfile"
	"github.com/afrase/nushi/internal/secrets"
)

// WorkflowAgents lists the agents of the run w names, in the order they
// started: the snapshot's rows once the run ended, the journal's while it
// runs (as last read by ReadWorkflow, or now when nothing was).
func (l Local) WorkflowAgents(sid, folder string, w model.Workflow) ([]model.WorkflowAgent, error) {
	var agents []model.WorkflowAgent
	err := l.readRun(sid, folder, w, func(r *run, _ *os.Root) error {
		agents = r.agents()
		return nil
	})
	return agents, err
}

func (r *run) agents() []model.WorkflowAgent {
	var out []model.WorkflowAgent
	if s := r.snap; s != nil && len(s.Agents) > 0 {
		for _, a := range s.Agents {
			wa := model.WorkflowAgent{ID: a.ID, Label: label(a.Label, a.ID), Phase: label(a.Phase, ""), State: agentState(a.State),
				Model: clipText(a.Model, 100), Prompt: preview(a.Prompt), Result: preview(a.Result),
				Started: a.Started, Tokens: a.Tokens, ToolCalls: a.ToolCalls}
			if !a.Started.IsZero() && a.Duration > 0 {
				wa.Ended = a.Started.Add(a.Duration)
			}
			out = append(out, wa)
		}
		return out
	}
	for _, row := range r.j.rows {
		state := row.State
		if (r.snap != nil || r.noted() != nil) && state == "running" {
			state = "stopped" // the run ended without it
		}
		wa := model.WorkflowAgent{ID: row.AgentID, Label: label(row.Label, row.AgentID), Phase: label(row.Phase, ""), State: state}
		if a := r.tokens[row.AgentID]; a != nil {
			wa.Tokens = int(a.tokens)
		}
		out = append(out, wa)
	}
	return out
}

// WorkflowAgentItems reads the transcript of agent id of the run w names
// as transcript items, the last limit of them, and how many came before
// those. Only an agent the run's journal or snapshot lists is read, so an
// id never names a file of its own; one it doesn't is fs.ErrNotExist.
func (l Local) WorkflowAgentItems(sid, folder string, w model.Workflow, id string, limit int) ([]model.Item, int, error) {
	var items []model.Item
	earlier := 0
	err := l.readRun(sid, folder, w, func(r *run, root *os.Root) error {
		listed := false
		for _, a := range r.agents() {
			listed = listed || a.ID == id && id != ""
		}
		if !listed || !agentID.MatchString(id) || root == nil {
			return fmt.Errorf("agent %q of workflow %s: %w", id, w.RunID, fs.ErrNotExist)
		}
		// The agent's own file, opened inside the session's folder as a
		// regular file and read as it grows: the path the run's id and a
		// listed agent's id name.
		f, fi, err := regularfile.OpenIn(root, path.Join("subagents", "workflows", w.RunID, "agent-"+id+".jsonl"), false)
		if err != nil {
			return err
		}
		defer f.Close() //nolint:errcheck // read-only
		if r.steps == nil {
			r.steps = map[string]*steps{}
		}
		s := r.steps[id]
		if s == nil {
			s = &steps{prefix: "wf/" + id + "/"}
			r.steps[id] = s
		}
		if err := s.read(f, fi.Size()); err != nil {
			return err
		}
		// Copied here, under the run's lock: the next read settles a
		// call's step in place and shifts the cached steps.
		n := len(s.items)
		if limit > 0 && n > limit {
			n = limit
		}
		items, earlier = slices.Clone(s.items[len(s.items)-n:]), s.dropped+len(s.items)-n
		return nil
	})
	if err != nil {
		return nil, 0, err
	}
	return items, earlier, nil
}

// preview is the start of an agent's task or answer, as the snapshot kept
// it: the model's text, masked as a tool call's text is, cut short.
func preview(s string) string { return clipText(secrets.MaskText(s), 2048) }
