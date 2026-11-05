# 0092. The details panel is Claude Code's rail: flat, one width

Status: accepted, 2026-11-05.

## Context
The owner, with a screenshot of Claude Code's desktop right rail (`claude-right-rail.png` in the research folder): "lets do some redesign of the right rail to look more like claude … they also don't let you resize this pane which i think makes sense. we should make it so it fits the things we need and you can't resize it, just hide it." The panel was 264 points, dragged from 220 to 480 and remembered, its widgets bordered cards on a raised fill with a six-dot grip under the pointer (ADR 0049).

## Decision
- **One width, 320, no edge to drag.** It shows or hides only (its header button, or Show details and Hide details). 320 is Claude's own rail (639 px at 2× in the screenshot), and at Nushi's type it holds the longest Context row ("MCP server instructions", its count and its share in their columns) and the pull request's merge control without cutting them. A width an older app remembered (`panes.details` in `app.json`) is ignored and dropped by the next save. It hides at the window width it hid at when it was 264 wide (820 for the chat, 1080 with the sidebar): beside it the transcript keeps 500, not the 556 it keeps beside a pane alone, so a narrow window doesn't lose the panel for the wider width, and a side chat or the files pane lies over the transcript where it did beside the 264-point panel.
- **Flat sections.** No card borders or fills: the widgets lie one under another on the window's background, a hairline between them, 16 in from the panel's sides. A widget's title is in the text color at medium weight, at the sidebar's size (13), with a small filled triangle after it that folds it, still remembered per widget; a widget with nothing to offer (Changes outside git) is its title and a note, no triangle. Rows are 13, what's said about a row 12.
- **Reorder stays, by the title, with no grip.** The open hand over a title and the closed one while dragged say it moves; the six dots are gone from the panel (they stay on the GitHub and Jira cards).
- **Context as Claude's block**: "N% used" and "used / window", a thin bar split by kind, a row per kind (largest first, the buffer and the free space last) with a colour square, its count and share in columns, the deferred kinds dimmed with a dash, a folding row for each list /context gives (MCP tools, custom agents, skills…, read from its markdown in the app), and "N until auto-compact" where the agent counts an autocompact buffer (the free space is that distance). Messages, system tools, skills and the system prompt have colours, the rest grey, as Claude's. An agent that reports only a total gets the line and the bar. **Compact** sends `/compact`, as typed, when the agent lists a `compact` command and the chat is idle; Claude's label, "Compact session", doesn't fit beside the line at Nushi's type.
- **Background tasks** are a row each: icon, task, how long it ran, and Stop on the running ones at rest, as Claude's; four running, then Show more; the finished fold under "N finished", a row as a task's, every row on one pitch. What one is doing, and the worktree it works in, is its tooltip: a worktree's tag beside the task cut the task's name to a few letters.
- **Artifacts** keep the glossary's word (Claude says Outputs): five rows (icon, name, kind on the right), then Show more; the pin takes the icon's place on hover and stays there on a pinned one; the folder and age are the tooltip.

## Consequences
- Just above where it hides, the transcript is up to 56 points narrower than before. The panel's rows' second lines (a subagent's step, a command's last line, a file's folder) moved to tooltips.
- The update toast takes the panel's text width (288) and side margin.
- A subagent's pane or the preview, dragged as wide as it's wanted, lies over the transcript at a window 56 points wider than beside the 264-point panel: beside them the transcript keeps 360 whatever else shows, and narrowing that to keep the old switch would leave a column too narrow to read.
## Alternatives considered
- Keeping the drag with a narrower default: the owner agreed with Claude's rule.
- Hiding where the transcript keeps 556 beside it (876 for the chat): windows 1080 to 1135 wide with the sidebar lost the panel they had.
- 300 points, to hide later: the Context columns and the merge control cut, and Claude's own is 320.
- Reading /context's lists in the daemon, as its categories are (ADR 0017): the right place in the end, but it needs an API field; the app has the markdown already.
