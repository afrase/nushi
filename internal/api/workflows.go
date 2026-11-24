package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

// workflowSteps is how many of an agent's last steps GetWorkflowAgent sends
// when the request names no limit, and the most it sends.
const workflowSteps = 400

func (s *server) GetWorkflow(_ context.Context, req *connect.Request[nushiv1.GetWorkflowRequest]) (*connect.Response[nushiv1.GetWorkflowResponse], error) {
	w, agents, more, err := s.Chats.Workflow(req.Msg.ChatId, req.Msg.CallId)
	if err != nil {
		return nil, workflowErr(err)
	}
	out := &nushiv1.GetWorkflowResponse{Workflow: workflowProto(w), More: more}
	for _, a := range agents {
		out.Agents = append(out.Agents, workflowAgentProto(a))
	}
	return connect.NewResponse(out), nil
}

func (s *server) GetWorkflowAgent(_ context.Context, req *connect.Request[nushiv1.GetWorkflowAgentRequest]) (*connect.Response[nushiv1.GetWorkflowAgentResponse], error) {
	n := int(req.Msg.Limit)
	if n <= 0 || n > workflowSteps {
		n = workflowSteps
	}
	items, earlier, agent, err := s.Chats.WorkflowAgent(req.Msg.ChatId, req.Msg.CallId, req.Msg.AgentId, n)
	if err != nil {
		return nil, workflowErr(err)
	}
	out := &nushiv1.GetWorkflowAgentResponse{Earlier: int32(earlier), Agent: workflowAgentProto(agent)}
	for i := range items {
		out.Items = append(out.Items, itemProto(&items[i], false))
	}
	return connect.NewResponse(out), nil
}

// workflowErr is NotFound for a workflow, agent or chat that isn't there,
// else a refusal.
func workflowErr(err error) error {
	if errors.Is(err, chats.ErrNoWorkflow) {
		return notFound(err)
	}
	return refused(err)
}

func workflowProto(w model.Workflow) *nushiv1.Workflow {
	out := &nushiv1.Workflow{RunId: w.RunID, Name: w.Name, Description: w.Description, State: string(w.State), End: w.End,
		Started: unixMs(w.Started), Ended: unixMs(w.Ended), Active: unixMs(w.Active), Agents: int32(w.Agents), Done: int32(w.Done),
		Failed: int32(w.Failed), Running: w.Running, RunningCount: int32(w.RunningCount), Summary: w.Summary, Stalled: w.Stalled, Tokens: w.Tokens}
	for _, i := range w.RunningPhases {
		out.RunningPhases = append(out.RunningPhases, int32(i))
	}
	for _, p := range w.Phases {
		out.Phases = append(out.Phases, &nushiv1.WorkflowPhase{Title: p.Title, Detail: p.Detail, Started: int32(p.Started), Done: int32(p.Done), Failed: int32(p.Failed)})
	}
	for _, p := range w.Planned {
		out.Planned = append(out.Planned, &nushiv1.WorkflowPhase{Title: p.Title, Detail: p.Detail})
	}
	return out
}

func workflowAgentProto(a model.WorkflowAgent) *nushiv1.WorkflowAgent {
	return &nushiv1.WorkflowAgent{Id: a.ID, Label: a.Label, Phase: a.Phase, State: string(a.State), Model: a.Model, Started: unixMs(a.Started),
		Ended: unixMs(a.Ended), Tokens: int32(min(a.Tokens, 1<<31-1)), ToolCalls: int32(min(a.ToolCalls, 1<<31-1)), Prompt: a.Prompt, Result: a.Result}
}
