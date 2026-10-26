# 0050. MCP servers go off through Claude's own toggle

## Context
The owner wanted to turn MCP servers off, not only log out of them. Claude Code (2.1.310) turns a user, local, plugin or claude.ai server off per project with `/mcp` in a terminal, which it records in the project's entry of `~/.claude.json` (`disabledMcpServers`). `claude mcp` has no command for it, `disabledMcpjsonServers` covers only `.mcp.json` servers (tried), and the only settings key that reaches other servers, `deniedMcpServers`, is the enterprise denylist: honored from any settings file, but a denied server vanishes from `/mcp` and `claude mcp list` instead of showing as off, and `/mcp` can't undo it. ADR 0021 has Nushi never write `~/.claude.json`.

## Decision
- A user or local server is turned on or off for the folder's project by Claude itself: a `claude -p --bare` run in the folder takes the Agent SDK's `mcp_toggle` control request (what the SDK's `toggleMcpServer` and claude-agent-acp's `/mcp disable` send) on its input after `initialize`, and Claude writes its own file, as `/mcp` does and as `claude mcp add-json` already writes it. `--bare` runs none of the folder's hooks, helpers (`apiKeyHelper` runs otherwise: seen) or MCP servers and reads no keychain. Whether it took is read back from `~/.claude.json`.
- A project's `.mcp.json` server keeps its switch through `disabledMcpjsonServers` (ADR 0021's exception).
- A plugin's server and a claude.ai connector have no switch: `--bare` doesn't know them, and a full run would load the folder's settings. The view says "Off only with /mcp in a terminal"; a plugin's servers go with the plugin (ADR 0051). One turned off in a terminal shows as off.
- Every switch says "in this project"; a running chat keeps its servers until it restarts, and the details card offers Reload.

## Consequences
- What Nushi shows is what Claude uses, and a change shows in the terminal's `/mcp` at once, both ways.
- It rests on the SDK's control protocol from outside the SDK, a public method's wire form but not a documented CLI; a Claude that refuses it shows its error, and nothing is written by Nushi.
- Turning a server on has Claude connect to it once (a few seconds when it fails).

## Alternatives considered
- `deniedMcpServers` in your settings: "everywhere" in one write, but it's policy, hides the server and can't be undone from `/mcp`.
- Per chat through the adapter's options (`strictMcpConfig`, settings): only Nushi's chats would see it, not the terminal.
