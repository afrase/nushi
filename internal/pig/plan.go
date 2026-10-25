package pig

import (
	"encoding/json"

	acp "github.com/afrase/acp-go/unstable"
)

// planOf reads a todo list an extension keeps as the agent's plan: a
// `todos` list, each with its text and whether it's done (`done` or
// `completed`), as Pi's todo extension puts in its tool's results and its
// plan-mode extension in its entries. Nil when raw holds none (an empty
// list included).
func planOf(raw json.RawMessage) *acp.SessionUpdate {
	var v struct {
		Todos []struct {
			Text      string `json:"text"`
			Done      *bool  `json:"done"`
			Completed *bool  `json:"completed"`
		} `json:"todos"`
	}
	if len(raw) == 0 || json.Unmarshal(raw, &v) != nil || len(v.Todos) == 0 {
		return nil
	}
	plan := &acp.Plan{}
	for _, t := range v.Todos {
		done := t.Done
		if done == nil {
			done = t.Completed
		}
		if t.Text == "" || done == nil {
			return nil
		}
		status := acp.PlanEntryStatusPending
		if *done {
			status = acp.PlanEntryStatusCompleted
		}
		plan.Entries = append(plan.Entries, acp.PlanEntry{Content: t.Text, Status: status, Priority: acp.PlanEntryPriorityMedium})
	}
	return &acp.SessionUpdate{SessionUpdate: "plan", Plan: plan}
}
