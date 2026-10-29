# MCP servers and skills

## MCP servers

Settings › MCP servers (also a chat's ⋯ › MCP servers…, or the palette) lists the servers Claude uses in a folder, by scope, each with its state.

**Switches.** Each user, project and local server has a switch, "in this project":

- A **project** server's switch approves or rejects its `.mcp.json` entry, in the project's `.claude/settings.local.json`.
- A **user or local** server is turned off as `/mcp` does it in a terminal, by Claude itself, so the terminal sees it too ([ADR 0050](adr/0050-mcp-servers-off-through-claudes-own-toggle.md)).
- A **plugin's** server or a **claude.ai connector** says "Off only with /mcp in a terminal". Or turn its plugin off in Skills.

A server that's off stays listed, dimmed. A running chat keeps its servers until it restarts: the details panel's MCP widget says "Applies when the chat restarts", with Reload.

**Ante's servers** are listed under Ante (Add server ▾ › For Ante…) ([ADR 0058](adr/0058-antes-mcp-servers-in-its-settings.md)):

- Yours only, since Ante reads no project's. They're kept in `~/.ante/settings.json` (or `$ANTE_HOME`), which Nushi changes under Ante's own lock.
- stdio or HTTP; Ante doesn't speak SSE.
- No switch, since Ante has no off: remove one instead.
- A change applies to new Ante sessions, or a running chat's Reload.

## Skills

Settings › Skills (or ⋯ › Skills…, which opens that chat's agent) lists an agent's skills for a folder. Pick the agent beside the title; Claude comes first ([ADR 0051](adr/0051-the-skills-manager.md), [ADR 0052](adr/0052-skills-for-every-agent-and-the-shared-folder.md)).

**Groups:** yours, the project's (where that agent reads them), **Shared**, the agent's own, and for Claude each plugin's and its built-in ones together.

**Each skill** shows its description, about what it costs every chat's context, and a switch that says how it acts:

| Agent | The switch says |
|---|---|
| Claude | "everywhere" or "in this project" (Claude's `skillOverrides`) |
| Codex | "in config.toml" |
| PiG | "in your settings" or "in .pig/settings.json" |
| Ante, oh-my-pi | "by name, everywhere" |

**Shared** is `.agents/skills` (the project's, as the agents walk it) and `~/.agents/skills`, which Codex, PiG, oh-my-pi and Ante read.

- Each shared skill says which agents load it ("Off for Codex", "PiG loads it once the folder is trusted"); its switch is the picked agent's.
- Claude doesn't read `.agents/skills` yet. A shared skill's ⋯ › Link for Claude… makes `.claude/skills/<name>`, a relative link to it, so Claude loads it too.

**Other actions:**

- Search filters skills and plugins.
- A skill's ⋯ opens its `SKILL.md` as text, shows it in Finder, or deletes it: its folder, or the link in its place, goes to the Trash, naming every agent that loses it.
- **Plugins** lists what each brings (skills, commands, agents, MCP servers), turns it on or off, or uninstalls one installed for you.
- **New skill…** opens a chat with the picked agent in the folder, with a request in the box to write one in `.agents/skills`. For Claude, it asks first: `.claude/skills`, or `.agents/skills` and a link.

What you change in a terminal shows when the section opens, or on Refresh.
