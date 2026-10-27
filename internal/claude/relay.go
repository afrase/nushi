package claude

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// subagentID finds a subagent's id in its Agent call's output: a background
// one's "agentId: <id>", a foreground one's pointer to its report.
var subagentID = regexp.MustCompile(`(?:\nagentId: |delivered to you as a message from ")([0-9a-z]+)`)

// SubagentID reads the id Claude gives a subagent from its Agent call's
// output, "" when it says none.
func SubagentID(output string) string {
	if m := subagentID.FindStringSubmatch(output); m != nil {
		return m[1]
	}
	return ""
}

// Relay asks Claude to pass text to one of its subagents unchanged, with
// its SendMessage tool, which runs a finished subagent again. Claude Code
// has no way for a client to reach a subagent itself.
func Relay(agent, agentID, text string) string {
	return fmt.Sprintf("Forward the message below, verbatim, to your %s subagent whose agentId is %s, with the SendMessage tool "+
		"(to: that agentId). Don't act on it yourself and don't change it. When its reply comes back, pass it on to me.\n\n"+
		"<message>\n%s\n</message>", agent, agentID, text)
}

var relayed = regexp.MustCompile(`(?s)^Forward the message below, verbatim, to your (.+?) subagent whose agentId is ([0-9a-z]+), with the SendMessage tool .*?\n\n<message>\n(.*)\n</message>$`)

// Relayed reads a prompt Relay made: the subagent's type and id, and the
// message.
func Relayed(prompt string) (agent, agentID, text string, ok bool) {
	m := relayed.FindStringSubmatch(prompt)
	if m == nil {
		return "", "", "", false
	}
	return m[1], m[2], m[3], true
}

// Relaying says a tool call is Claude passing a message to a subagent (its
// SendMessage), or stopping a background task (its TaskStop), and which:
// the agent's id for it.
func Relaying(it model.Item) string {
	switch it.Tool {
	case "SendMessage":
		return it.AgentID
	case "TaskStop":
		return it.Stops
	}
	return ""
}

// StopTask asks Claude to stop one of its background tasks, a subagent or a
// command (what names it), with its TaskStop tool, by the task's id: a
// subagent's agentId, a command's background task id. A client that
// isn't JetBrains AIR has no way to stop one itself
// (_session/async_task/stop answers {stopped: false}).
func StopTask(what, taskID string) string {
	what, _, _ = strings.Cut(what, "\n")
	if r := []rune(what); len(r) > 80 {
		what = string(r[:79]) + "…"
	}
	return fmt.Sprintf("Stop your background task %s (%s) now with your TaskStop tool (task_id: %s). "+
		"Do nothing else, and say only whether it stopped.", taskID, what, taskID)
}

var stopRelayed = regexp.MustCompile(`^Stop your background task ([0-9a-z]+) \((.*)\) now with your TaskStop tool \(task_id: ([0-9a-z]+)\)\. Do nothing else, and say only whether it stopped\.$`)

// StopRelayed reads a prompt StopTask made: what it names, and the task's
// id.
func StopRelayed(prompt string) (what, taskID string, ok bool) {
	m := stopRelayed.FindStringSubmatch(prompt)
	if len(m) != 4 || m[1] != m[3] {
		return "", "", false
	}
	return m[2], m[1], true
}

// Stopped says a tool call is Claude's TaskStop having stopped a task, or
// having found it no longer running ("Task <id> is not running (status:
// killed)", an error): the task's id.
func Stopped(it model.Item) string {
	switch {
	case it.Tool != "TaskStop":
		return ""
	case it.Status == "completed", it.Status == "failed" && strings.Contains(it.Text, it.Stops+" is not running"):
		return it.Stops
	}
	return ""
}
