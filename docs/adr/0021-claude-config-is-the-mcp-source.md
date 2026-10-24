# 0021. Claude's own config is the source of truth for MCP servers

## Context
Nushi shows and manages the MCP servers Claude uses. Claude keeps them in its own files: user and local scope in `~/.claude.json` (or `$CLAUDE_CONFIG_DIR/.claude.json`), project scope in each repository's `.mcp.json`, plugins' servers in the plugins, claude.ai connectors in the account. Claude writes `~/.claude.json` constantly (counters, caches, per-project state), so a second writer would lose data. A copy kept by Nushi would drift from what Claude, the terminal and other tools see.

## Decision
Nushi keeps no copy of MCP config. It reads Claude's files to list servers, asks `claude mcp list` for their health, and changes servers only through the `claude mcp` CLI (`add-json`, `remove`, `login`, `logout`). It never writes `~/.claude.json`.

One exception, for project servers: turning a repository's `.mcp.json` server on or off for the project (which also approves or rejects it) writes Claude's documented `enabledMcpjsonServers` and `disabledMcpjsonServers` lists in the project's `.claude/settings.local.json`, a settings file Claude itself writes only on "don't ask again". Nushi changes only those two lists, keeps everything else in the file, replaces it atomically, and keeps a file it creates out of git through `.git/info/exclude`. Turning a user, local, plugin or claude.ai server off per project is recorded only in `~/.claude.json` (`disabledMcpServers`, by Claude's `/mcp`), so Nushi doesn't offer it.

All of this is Claude-specific code in `internal/claudemcp`, behind an interface the `mcp` feature declares, so another agent can bring its own.

## Consequences
- What Nushi shows is what Claude uses, and a change made in Nushi shows in the terminal at once (and the other way round).
- Anything Claude records only in `~/.claude.json` (per-project on/off of user servers, the terminal's approvals) can be shown but not changed from Nushi.
- Reading depends on Claude's private file layout and the list's text format; both are read tolerantly (an unknown status is "unknown", not an error).
- Codex keeps its MCP servers in its own `config.toml`; Nushi doesn't show them, and a Codex chat's MCP card says so.
