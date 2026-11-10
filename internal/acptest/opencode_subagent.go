package acptest

import (
	"encoding/json"
	"maps"
)

// subagentJob is what the fake's subagent is asked to do: its session's
// title, which opencode puts before the titles of its tool calls.
const subagentJob = "Do a small job"

// opencodeChild is a subagent's session, as opencode tells the client of
// its parent session, root, about it (docs/facts/opencode.md, Turns).
type opencodeChild struct {
	a        *Agent
	root, id string
}

// meta marks an update or a permission request as the child's.
func (c opencodeChild) meta() map[string]any {
	return map[string]any{"opencode/child-session": map[string]any{"id": c.id, "parentID": c.root, "depth": 1, "title": subagentJob}}
}

// notify sends opencode's own notification about the child, which isn't a
// session/update: its status, or one of its updates.
func (c opencodeChild) notify(what map[string]any) {
	p := map[string]any{"rootSessionId": c.root, "childSessionId": c.id, "parentSessionId": c.root, "depth": 1, "title": subagentJob}
	maps.Copy(p, what)
	b, _ := json.Marshal(p)
	c.a.send(frame{Method: "opencode/session/child_update", Params: b})
}

// wanted says the client asked, in initialize, for the child's updates as
// notifications of their own.
func (c opencodeChild) wanted() bool {
	c.a.mu.Lock()
	defer c.a.mu.Unlock()
	return c.a.childUpdates
}

// status tells a client that asked for child updates how the child is
// doing; the fake tells another nothing of it.
func (c opencodeChild) status(s string) {
	if c.wanted() {
		c.notify(map[string]any{"type": "status", "status": s})
	}
}

// update sends one of the child's session updates: as a child update to a
// client that asked for them, else among the parent's own, with only its
// _meta to tell it by. The parent's history keeps neither.
func (c opencodeChild) update(u map[string]any) {
	u = maps.Clone(u)
	u["_meta"] = c.meta()
	if c.wanted() {
		c.notify(map[string]any{"type": "update", "update": u})
		return
	}
	c.a.live(c.root, u)
}

func (c opencodeChild) say(text string) {
	c.update(map[string]any{"sessionUpdate": "agent_message_chunk", "content": map[string]any{"type": "text", "text": text}})
}

// opencodeSubagent plays opencode's subagent tool as a run of opencode
// 2.2.6 showed it: the parent's call, in progress twice, and a child
// session that says a line, runs a shell command after asking, and says
// another. What the child does never comes as the parent's tool calls or
// text, yet its permission is asked on the parent's session, for a call
// the parent never sent, "<child session>:<id>". Allowed, the parent's
// call completes with the child's last message, and the child says one
// thing more once the prompt is answered, as a background child's updates
// go on after its parent's turn. Rejected, the child is interrupted and
// the parent's call fails "Subagent cancelled". Either way the parent's
// turn goes on to its end; only a cancelled request ends it "cancelled".
func (a *Agent) opencodeSubagent(session string) string {
	a.mu.Lock()
	cwd := a.cwds[session]
	a.mu.Unlock()
	input := map[string]any{"agent": "general", "description": subagentJob, "prompt": "Say a line, run echo from-child, say another."}
	id := a.opencodeTool(session, "subagent", "think", input, []map[string]any{})
	c := opencodeChild{a: a, root: session, id: "ses_child_of_" + id}
	c.status("created")
	a.update(session, map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": id, "status": "in_progress", "kind": "think", "title": "subagent",
		"locations": []any{}, "rawInput": input})
	c.status("running")
	c.say("Child starts.")

	call, at := c.id+":"+a.opencodeCall(), []map[string]any{{"path": cwd}}
	run := map[string]any{"command": "echo from-child", "cwd": cwd}
	c.update(map[string]any{"sessionUpdate": "tool_call", "toolCallId": call, "name": "shell", "title": subagentJob + ": shell", "kind": "execute",
		"status": "pending", "locations": at, "rawInput": map[string]any{"cwd": cwd}})
	running := map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": call, "status": "in_progress", "kind": "execute",
		"title": subagentJob + ": echo from-child", "locations": at, "rawInput": run}
	c.update(running)
	outcome, option := a.opencodeAsk(session, map[string]any{"toolCallId": call, "name": "shell", "title": "echo from-child", "kind": "execute",
		"status": "pending", "locations": at, "rawInput": run, "_meta": c.meta()})
	if outcome != "selected" || option == "reject" {
		c.update(opencodeEnd(call, "The user declined this tool call", true, map[string]any{}))
		c.status("interrupted")
		gone := "Subagent cancelled (sessionID: " + c.id + ")"
		a.update(session, opencodeEnd(id, gone, true, map[string]any{"sessionID": c.id, "status": "running"}))
		if outcome != "selected" {
			return "cancelled"
		}
		a.say(session, "Parent done.")
		return "end_turn"
	}
	c.update(running)
	c.update(opencodeEnd(call, "from-child\n", false, map[string]any{"status": "completed", "truncated": false, "exit": 0}))
	c.say("Child finished.")
	c.status("completed")
	a.update(session, opencodeEnd(id, `<subagent sessionID="`+c.id+`" state="completed">`+"\nChild finished.\n</subagent>", false,
		map[string]any{"sessionID": c.id, "status": "completed", "truncated": false}))
	a.say(session, "Parent done.")
	a.mu.Lock()
	if a.after == nil {
		a.after = map[string]func(){}
	}
	a.after[session] = func() { c.say("Child, later.") }
	a.mu.Unlock()
	return "end_turn"
}
