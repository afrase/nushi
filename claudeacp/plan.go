package claudeacp

import (
	"cmp"
	"encoding/json"
	"regexp"
	"slices"
	"strings"
	"sync"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// The session's plan: claude's to-do list, as ACP's plan updates, each
// the whole list. Claude keeps one with TodoWrite, whose input is the
// list, or (with its task tools, in a session with no terminal) with
// TaskCreate, TaskUpdate and TaskList, whose results say what changed.
// These calls of the main agent's aren't shown as tool calls: the plan
// is what they do. A subagent's are, as its own steps.

// planTools are the tools whose calls are the plan.
var planTools = []string{"TodoWrite", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet"}

// isPlanTool says a call of the tool name in a stream ("" at the top) is
// the plan's.
func isPlanTool(stream, name string) bool { return stream == "" && slices.Contains(planTools, name) }

// plan is the session's plan and the task tools' calls waiting for their
// results. Each new plan goes to the client under mu, so the last the
// client has is the plan.
type plan struct {
	send func(acp.SessionUpdate) // to the client, on the session

	mu      sync.Mutex
	calls   map[string]planCall // by tool use id
	tasks   map[string]*task
	order   []string // the tasks' ids, as they came
	entries []acp.PlanEntry
	shown   bool // the client has a plan
}

type planCall struct {
	name  string
	input json.RawMessage
}

// task is one of the task tools' tasks.
type task struct {
	ID         string `json:"id"`
	Subject    string `json:"subject"`
	Status     string `json:"status"`
	ActiveForm string `json:"activeForm"`
}

func (p *plan) init(send func(acp.SessionUpdate)) {
	p.send, p.calls, p.tasks = send, map[string]planCall{}, map[string]*task{}
}

// input is a plan tool's call with its whole input: TodoWrite's is the
// plan; a task tool's waits for its result.
func (p *plan) input(b claudeagent.Block) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if b.Name != "TodoWrite" {
		p.calls[b.ID] = planCall{name: b.Name, input: b.Input}
		return
	}
	var in struct {
		Todos []struct {
			Content    string `json:"content"`
			Status     string `json:"status"`
			ActiveForm string `json:"activeForm"`
		} `json:"todos"`
	}
	if json.Unmarshal(b.Input, &in) != nil || in.Todos == nil {
		return
	}
	entries := []acp.PlanEntry{}
	for _, t := range in.Todos {
		entries = append(entries, entry(t.Content, t.ActiveForm, t.Status))
	}
	p.sendLocked(entries)
}

// result is a tool's result, if it is a task tool's: the tasks change as
// it says. structured is the tool's own output, when claude gave it.
func (p *plan) result(b claudeagent.Block, structured json.RawMessage) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	call, ok := p.calls[b.ToolUseID]
	if !ok {
		return false
	}
	delete(p.calls, b.ToolUseID)
	if b.IsError {
		return true
	}
	text, _ := resultParts(b.Content)
	var in struct {
		task
		TaskID string `json:"taskId"`
	}
	_ = json.Unmarshal(call.input, &in)
	switch call.name {
	case "TaskCreate":
		id := createdID(structured, text)
		if id == "" {
			return true
		}
		in.ID, in.Status = id, "pending"
		if p.tasks[id] == nil {
			p.order = append(p.order, id)
		}
		p.tasks[id] = &in.task
	case "TaskUpdate":
		t := p.tasks[in.TaskID]
		switch {
		case t == nil:
			return true
		case in.Status == "deleted":
			delete(p.tasks, in.TaskID)
			p.order = slices.DeleteFunc(p.order, func(id string) bool { return id == in.TaskID })
		default:
			t.Subject = cmp.Or(in.Subject, t.Subject)
			t.Status = cmp.Or(in.Status, t.Status)
			t.ActiveForm = cmp.Or(in.ActiveForm, t.ActiveForm)
		}
	case "TaskList":
		tasks, ok := listed(structured, text)
		if !ok {
			return true
		}
		p.tasks, p.order = map[string]*task{}, nil
		for _, t := range tasks {
			p.tasks[t.ID] = &t
			p.order = append(p.order, t.ID)
		}
	default: // TaskGet changes nothing
		return true
	}
	entries := []acp.PlanEntry{}
	for _, id := range p.order {
		t := p.tasks[id]
		entries = append(entries, entry(t.Subject, t.ActiveForm, t.Status))
	}
	p.sendLocked(entries)
	return true
}

