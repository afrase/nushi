// Package claudeacp is an ACP agent for Claude: it speaks the Agent
// Client Protocol to a client on one side and runs each session on the
// user's own claude CLI, through claudeagent, on the other.
//
// It is unofficial and not affiliated with Anthropic, and it contains no
// authentication code: claude signs in as it always does.
//
// Its behaviour follows claude-agent-acp, the Node agent it replaces, so
// a client written for that one works with this one: the same session
// ids (claude's own), message ids (the Messages API's), _meta keys and
// turn ends. The code is written fresh; where a piece is translated from
// claude-agent-acp, its file says so.
//
// Serve runs the agent on a client's streams. Each session is one claude
// process: prompts are queued as claude queues them, a turn ends at
// claude's result for it, and a cancel interrupts claude and answers
// what claude hasn't taken yet at once.
package claudeacp

// Name is the agent's name in its initialize answer; clients may key on
// it.
const Name = "claudeacp"

// Version is this package's version, the agent's in its initialize
// answer.
const Version = "0.1.0"
