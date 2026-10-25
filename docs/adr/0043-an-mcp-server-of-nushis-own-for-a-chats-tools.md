# 0043. A chat's agent gets Nushi's tools through an MCP server of Nushi's own, scoped to the chat

## Context
A chat started from a Jira issue should let its agent read the issue, comment on it and move it, without the agent seeing the Jira token or reaching any other issue. ACP lets a client name MCP servers in `session/new`, `session/load` and `session/fork`; every agent must take stdio servers. Atlassian's Rovo MCP server would need the token (or an OAuth login) in the agent's hands and gives the whole site. Later, a review side chat should post comments on the diff the same way: a second tool set.

## Decision
- Nushi's tools are an MCP server over stdio, `nushid tools-mcp` (`internal/mcpserver`), named "nushi" in the chat's sessions' `mcpServers`. It knows no tool: it lists and runs what the daemon grants, asking over the daemon's socket (`/tools/list`, `/tools/call`, HTTP/2 as the app talks to it).
- It authenticates with a key the daemon makes for the chat (`internal/features/tools`), given in its environment beside the socket's path. A key grants that chat's tool sets and nothing else; the client token isn't accepted there, nor a key in the API's place. Keys live in memory while the daemon runs; a reopened chat gets a new one.
- Tool sets decide what a chat gets. Jira's (`internal/features/jira`), for a chat on an issue: `jira_issue` (the issue as Markdown, with its recent comments), `jira_comment` (Markdown), `jira_transitions`, `jira_transition`. Each is for that issue only; a call naming another is refused. A chat without an issue gets no server.
- What the agent may run is its harness's to ask (ADR 0007): Claude and Codex show their own permission prompts for MCP tools, as cards. Nushi adds no approval of its own.
- The agents' writes are kept (`jira-writes.json`: which comment or move, which chat and agent, when) and the issue view says whose they were; the log says which tool ran for which chat and whether it worked, never its arguments or result.

## Consequences
- Claude and Codex get the tools. Ante (its `serve` protocol takes no MCP servers), oh-my-pi (ignores a client's in ACP mode) and PiG (RPC mode has none) don't: their chats on an issue have the context in the first message only.
- The key is visible to the agent and, since Claude Code passes MCP servers on its command line, to `ps`; anything running as the user can already read Nushi's token file (ADR 0024). The key reaches one issue's four tools for as long as the daemon runs, never the Jira token.
- A second tool set (review comments) is another `tools.Set`; the server, the key and the transport stay.

## Alternatives considered
- Rovo MCP passed to agents: the token or an OAuth session in the agent, the whole site, an admin's opt-in, and writes Nushi can't see.
- An HTTP MCP server on a local socket: not every agent takes HTTP servers (`mcpCapabilities.http`); stdio is the one all must.
- The client token for the tools server: it opens the whole API, terminals included.
