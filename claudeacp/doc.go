// Package claudeacp is an Agent Client Protocol (ACP) agent for Claude
// Code: it speaks ACP to a client (an editor such as Zed, or any ACP
// client) on one side, and runs each session on the user's own claude CLI,
// through claudeagent, on the other. It needs no Node: it is a Go
// replacement for claude-agent-acp, the Node agent ACP clients run today.
//
// It is unofficial and not affiliated with Anthropic, and it contains no
// authentication code: claude signs in as it always does.
//
// # Compatibility
//
// Its behaviour follows claude-agent-acp, so a client written for that one
// works with this one: the same session ids (claude's own), message ids
// (the Messages API's), _meta keys (_meta.claudeCode, _claude/origin, the
// JetBrains fork-at extension), modes and config options, and a turn's end
// at claude's result for it. Sessions are claude's own: a session started
// here resumes in claude's terminal (claude --resume) and the other way
// round, and one started by claude-agent-acp loads here.
//
// # Running it
//
// Main runs the agent on stdin and stdout, as an ACP client starts an
// agent; the module's cmd/claude-acp is that program. Serve runs it on any
// streams, with a Config. Each session is one claude process: prompts are
// queued as claude queues them, a turn ends at claude's result for it,
// and a cancel interrupts claude and answers what claude hasn't taken yet
// at once. Every permission claude asks for goes to the client; the agent
// never allows anything itself.
//
// # Trust
//
// The client is trusted as the user: what it sends in a session's _meta
// (claude's environment, settings, MCP servers, permission mode) is passed
// to claude as claude-agent-acp passes it, and stdio MCP servers are
// commands claude runs. Session ids must be UUIDs and folders absolute, so
// a request can't name a path of its own choosing.
//
// The code is written fresh; where a piece is translated from
// claude-agent-acp, its file says so (see NOTICE).
package claudeacp

import "github.com/afrase/nushi/claudeagent"

// Name is the agent's name in its initialize answer; clients may key on
// it.
const Name = "claudeacp"

// Version is the agent's version in its initialize answer: the module's.
const Version = claudeagent.Version
