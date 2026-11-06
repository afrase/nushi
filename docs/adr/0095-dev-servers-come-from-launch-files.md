# 0095. Dev servers come from .agents/launch.json and .claude/launch.json, in Claude's format

Status: accepted, 2026-11-06.

## Context
The owner wants a browser tab beside the chat showing the project's dev server, as Claude desktop has it, for every agent. Claude desktop keeps a project's servers in `.claude/launch.json` (its format and rules in `docs/facts/claude.md`), committed with the repository, which it reads and also writes when it detects servers. Nushi runs six agents; `.agents/` is already the folder several of them share (ADR 0052), and writing into `.claude/` for a Codex-only repository would be odd. Other tools' files (VS Code's `.vscode/launch.json`, Cursor's, Conductor's) describe debuggers or generic tasks, not servers.

## Decision
- **Two files, one format**: Nushi reads `<folder>/.agents/launch.json` and `<folder>/.claude/launch.json`, where the folder is the chat's folder or its worktree, never the repository's root above it (Claude reads only the selected folder, and a root's file would run commands the chat's folder didn't bring). Both are Claude's format exactly: `version`, `autoVerify` and `configurations[{name, runtimeExecutable, runtimeArgs, program, args, cwd, port, env, autoPort, url}]`, JSON with comments (`tailscale/hujson`), so an entry copies between the files, and between Nushi and Claude desktop, unchanged. No keys of Nushi's own; if some are ever needed, one `"nushi": {}` object, once Claude desktop is seen to ignore it.
- **Merged by written name**, without case, `.agents`' winning a name both use; a derived name (an entry without one gets Claude's) claims nothing, so it never hides a written one and may repeat. Each entry says which file it came from.
- **A worktree** has only what's committed: when it has neither file, the main checkout's file at the same relative path is read in their place, read only, with `cwd` and `${workspaceFolder}` resolved in the worktree, and its entries marked as from the main checkout.
- **Claude's rules** (`internal/launchfile`): a missing name is derived and the port found as Claude finds them; an entry Claude refuses (a VS Code `command` or `node-terminal` entry, a bad port or `autoPort`, a localhost `url` that isn't a bare origin on the entry's port, credentials in a `url`) is listed with its problem, in fixed words. Stricter than Claude: the file and `cwd` through `os.Root` (no link out of the folder; `cwd` checked at reading and again just before the start, `CheckCwd`, where Claude checks only at the start), `cwd` an existing folder, port 0 in a `url` refused, a port derived from the command within 1–65535, `env` strings only, and a file that isn't JSON with comments refused whole (Claude keeps what it could parse), its error giving only the line and column. A `url`'s host is read as a browser reads it, IDNA's mapping included, so no spelling of localhost escapes its rules.
- **Names** fit for a note or a tool's text match `^[A-Za-z0-9][A-Za-z0-9:_.-]{0,63}$` (Claude's rule for its candidates); an entry whose name doesn't is still listed, shown marked, and addressed by index.
- **A content hash** of each entry as resolved, so a running server can tell that its configuration changed.
- `autoVerify` is ignored: no repository text reaches an agent's instructions from these files.

## Consequences
- Nushi will write only `.agents/launch.json`; a change to a `.claude` entry will be an override of the same name there. Claude desktop keeps editing `.claude/launch.json` its own way.
- Someone using Claude desktop on the same repository has the same servers in both apps.
- Claude never reads `version`, and its format is documented only by its docs' table: a key it adds later is ignored here until read.

## Alternatives considered
- `.claude/launch.json` alone: it serves both apps, but makes Nushi a second writer of a file Claude desktop rewrites with its own format-keeping edits, where the two writers' changes could clash, and is odd in a repository that doesn't use Claude.
- A format of Nushi's own (an explicit `${port}`, a readiness pattern): better in places, but no agent or tool would know it.
- Falling back to the repository's root: more servers found, but commands the chat's folder didn't bring.
