# 0051. The skills manager reads Claude's files and writes only documented keys

## Context
The owner asked for a skills manager. Claude Code (2.1.310) loads skills from your config folder (`skills/`), the project's `.claude/skills` (the folder and those above it up to the repository's top), installed plugins and its own bundle. Whether a skill is listed is the documented `skillOverrides` setting (on, name-only, user-invocable-only, off); built-in skills go off together with `disableBundledSkills`; plugins with `claude plugin enable`/`disable` or `enabledPlugins`. Claude's own `/skills` list is reachable (the control request `get_skills_dialog`) only from a run that loads the folder's settings, which runs its `apiKeyHelper` (seen).

## Decision
- **Reading**: Nushi reads the skill folders and settings files itself and asks `claude plugin list --json`, run in Claude's config folder, never the project's; whether a plugin is on in a folder comes from the settings files' `enabledPlugins`. A project's `.claude` or `.claude/skills` that is a symlink is left out. Descriptions are their authors' text: shown as plain text (control and bidi characters dropped), never Markdown, never links, never sent to an agent. The cost shown is an estimate (about 0.35 tokens a character, as `/skills` counted).
- **Writing**, only on the user's action, only the one key, the file replaced at once with the rest kept (ADR 0021's way): `skillOverrides` in your `settings.json` for your skill, in the project's `.claude/settings.local.json` for a project's (Claude's own advice names these files); `disableBundledSkills` in yours; a plugin on or off through `claude plugin` for you, or its `enabledPlugins` entry in the project's local settings when the project's settings name it. Uninstall only what's installed for you. This widens ADR 0021's exception to your `settings.json` (a link to it is followed) and to two more keys.
- **Deleting** a skill moves its folder (or the link in its place) to the Trash, only right in a skills folder Nushi listed, after a confirmation naming the path.
- **New skill…** opens a Claude chat in the folder with a request in its box, unsent; Nushi has no skill editor. No marketplace browsing yet.

## Consequences
- What the page shows can differ from Claude's own list where Claude's rules aren't the files' (managed settings, a skills-dir plugin, a name in two places); what it writes is what Claude reads.
- A change reaches a chat when it restarts.
- Codex, Ante, omp and PiG have their own skills; the page is Claude's.

## Amendments
- 2026-10-27: the page is every agent's, with the shared `.agents/skills` (ADR 0052); Claude's part is as above.
