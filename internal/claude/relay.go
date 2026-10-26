package claude

import (
	"fmt"
	"regexp"

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
// SendMessage), and to which: the agent's id for it.
func Relaying(it model.Item) string {
	if it.Tool != "SendMessage" {
		return ""
	}
	return it.AgentID
}
