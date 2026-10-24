# 0029. Warn before a folder's own code runs, for Codex too

## Context
[0023](0023-warn-before-a-folder-runs-code.md) warns before Claude runs what a folder brings. Codex 0.160.1 (read in its source) loads a project's `.codex/config.toml` and `.codex/rules/` only for a trusted project, and records trust as `projects.<path>.trust_level = "trusted"` in its own `config.toml` (`$CODEX_HOME`, else `~/.codex`), the path being the folder, its project root or its repository's main checkout. But codex-acp 2.2.2 starts every session with `projects.<cwd>.trust_level = "trusted"` as an override, so a chat's own folder's `.codex` always loads, even where the user marked it untrusted; folders above it load only when Codex's record trusts them. That config can start MCP servers (a `command`, or an `http_headers_helper`), set the environment every command gets (`shell_environment_policy.set`, such as `BASH_ENV`), set sandbox and approval settings, and turn on installed plugins; its rules can let commands run without asking. A folder's hooks run only once the user trusted each one in Codex (a hash in the user's own config), and a project can't set that.

## Decision
- For a Codex chat, the card lists what the folder's own `.codex` brings: MCP servers and header helpers, the names of the environment it sets, which sandbox and approval settings it sets, the plugins it turns on, and each rules file whole. A `config.toml` Nushi can't parse shows whole. Hooks aren't listed.
- Codex's record of trust counts as Claude's does; "Start anyway" is kept per agent (`codex:<key>` in `trusted.json`), so a folder trusted for Claude still warns for Codex.
- As in 0023, it warns and never refuses; Nushi never writes Codex's config.

## Consequences
- The card shows what will load, not what Codex would ask about: codex-acp's override means Codex itself never asks.
- An older app asks about Claude's files only (CheckFolder without an agent is the default agent's).
- Codex runs `git status` in the folder each turn with hooks and fsmonitor off but the repository's filter drivers on, as Nushi's Changes view does (0023).
