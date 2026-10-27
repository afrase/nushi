# 0053. Settings is a view, not a dialog

## Context
Settings was a ~500 px dialog with four tabs: General held the terminal's font, sleep, every chat's transcript copy (five rows, then "Show all"), remote access, start at login and the logs, each a bold heading with its controls squeezed beside 90 px labels. The owner: "very crammed, it's narrow", and "how will the list grow at 200 chats?". MCP servers and Skills were already views in the chat's place, with their own way in from the sidebar.

## Decision
- **Settings replaces the main area beside the sidebar**, as Jira, GitHub, MCP and Skills did: ⌘, opens it (a terminal passes ⌘, on as `OpenSettingsIntent`), Esc and Close leave it for what showed before (the Jira or GitHub view it was opened from, else the chat). Picking a chat leaves it too.
- **A nav of sections** (200 px): General, Terminal, Chat history, Remote access, Agents, MCP servers, Skills, Jira, GitHub, Logs & advanced. MCP servers and Skills are sections now (the same widgets; their folder and agent pickers on the page); every way in is `Daemon.openSettings(section:, folder:, agent:)`. The last section is remembered while the app runs, not across launches.
- **Pages of grouped rows** (`settings_rows.dart`), as macOS System Settings lays them out: a title (with the page's buttons on its line, under it when narrow), rounded groups, each row a label and a muted line on the left and its control at the group's right edge, hairlines between rows, ADR 0049's controls and one switch size.
- **The content is at most 720 px wide, left-aligned beside the nav**, 32 px from it. Both were drawn at 1700 px: centered, 240 px of nothing separated the content from the nav it belongs to.
- **Chat history is a table**, built lazily (a fixed-extent sliver under a pinned header), sorted, searched, filtered and picked with ⇧ and ⌘ like a Finder list; the daemon still sends every copy in one answer (5,000 in about 0.15 s).

## Consequences
- A section can be as long as it needs; the window's size is Settings' size.
- Settings no longer floats over a chat: a chat's terminal or transcript isn't visible beside it.
- Remote access's section is the remote widget as it was (its own heading under the page's), until it's redone in rows.

## Alternatives considered
- A bigger dialog: still modal, still a fixed size, and MCP servers and Skills stay apart.
- A separate window (macOS's usual Settings window): another window to manage for a single-window app, and the deep links into it (Set up…, Settings › Jira) would move focus between windows.
- Centered content: drawn and rejected (above).