// entry is a task as a plan's entry: what is under way says so in its
// active form ("Running the tests").
func entry(content, active, status string) acp.PlanEntry {
	st := acp.PlanEntryStatus(status)
	if st != acp.PlanEntryStatusInProgress && st != acp.PlanEntryStatusCompleted {
		st = acp.PlanEntryStatusPending
	}
	if st == acp.PlanEntryStatusInProgress && active != "" {
		content = active
	}
	return acp.PlanEntry{Content: content, Status: st, Priority: acp.PlanEntryPriorityMedium}
}

// sendLocked makes entries the plan, and tells the client.
func (p *plan) sendLocked(entries []acp.PlanEntry) {
	p.entries, p.shown = entries, true
	p.send(acp.SessionUpdate{SessionUpdate: "plan", Plan: &acp.Plan{Entries: entries}})
}

// again shows the plan again as a prompt starts, while some of it is
// left to do.
func (p *plan) again() {
	p.mu.Lock()
	defer p.mu.Unlock()
	if slices.ContainsFunc(p.entries, func(e acp.PlanEntry) bool { return e.Status != acp.PlanEntryStatusCompleted }) {
		p.sendLocked(p.entries)
	}
}

// reset is the conversation starting over: the plan is empty.
func (p *plan) reset() {
	p.mu.Lock()
	defer p.mu.Unlock()
	shown := p.shown
	p.calls, p.tasks, p.order, p.entries = map[string]planCall{}, map[string]*task{}, nil, nil
	if shown {
		p.sendLocked([]acp.PlanEntry{})
	}
}

var (
	// createdText is how TaskCreate's text names the task it made.
	createdText = regexp.MustCompile(`Task #(\S+) created`)
	// listedLine is a task in TaskList's text: "#id [status] subject",
	// maybe followed by its owner and what blocks it.
	listedLine = regexp.MustCompile(`^#(\S+) \[([a-z_]+)\] (.*?)(?: \([^()]*\))?(?: \[blocked by [^\]]*\])?$`)
)

// createdID is the id of the task TaskCreate made, from its output.
func createdID(structured json.RawMessage, text string) string {
	var out struct {
		Task struct {
			ID json.RawMessage `json:"id"`
		} `json:"task"`
		ID json.RawMessage `json:"id"`
	}
	if json.Unmarshal(structured, &out) == nil {
		if id := idString(out.Task.ID, out.ID); id != "" {
			return id
		}
	}
	if m := createdText.FindStringSubmatch(text); m != nil {
		return m[1]
	}
	return ""
}

// listed are the tasks TaskList's output lists.
func listed(structured json.RawMessage, text string) ([]task, bool) {
	var out struct {
		Tasks []struct {
			ID         json.RawMessage `json:"id"`
			Subject    string          `json:"subject"`
			Status     string          `json:"status"`
			ActiveForm string          `json:"activeForm"`
		} `json:"tasks"`
	}
	if json.Unmarshal(structured, &out) == nil && out.Tasks != nil {
		var tasks []task
		for _, t := range out.Tasks {
			tasks = append(tasks, task{ID: idString(t.ID), Subject: t.Subject, Status: t.Status, ActiveForm: t.ActiveForm})
		}
		return tasks, true
	}
	var tasks []task
	for line := range strings.Lines(text) {
		if m := listedLine.FindStringSubmatch(strings.TrimSpace(line)); m != nil {
			tasks = append(tasks, task{ID: m[1], Status: m[2], Subject: m[3]})
		}
	}
	return tasks, tasks != nil
}

// idString is the first id given, a string or a number, as a string.
func idString(ids ...json.RawMessage) string {
	for _, raw := range ids {
		var s string
		if json.Unmarshal(raw, &s) == nil && s != "" {
			return s
		}
		var n json.Number
		if json.Unmarshal(raw, &n) == nil && n != "" {
			return n.String()
		}
	}
	return ""
}
