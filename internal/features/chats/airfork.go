package chats

import "github.com/afrase/nushi/acp"

// Forking a session at a message, to rewind a chat, uses a vendor extension
// of claude-agent-acp meant for JetBrains AIR: ACP's session/fork copies
// the whole conversation, and only `_meta.jetbrains.air.fork` on the
// request makes the adapter cut the copy after a message (ADR 0020). This
// file is the only place that knows it; drop it when ACP has a standard
// way.

// forksAtMessage reports whether the agent is claude-agent-acp, which
// forks at a message given airFork's meta.
func forksAtMessage(init *acp.InitializeResponse) bool {
	return init.AgentInfo != nil && init.AgentInfo.Name == "@agentclientprotocol/claude-agent-acp"
}

// airFork is session/fork's meta to make the fork end with the agent
// message messageID (an ACP messageId of the session's updates), it
// included.
func airFork(messageID string) map[string]any {
	return map[string]any{"jetbrains": map[string]any{"air": map[string]any{
		"fork": map[string]any{"version": 1, "messageId": messageID}}}}
}
