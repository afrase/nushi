package api

import (
	"cmp"
	"time"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
)

// Conversions between the features' model types and the API's.

func messageProto(m model.Message) *nushiv1.QueuedMessage {
	out := &nushiv1.QueuedMessage{Id: m.ID, Text: m.Text, Files: m.Files, ToSubagent: m.To}
	if m.Relay != nil {
		out.RelayTo = m.Relay.Agent
	}
	for _, img := range m.Images {
		out.Images = append(out.Images, &nushiv1.ImageData{MimeType: img.MimeType, Data: img.Data})
	}
	return out
}

func queueProto(q []model.Message) *nushiv1.ChatQueue {
	out := &nushiv1.ChatQueue{}
	for _, m := range q {
		out.Messages = append(out.Messages, messageProto(m))
	}
	return out
}

var itemKinds = map[model.ItemKind]nushiv1.ItemKind{
	model.UserMessage:  nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE,
	model.AgentMessage: nushiv1.ItemKind_ITEM_KIND_AGENT_MESSAGE,
	model.ToolCall:     nushiv1.ItemKind_ITEM_KIND_TOOL_CALL,
	model.Permission:   nushiv1.ItemKind_ITEM_KIND_PERMISSION,
	model.Question:     nushiv1.ItemKind_ITEM_KIND_QUESTION,
	model.Thought:      nushiv1.ItemKind_ITEM_KIND_THOUGHT,
	model.Plan:         nushiv1.ItemKind_ITEM_KIND_PLAN,
	model.Notice:       nushiv1.ItemKind_ITEM_KIND_NOTICE,
}

var fieldTypes = map[model.FieldType]nushiv1.FieldType{
	model.Text:    nushiv1.FieldType_FIELD_TYPE_TEXT,
	model.Choice:  nushiv1.FieldType_FIELD_TYPE_CHOICE,
	model.Choices: nushiv1.FieldType_FIELD_TYPE_CHOICES,
	model.Number:  nushiv1.FieldType_FIELD_TYPE_NUMBER,
	model.Integer: nushiv1.FieldType_FIELD_TYPE_INTEGER,
	model.Boolean: nushiv1.FieldType_FIELD_TYPE_BOOLEAN,
}

func toProto(e model.Event) *nushiv1.EventsResponse {
	out := &nushiv1.EventsResponse{ChatId: e.ChatID, Seq: e.Seq}
	switch {
	case e.Item != nil:
		out.Kind = &nushiv1.EventsResponse_Item{Item: &nushiv1.ItemEvent{Item: itemProto(e.Item), Append: e.Append}}
	case e.Session != nil:
		out.Kind = &nushiv1.EventsResponse_Chat{Chat: chatProto(*e.Session)}
	case e.Config != nil:
		out.Kind = &nushiv1.EventsResponse_Config{Config: &nushiv1.ChatConfig{Options: configProto(e.Config)}}
	case e.Status != nil:
		out.Kind = &nushiv1.EventsResponse_Status{Status: statusProto(*e.Status)}
	case e.Usage != nil:
		out.Kind = &nushiv1.EventsResponse_Usage{Usage: usageProto(*e.Usage)}
	case e.Removed:
		out.Kind = &nushiv1.EventsResponse_Removed{Removed: true}
	case e.Cut != "":
		out.Kind = &nushiv1.EventsResponse_Cut{Cut: e.Cut}
	case e.Dropped != "":
		out.Kind = &nushiv1.EventsResponse_Dropped{Dropped: e.Dropped}
	case e.Queue != nil:
		out.Kind = &nushiv1.EventsResponse_Queue{Queue: queueProto(*e.Queue)}
	case e.Commands != nil:
		out.Kind = &nushiv1.EventsResponse_Commands{Commands: &nushiv1.ChatCommands{Commands: commandsProto(e.Commands)}}
	case e.Terminals != nil:
		out.Kind = &nushiv1.EventsResponse_Terminals{Terminals: &nushiv1.ChatTerminals{Terminals: terminalsProto(*e.Terminals)}}
	}
	return out
}

