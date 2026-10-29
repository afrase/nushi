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

// ToSubagent asks Claude to pass text to one of its subagents unchanged,
// with its SendMessage tool, which runs a finished subagent again. Claude Code
// has no way for a client to reach a subagent itself.
func ToSubagent(agent, agentID, text string) string {
	return fmt.Sprintf("Forward the message below, verbatim, to your %s subagent whose agentId is %s, with the SendMessage tool "+
		"(to: that agentId). Don't act on it yourself and don't change it. When its reply comes back, pass it on to me.\n\n"+
		"<message>\n%s\n</message>", agent, agentID, text)
}

var toSubagentPrompt = regexp.MustCompile(`(?s)^Forward the message below, verbatim, to your (.+?) subagent whose agentId is ([0-9a-z]+), with the SendMessage tool .*?\n\n<message>\n(.*)\n</message>$`)

// ReadToSubagent reads a prompt ToSubagent made: the subagent's type and
// id, and the message.
func ReadToSubagent(prompt string) (agent, agentID, text string, ok bool) {
	m := toSubagentPrompt.FindStringSubmatch(prompt)
	if m == nil {
		return "", "", "", false
	}
	return m[1], m[2], m[3], true
}

// PassesToSubagent says a tool call is Claude passing a message to a
// subagent (its SendMessage), or stopping a background task (its
// TaskStop), and which: the agent's id for it.
func PassesToSubagent(it model.Item) string {
	switch it.Tool {
	case "SendMessage":
		return it.AgentID
	case "TaskStop":
		return it.Stops
	}
	return ""
}

// StopTask asks Claude to stop one of its background tasks with its
// TaskStop tool, by the task's id: a subagent's agentId, or a background
// command's task id when Nushi couldn't stop the command itself. A client
// that isn't JetBrains AIR has no way to stop a subagent itself
// (_session/async_task/stop answers {stopped: false}). The prompt is as
// short as Claude reads reliably: the id and the one reply wanted; what
// the task is shows from the call it names.
func StopTask(taskID string) string {
	return fmt.Sprintf(`Stop background task %s: call TaskStop with task_id "%s", then reply only "stopped" or "not running".`, taskID, taskID)
}

var (
	stopTaskPrompt    = regexp.MustCompile(`^Stop background task ([0-9a-z]+): call TaskStop with task_id "([0-9a-z]+)", then reply only "stopped" or "not running"\.$`)
	oldStopTaskPrompt = regexp.MustCompile(`^Stop your background task ([0-9a-z]+) \((.*)\) now with your TaskStop tool \(task_id: ([0-9a-z]+)\)\. Do nothing else, and say only whether it stopped\.$`)
)

// ReadStopTask reads a prompt StopTask made: the task's id, and what the
// prompt names it ("" for today's, which names it by its id only; before,
// a label of 80 characters at most).
func ReadStopTask(prompt string) (what, taskID string, ok bool) {
	if m := stopTaskPrompt.FindStringSubmatch(prompt); len(m) == 3 && m[1] == m[2] {
		return "", m[1], true
	}
	if m := oldStopTaskPrompt.FindStringSubmatch(prompt); len(m) == 4 && m[1] == m[3] {
		return m[2], m[1], true
	}
	return "", "", false
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
