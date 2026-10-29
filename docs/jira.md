# Jira

## Adding a site

Settings › Jira adds a Jira Cloud site: its address, your email, and an API token from id.atlassian.com (classic or scoped). Give the token's expiry date if you want a warning before it ends.

- Nushi checks the token with Jira, then keeps it in your login keychain, never in a file ([ADR 0042](adr/0042-jira-cloud-through-our-own-client-tokens-in-the-keychain.md)).
- After an update of Nushi, macOS wants your OK before the new build reads it: Allow… asks.
- A daemon started before the update (or outside your login session) can't be given that OK. Nushi says so and offers Restart daemon instead.

## The task list

⌘J (View › Jira, or Jira at the sidebar's foot) shows Jira in the chat's place, as a task list.

**Lists:** your open issues, in a card for each status; or the active sprint of a board you pick, a saved search, or JQL that completes fields, operators and values as you type. With several sites, "All sites" lists your open issues from each.

- Drag a card by its title to reorder it, and click its title to collapse it. Both are kept per site.
- The sprint, a saved search and JQL have "Everyone ▾" at the bar's end: Me, Unassigned, or anyone the list has, remembered per site and list.

**Each row** shows the issue's key, its summary and the chats on it (a click opens the newest), then in columns:

- its priority;
- its status: a click lists the moves its workflow allows;
- outside Mine, who it's assigned to: a round avatar with initials, the name on hover, a dashed circle when nobody.

Start work shows on the row under the pointer and the selected one (⌘⏎), and in its right-click menu.

**Details.** ⏎ or a click shows an issue's details in the list's place: description and comments, subtasks, parent, links, attachments, remote links, and a box to comment in (Markdown). Esc goes back, as do a swipe back and the mouse's back button ([GitHub](github.md#the-inbox)).

**Keys:** ↑↓ or j k pick, ⌘⏎ starts work, ⌘R refreshes, ⌥⌘1–9 switch lists, / goes to the JQL, Esc closes.

**Freshness.** What a list or an issue showed last shows at once while Jira is asked again ("Updated 5m ago · refreshing"); the daemon keeps it per site in its data folder. Lists and the issue are asked for again each minute while the view shows. Nothing reaches Jira otherwise, and Nushi never writes to it unless you (or an agent, through its tools) do.

## Starting work on an issue

Start work on an issue (its row, or Start a chat in its details) picks the folder, then opens the New chat dialog with the issue picked. Or, in the New chat dialog, press I (or ⌘V with an issue's link) and paste a link (`https://<site>/browse/ABC-12`), type a key, or search by words across your sites.

- A picked issue turns on a new worktree, on a branch named after it (`ABC-12-fix-the-login`). W turns it off, B changes the branch, ⌫ clears the issue.
- Nothing about the issue goes into the box. The chat shows the key, and the issue's details list its chats.

## The agent's tools

Claude and Codex chats on an issue get four tools for it, through an MCP server of Nushi's own, which also tells the agent which issue its chat is for ([ADR 0043](adr/0043-an-mcp-server-of-nushis-own-for-a-chats-tools.md)):

- read it;
- comment on it;
- list its moves;
- move it.

Never another issue, and never the token. The agents' own permission prompts ask before the tools run, and the issue view says which comments and moves were an agent's.
