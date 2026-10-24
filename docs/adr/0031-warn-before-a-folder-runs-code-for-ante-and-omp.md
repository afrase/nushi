# 0031. Warn before a folder's own code runs, for Ante and omp

## Context
[0023](0023-warn-before-a-folder-runs-code.md) and [0029](0029-warn-before-a-folder-runs-code-for-codex.md) warn before Claude or Codex runs what a folder brings. Neither Ante nor omp keeps a record of trusted folders.
- **Ante** 0.2.14 layers the nearest `.ante/settings.json` from the session's folder up over the user's settings, and drops from it what would widen what Ante may do: permission mode, allow rules, MCP servers, system prompt, model, provider (checked: an MCP server and `yolo` in a project file were ignored, with a notice). It has no hooks. A folder's skills, subagents and `AGENTS.md` are instructions.
- **omp** 18.12.6 (read in its source) loads a project's code at `session/new` without asking: extensions, hooks, custom tools, command modules and LSP servers from `.omp`, `.claude`, `.codex`, `.gemini` and `.opencode`, and settings (which can name more extensions, and the shell commands run in) from those, `.cursor` and `opencode.json`. In ACP mode it ignores MCP configs; only the client's servers run.

## Decision
- Ante: the card shows the nearest `.ante/settings.json` whole (not Ante's own in its home). Ante ignores its dangerous keys, but it is what the folder sets for Ante, and Nushi can't check the closed binary that reads it.
- omp: the card shows every file omp loads code or settings from, whole, in each folder from the repository's root down to the chat's (the folder alone outside a repository): all of `.omp`; `extensions`, `hooks`, `tools`, `plugins`, settings files and `commands/*/index.{ts,js,mjs,cjs}` in the other agents' folders; `lsp.*`, `ssh.json`, `opencode.json`. Instructions (`AGENTS.md`, skills, rules, `.md` commands) are left out, as Claude's card leaves them out.
- As for Codex, "Start anyway" is kept per agent and per what was shown (`ante:` / `omp:<folder>#<hash>`), checked again on Start anyway; a link or a file Nushi can't read can't be remembered. The files are read by one package for all agents (`internal/folderfiles`).

## Consequences
- An omp chat in a repository with Claude or Codex hooks or settings asks once for omp too.
- omp walks some folders above the repository's root (skills, up to the home folder) that the card doesn't show: they hold instructions only.