func itemProto(it *model.Item) *nushiv1.Item {
	out := &nushiv1.Item{Id: it.ID, Kind: itemKinds[it.Kind], Text: it.Text,
		Title: it.Title, ToolKind: it.ToolKind, Status: it.Status, Answer: it.Answer, Parent: it.Parent, Agent: it.Agent, Tool: it.Tool, ForkAt: it.ForkAt,
		Prompt: it.Prompt, Model: it.Model, Effort: it.Effort, RanModel: it.RanModel, AgentId: it.AgentID, RelayTo: it.RelayTo,
		Rewindable: it.Rewindable, Report: it.Report}
	if sh := it.Shell; sh != nil {
		out.Shell = &nushiv1.Shell{Id: sh.ID, State: sh.State, Started: unixMs(sh.Started), Ended: unixMs(sh.Ended), Output: sh.Output, End: sh.End}
	}
	if sa := it.Subagent; sa != nil {
		out.Subagent = &nushiv1.Subagent{State: sa.State, Started: unixMs(sa.Started), Ended: unixMs(sa.Ended), Result: sa.Result}
	}
	out.Options = optionsProto(it.Options)
	out.Paths = it.Paths
	for _, img := range it.Images {
		out.Images = append(out.Images, &nushiv1.ImageData{MimeType: img.MimeType, Data: img.Data})
	}
	for _, e := range it.Plan {
		out.Plan = append(out.Plan, &nushiv1.PlanEntry{Content: e.Content, Status: e.Status})
	}
	for _, d := range it.Diffs {
		out.Diffs = append(out.Diffs, &nushiv1.FileChange{Path: d.Path, Status: d.Status, OldText: d.Old, NewText: d.New})
	}
	for _, f := range it.Fields {
		out.Fields = append(out.Fields, &nushiv1.Field{Id: f.ID, Title: f.Title, Description: f.Description,
			Type: fieldTypes[f.Type], Options: optionsProto(f.Options), Required: f.Required, Values: f.Values, OtherFor: f.OtherFor})
	}
	return out
}

func commandsProto(cmds []model.Command) []*nushiv1.Command {
	var out []*nushiv1.Command
	for _, c := range cmds {
		out = append(out, &nushiv1.Command{Name: c.Name, Description: c.Description, Hint: c.Hint})
	}
	return out
}

func usageProto(u model.Usage) *nushiv1.Usage {
	return &nushiv1.Usage{ContextUsed: u.Used, ContextSize: u.Size, Cost: u.Cost, Currency: u.Currency,
		InputTokens: u.Input, OutputTokens: u.Output, CachedReadTokens: u.CachedRead, CachedWriteTokens: u.CachedWrite}
}

func statusProto(st model.Status) *nushiv1.ChatStatus {
	return &nushiv1.ChatStatus{Busy: st.Busy, Waiting: st.Waiting, CanFork: st.CanFork, Images: st.Images, CanRewind: st.CanRewind,
		McpChanged: st.MCPChanged, Started: unixMs(st.Started), CanAskContext: st.CanAskContext, Asleep: st.Asleep, CanSleep: st.CanSleep}
}

// unixMs is t in Unix milliseconds, 0 for the zero time.
func unixMs(t time.Time) int64 {
	if t.IsZero() {
		return 0
	}
	return t.UnixMilli()
}

func optionsProto(opts []model.Option) []*nushiv1.Option {
	var out []*nushiv1.Option
	for _, o := range opts {
		out = append(out, &nushiv1.Option{Id: o.ID, Name: o.Name, Kind: o.Kind, Description: o.Description})
	}
	return out
}

func configProto(opts []model.ConfigOption) []*nushiv1.ConfigOption {
	var out []*nushiv1.ConfigOption
	for _, o := range opts {
		co := &nushiv1.ConfigOption{Id: o.ID, Name: o.Name, Description: o.Description,
			Category: o.Category, Type: o.Type, Current: o.Current}
		for _, v := range o.Values {
			co.Values = append(co.Values, &nushiv1.ConfigValue{Value: v.Value, Name: v.Name, Description: v.Description, Group: v.Group, IsDefault: v.Default})
		}
		out = append(out, co)
	}
	return out
}

func chatProto(s model.Session) *nushiv1.Chat {
	out := &nushiv1.Chat{Id: s.ID, Agent: s.Agent, Folder: s.Folder, Title: cmp.Or(s.Name, s.Title), Mode: s.Mode,
		CreatedUnixMs: s.Created.UnixMilli(), Archived: s.Archived, SessionId: s.SessionID, Scratch: s.Scratch}
	if wt := s.Worktree; wt != nil {
		out.Worktree = &nushiv1.Worktree{Repo: wt.Repo, Path: wt.Path, Branch: wt.Branch, Base: wt.Base, BaseCommit: wt.BaseCommit}
	}
	return out
}
