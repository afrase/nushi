# 0058. Ante's MCP servers: written in its settings, under its lock

Status: accepted, 2026-10-28. Amends 0021.

## Context
The owner asked to edit Ante's MCP servers as Claude's are. ADR 0021 changes Claude's only through `claude mcp`, never writing its config. Ante 0.2.14 has no such CLI: its servers are `mcp_servers` in `$ANTE_HOME/settings.json`, which Ante reads at each session's start and rewrites whole (its own struct, unknown keys dropped) when its TUI or an "always allow" changes it, taking `settings.json.lock` with `flock` first (docs/facts/ante.md).

## Decision
- Nushi writes `mcp_servers` itself (`internal/antemcp`): it takes Ante's lock (waiting up to 5 s), reads the file, changes that key alone (every other key kept, the file's mode kept), and replaces it atomically. A file that isn't JSON is refused and left alone. Skills' `exclude_skills` goes through the same lock.
- Only your servers, Ante's only scope; the form says so where a scope would be picked. No off switch (Ante has none: a server is removed) and no sign-in (Ante 0.2.14 has none).
- Nushi's form says `type` as Claude does; it's dropped with `transport` when saved, Ante inferring it from the command or URL. SSE is refused (Ante doesn't speak it).
- Check is a throwaway `ante serve` session in an empty temp folder, read from its MCP warm-up notice (no status elsewhere); nothing is saved.
- A change reaches new and reloaded Ante sessions; running chats get the "MCP servers changed" Reload, as Claude's.

## Consequences
- A second writer: Ante writing between Nushi's read and write is prevented only by the lock it does take; an older or newer Ante that stops taking it could lose one side's change.
- A key Ante doesn't know (headers before 0.2.15) is dropped the next time Ante rewrites the file.
- Check starts your MCP servers as Ante would, in a folder of its own.
