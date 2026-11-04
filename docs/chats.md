# Chats

A chat is a conversation with one agent, in one folder. This page covers the window, the chats in it, and what they show. Which agents there are, and how to set them up, is in [Agents](agent-setup.md).

## The window

- **First run.** With no chat open, the pane offers New chat, Open a folder…, and the recent folders: the chats' folders, or before there are any, the folders Claude's sessions were found in. Each starts a new chat there.
- **The sidebar** lists Pinned, then your sections, then the projects and their chats; its Arrange button groups and sorts them otherwise ([Arrange](#arrange)). Its foot has Jira, GitHub and Settings. ⌘\ or the button at its top hides it, and the main area takes the window; the button at the start of each header, ⌘\, the palette or View › Show Sidebar brings it back. Nushi remembers which, and the sidebar's width. Hidden, ⌘K still goes to any chat, Jira, GitHub and Settings, and a chat's color is a dot in its header.
- **Settings** (⌘,) opens over the window, which stays in sight behind it, dimmed; its sections in a list on the left. Esc, Close, ⌘, again or a click outside shut it, and you're where you were ([ADR 0087](adr/0087-settings-is-a-modal.md)). What starts work elsewhere (a chat from New skill…, a chat opened from Chat history, a menu bar item) shuts it first. Settings › Appearance's Appearance (Light, Dark, or as the system; also in the View menu) is remembered.
- **Chat width.** Settings › Appearance or the palette (⌘K): a centered column, or the whole width of the window.
- **Themes.** Settings › Appearance (or the palette's Appearance and themes) picks the palette: the picked theme large, its dark and light sets side by side, then a card for each theme, a small picture of Nushi in it. The cards show the set the app shows; Dark and Light over them look at the other without changing Appearance, which still picks which of the two shows. A pick repaints at once and is remembered. Built in: Nushi, Vivid (bolder fills), Solarized, Nord and Catppuccin. The phone's Settings picks one of these for the phone, from the same pictures. See [Themes](#themes) for your own.
- **Jump to latest.** Scrolled up, a chip over the transcript's bottom right takes you back down, and the chat follows the agent again. It glides the last screen, however far up you were, so a long chat is as quick as a short one; scroll to stop it. With Reduce Motion it jumps.
- **Around the composer**, nothing jumps: the turn line grows in as a turn starts and folds away after it, the lines over the box (the plan, queued messages, an error, completions, attachments) grow in and fold away, a queued message's pill pops in and fades where it was as it goes, and the box's buttons pop in. The box itself grows a line at a time at once, as you type. With Reduce Motion they all come and go at once.
- **The plan.** An agent that keeps a to-do list shows it in the transcript as a checklist ("Plan · 1 of 5 done"), kept up to date in place through the turn, and a later turn gets a card of its own only once the plan changes in it; while the agent works, the line over the box says the step it's on ("1/5 Merging the duplicates"). A step done while you watch draws its check as its words dim, the step being worked on shines beside a working ring, and the line over the box crossfades to the next step; a chat you open shows its plan still, and with Reduce Motion only the colors change. Claude keeps one only with its todo tools on: Nushi turns them on (`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in its environment) unless your shell's environment sets the variable, so `CLAUDE_CODE_ENABLE_TODO_TOOLS=0` there keeps them off.
- **A message shows as you send it**, faint until the daemon has it, then whole in the same place (on the phone too, where the relay takes a moment). If it couldn't be sent it fades out as its text goes back in the box. A message sent while the agent works is a queued pill instead, as before.
- **An answered permission prompt or question** settles into its answered line: it shrinks to it as its amber (or a question's blue) fades, so the transcript under it slides rather than jumps. With Reduce Motion it changes at once.
- **A chat keeps its place.** Leave a chat scrolled up and it opens there again, with Jump to latest showing, until Nushi quits. One left at its bottom, or one that needs you, opens at its bottom.
- **Under a message**, on hover: Copy, Rewind or Fork from here, Pin on the agent's, and its time; on yours, one check when it's sent and two once the agent has answered ([ADR 0076](adr/0076-messages-as-bubbles-with-actions-on-hover.md)).
- **Pinned messages.** Pin one of the agent's messages (Pin under it, on hover; your own aren't pinned) and its pin stays held down; Unpin takes it off. While a chat has pins, a rail of short dashes sits in the transcript's left margin at its top: one for Session start, then one per pin in the transcript's order, the one for where you're reading long and bright, changing as you scroll past a pin. Point at the rail (or click it, or Tab to it) and its menu lists them by title; ↑↓ and Enter work it, Esc or moving away closes it, and a pick goes there and tints the message for a moment. Each pin's title is a few words from the message at first; in a Claude chat, Claude's own fast model names it a moment later (it doesn't rename the chat). The daemon keeps the pins and their titles, so the phone has the rail too (a tap opens the menu; it can't pin: it has no actions under a message). A rewind that cuts a pinned message drops its pin, a fork keeps the pins of what it keeps, and with Keep transcripts off a pin goes when its message leaves the agent's history (a compaction, say) ([ADR 0085](adr/0085-pinned-messages-kept-by-the-daemon.md)).
- **`/plan`** in a Claude chat switches it to plan mode, as the mode menu does, on the Mac and on the phone; `/plan <what to plan>` switches, then sends the rest as your message. In plan mode already, `/plan` only says so and `/plan <text>` just sends the text, which Claude's terminal would drop ([ADR 0088](adr/0088-claudes-plan-runs-in-the-daemon.md)). Claude's other terminal-only commands (`/rewind`, `/resume`, `/permissions`…) aren't offered, since Claude refuses them outside its terminal; Nushi's own controls do most of what they do.
- **`/copy`** puts the agent's last message on the clipboard as Markdown; `/copy 2` the one before ([ADR 0075](adr/0075-copy-is-nushis-own-command.md)).
- **Tabs.** A chat opens on the tab it was left on (Chat, Changes, Pull request), and on Chat when it needs you.
- **Trust.** Before an agent starts in a folder that brings code of its own (hooks, MCP servers, extensions), a trust card shows that code. Going elsewhere while it asks is a no, and a bar over the app says what didn't start ("Didn't start Claude in site: its code wasn't approved.").
- **Motion.** The sidebar, the details panel, a side chat and the side panes slide in from their edge and back out (the sidebar's button moving with it between its header and the traffic lights, and the header's title with its edge), and the chat's text glides to its new place beside them (in a window too narrow for its column it re-wraps where it goes instead). The terminal slides up from under the chat, the bars over the app slide down, the update toast rises in, and a tab's line slides to the tab picked; what shows changes at once, and nothing waits for the motion. With Reduce Motion (System Settings › Accessibility › Display) everything is where it goes at once.
- **The status bar**, along the window's bottom, counts working, awake and sleeping agents and shows the memory Nushi takes. A click lists each awake chat's.

## Themes

A theme of your own is a JSON file in the `themes` folder of Nushi's data folder (`~/Library/Application Support/Nushi/themes`). Settings › Appearance shows each as a card marked Yours, with what's wrong with its file and any colors that read too faintly on it, and Show in Finder. Its Theme has **New from** (writes the current theme with every color, picks it, and shows the file in Finder) and **Show folder**. Edit the file and the app repaints as you save ([ADR 0086](adr/0086-color-themes.md)).

```json
{
  "name": "Midnight",
  "from": "nord",
  "dark": { "base": "#1B1F27", "accent": "#5E81AC", "syntax.keyword": "#81A1C1" },
  "light": { "accentSoft": "#D2DEEC" }
}
```

- `from` is the built-in it starts from (`nushi`, `vivid`, `solarized`, `nord`, `catppuccin`; Nushi's if it's left out); what the file doesn't name is that theme's. `name` is what Settings shows (the file's name if left out).
- `dark` and `light` map token names to `#RRGGBB` or `#AARRGGBB` (the alpha first). The names are `theme/tokens.dart`'s (`base`, `raised`, `text`, `toolTint`, `subagentAccent`, `needs`…), then `avatars.<blue|teal|violet|amber|rust|magenta|slate|green>` (the chat colors), `syntax.<keyword|string|comment|…>`, `terminal.<black|red|…|brightWhite>` and `diff.<insertedLine|deletedWord|…>`. A file from New from lists them all.
- A key that's no token, a value that's no color, and a file that isn't JSON each get a line under the themes in Settings; the rest still applies. A pair that reads under AA (text under 4.5:1 on a fill it sits on, a mark under 3:1) gets a warning line naming it; the theme still works.

## Starting and arranging chats

**New chat** (⌘N, or a folder's +) asks which agent to run, with the one used last picked; Enter starts it.

- A chat keeps its agent, and shows its mark, in the agent's own color, in the sidebar, its header and wherever its chats are listed ([where the marks and their colors come from](user/agent-marks.md)).
- It keeps the model, effort and other options you pick under the box, after it sleeps or the daemon restarts.
- A new chat starts on the options last picked for its agent (where it still offers them), in the mode last picked.

**Order.** Drag a chat within its project to reorder it; a new chat goes to the top. Drag a project by its header. A project's chevron collapses it, its chats folding away; every chevron in Nushi (Thinking, a tool's row, a finding, a details widget, Archived) opens and folds the same way, at once with Reduce Motion.

**Rows that come and go.** A new chat's row grows into its place, one archived or deleted fades and folds, and one pinned, unpinned or moved to another project glides from where it was to where it goes, as does a project that changes place. While a chat starts, a row-shaped placeholder ("Starting Claude…") holds the place its row will take, at the top of its project, its project moved to where the new chat will put it; the row takes its place with no jump. This happens only when the list changes, never on a chat's state, and with Reduce Motion rows come and go at once. The phone's list grows and folds its rows and sections the same way: a chat that starts needing you leaves its project and comes into "Needs you", which grows in with it and folds once none does.

**Arrange.** The button at the sidebar's top, left of the one that hides it, shows under the pointer (or with the focus); while the sidebar is arranged otherwise than at first it stays, with a dot. Its menu ([ADR 0089](adr/0089-sidebar-sections-are-the-macs.md)):

- **Group by**: Project (the projects, as above: the default), Date (Today, Yesterday, Previous 7 days, Previous 30 days, then by month), Status (Needs you, Working, Done, Idle and the others, in that order), Agent, Worktree (in one or not), or None (one list). Pinned stays on top whatever the grouping.
- **Sort by**: Manual (as you drag them, a new chat first: by Project only), Last updated (a message sent or a turn ended), Date created, or Name; newest or oldest first, A to Z or Z to A. The menu says which applies: drag chats to put them in order (by project, by hand), or the sort sets the order and a drag only moves a chat into a section. Under Date, Last updated groups by the last update and Date created by when the chat was made.
- **Show**: what each row shows besides its title: Status (its dot), Agent (its mark), Branch (or Jira key), Project (its project's name, where its group doesn't say it: Pinned, a section, a grouping other than Project) and Time (how long ago it was updated or made). All but Time at first.
- **New section**: a section of your own, under Pinned, its name a field at once. Drag a chat onto it, or pick its row's Move to section; Remove from section, or a drag onto the groups below, puts it back. A pinned chat moved in is unpinned. Drag a section by its header to reorder it; its chevron collapses it; its ⋯ or right-click renames or deletes it, its chats going back.
- **Reset to defaults** puts the grouping, the sort and what rows show back as at first; your sections stay. **View all** opens Settings › Chat history.

Nushi remembers all of it. ⌘1–⌘9 and ⌘[ ⌘] go through the chats in the order shown. A chat's row rebuilds only when what it shows changes, never as an agent's text streams in. The phone's list keeps its own order (Needs you, Pinned, then the projects).

**Pins.** Pin a chat with ⌘D (Chat › Pin Chat, its ⋯, its row's right-click, or the palette) and it moves to Pinned, above the projects, with its project's name beside it.

- Drag pinned chats to reorder them.
- Unpin puts a chat back where it was in its project.
- The daemon keeps the pins, so the phone has them too. Archiving unpins.

**Colors.** With many chats, a color tells them apart when the titles no longer do. The swatches on the Color row of a chat's menu (its ⋯, its row's right-click) put a bar of that color at its row's left; No color takes it off. Only the open chat's row is filled, so a colored chat never reads as the open one. The daemon keeps it, so the phone's list shows it too, and a fork, or a side chat kept as a chat, starts with its chat's color.

## Keys

| Keys | What they do |
|---|---|
| ⌘\ | Hide or show the sidebar. |
| ⌘1 – ⌘9 | Open one of the first nine chats. Hold ⌘ and the sidebar numbers them, top to bottom, Pinned first, archived left out. |
| ⌘[ and ⌘] | The chat before or after (View › Previous Chat, Next Chat). |
| ⌃Tab, ⌃⇧Tab | Go through Chat, Changes and Pull request (when the chat has one). |
| ⌃⌘1, ⌃⌘2, ⌃⌘3 | Show Chat, Changes or Pull Request (View menu). |
| ⌘W | Close the preview tab showing, and with the last the pane (File › Close Tab). A focused terminal keeps it, to close itself. |
| ⌘K, ⌘⇧P | The command palette. |
| ⌘F | Find. |
| ⌘; | The next typo in the composer ([Spell check](#spell-check)). |
| ⌘P | Open file. |
| ⇧⌘E | Show or hide the Files pane. |
| Esc | Stop a running turn. |
| Esc Esc | Rewind: list your messages. |

The chat keys work in a terminal too.

## The palette

⌘K (View › Command Palette…) opens the palette. In a terminal ⌘K clears it, so use ⌘⇧P there, which works everywhere.

- **Go to a chat** by its title: the pinned first, then the last opened. Archived chats are listed last, marked.
- **Run an action**: New chat, Open file…, Artifacts…, Chat, Changes, Pull request, show or hide the sidebar, the details and the terminal, Rewind…; the chat's own: Side chat, Fork chat, Send review comments, Stop, Rename, Pin or Unpin, Sleep, Reload, Link pull request…, Archive or Unarchive, MCP servers, Skills, Delete…; and Settings, Jira, GitHub, Restart daemon.

Rows match as you type, each with its key. Actions that don't apply now are left out, and what you picked lately comes first.

**Side chat** (⇧⌘B) opens a fork of the chat beside it. It knows the conversation and doesn't add to it; you can go back and forth in it. ⇧⌘B (or its −) hides it and shows it again, alive all the while: hidden, a Side chat chip in the chat's header shows it, with a dot while it works or when a turn ended unseen. Its × ends it and deletes its conversation, so one with messages asks first; **Keep as chat**, beside it, makes it a chat of its own in the sidebar instead (a fork, below). While it's open, the Context widget shows its context and cost on a Side chat line under the chat's.

The chat's own actions are also in the menu bar's Chat menu, its ⋯ menu, and its sidebar row's right-click.

## Find

⌘F (View › Find…) finds in what's showing:

- **In the chat**, every match is marked in the text, the current one in the accent, and the chat goes to it and stays there, however much the agent writes, until you go back to the bottom. A match in something closed (a tool row, a thought, a subagent's steps) marks the row with how many it holds, and shows in place once you open it. ⏎ and ⇧⏎ go through the matches; Esc closes.
- **In Changes**, it lists the files with the text in their path or either side and marks it in the diff. ⏎ and ⇧⏎ go through the file shown and on to the next file; Esc closes.
- **In a focused terminal**, it finds in its scrollback.

## When a turn fails

A turn that fails, say on the agent's API answering "overloaded" until it gives up or your account running out of credit, ends with a red notice saying why, and a button beside it:

- **Continue**, when the turn got somewhere after your last message: the agent wrote, thought, ran a tool, started a subagent, made a plan, or asked you something (a message that only repeats the error, as Claude's "API Error: …" does, doesn't count; nor does a step of a subagent started earlier). It sends "Continue.", what you'd type in Claude Code: the agent already has your message and its work in its history, so sending the message again would have it start over, or answer that it already did that.
- **Try again**, when nothing came back: it sends your last message once more, with its images, to the subagent it was for, as a new message.

Nothing is rewound, and the box keeps what you've typed. The button shows while the notice is the chat's last line (in an archived chat, or while a rewind is on its way, there's none) and goes grey while the chat is busy; a chat reopened after Nushi restarted shows the same one, as long as Keep transcripts is on (the notice is Nushi's, not the agent's). Nushi never tries again on its own.

A message from the queue steered into the turn is part of it: when the turn got somewhere before it, the button is Continue, as the agent already has that message; when nothing came back at all, Try again sends it.

Messages waiting in the queue stay held after a failed turn. Continue, Try again, or any message you send, goes first, and the queue follows once that turn ends well, each message once; in a chat that went to sleep meanwhile too, as it wakes.

## Writing a message

⏎ (or ⌘⏎) sends; ⇧⏎, ⌥⏎ or ⌃⏎ starts a line. The same goes for a reply, a review comment and a subagent's box.

- **Lists continue.** A line started after a list item begins the next one, as in GitHub's and Slack's boxes: `2. ` after `1. `, the same `-` or `*` after a bullet, at the same indent. On an item with nothing in it yet, the marker goes instead and the line is left blank, which ends the list. ⌘Z takes a line and its marker back at once. Only the line key does this: pasted text and lines typed any other way stay as they are.
- **Code shows as code.** In the composer, text between a pair of single backticks on one line is drawn in the code font on the tint the transcript gives inline code, its backticks muted; a fenced block (from a line starting ```` ``` ```` to the next) is in the code font, its fences muted. An open backtick or fence changes nothing until it's closed. Words in code aren't spell checked.

## Spell check

On the Mac the composer checks spelling as you type, with macOS's own checker, languages and dictionary (Settings › General's Check spelling while typing, on at first). A misspelled word gets a dotted underline once you've moved on from it, by a space, punctuation or the caret; a word isn't judged while the caret's in it. Typos never stop a message going.

- **Click a flagged word**, or press ⌘; (Chat › Next Typo) to go to the next one after the caret: a menu opens above it with up to four suggestions, Ignore and Add to dictionary. ⏎ takes the first suggestion and 1–4 take that one; esc closes, and any other key closes it and carries on. ⌘Z undoes a suggestion, which keeps the word's capital.
- **Right-click a flagged word** for the same, over Cut, Copy and Paste.
- **Ignore** lasts until Nushi quits, in every chat. **Add to dictionary** goes in the macOS user dictionary, which every app shares.
- **Left alone**: anything in backticks or fences, paths, URLs, words starting with `/ @ # ~ $ -`, anything with digits, dots, underscores or colons in it, camelCase and ALLCAPS, words under three letters, capitalized words mid-sentence (probably names; one starting a sentence is checked), and any word of the agent's messages in this chat, which covers the project's own. A hyphenated word is checked part by part. A prompt past 20,000 characters is checked up to there.

A subagent's box, a reply box and a review comment aren't checked.

## Rewind

A chat whose agent can rewind goes back to just before one of your messages. Rewind forgets everything from that message on and puts the message back in the box. Files aren't rewound.

- Rewind shows on a message under the pointer, and in its right-click menu.
- Esc twice quickly in the box lists your messages, newest first, with when each was sent. Type to filter; ↑↓ and ⏎ (or a click) rewind at once.
- A single Esc stops a running turn. A turn must stop before a rewind.
- While the message is on its way back, the box is read-only and sends nothing. The same goes for a turn stopped before the agent answered, which takes your message back. Text already in the box stays, and the message goes after it. This holds only on the device that asked: a rewind from your phone doesn't lock the Mac's box.

## Fork

**Fork chat** (the chat's menus, the palette, the phone's ⋯) makes a new chat from this one's conversation, which then goes on separately: the same agent, folder and worktree, the chat's model, mode and effort, its title marked "(fork)". The original stays as it was. While a turn runs, the fork has what has finished. **Fork from here**, on one of the agent's messages under the pointer, makes it from the conversation up to that message. Both need an agent that can fork; a fork shares the folder's files with the original ([ADR 0067](adr/0067-forking-a-chat-makes-a-new-chat.md)).

## Changes and review comments

**Changes**, beside Chat, is the chat's diff viewer: its folder's uncommitted changes, or its branch's for a worktree chat (Uncommitted, Branch and Commits pick which). In Uncommitted you can stage and commit; Branch and Commits only read, and Nushi doesn't push.

When a chat's subagents work in worktrees of their own, a menu at the left of the bar picks the chat's folder or one of those **related worktrees**. One of them only reads: no staging, commit box or comments ([ADR 0081](adr/0081-related-worktrees.md)). Its diff is read when you pick it, click a scope or press Reload, because that runs the repository's filters: after a turn ends the view says **Changed** and waits for you. Once a worktree is removed its commits can still be read, while git keeps them. Nushi doesn't keep them for you: when git has collected them, the view says they're gone.

- Each file and folder has a checkbox to stage it whole. A dash means part of it is staged, by a terminal or because it changed since: a click stages all of it.
- Under the files, write a message and press Commit (⌘⏎). It commits what's staged, as `git commit` does: hooks and signing run, and what a failing hook says shows there.
- The ✨ button asks the chat's agent to write the message from what's staged and why the chat did it, for Claude and Codex while the chat is idle. Nothing commits until you press Commit, and the chat shows no trace of it.
- A commit follows your git: your identity, signing (GPG or SSH), hooks and `commit.*` settings. If signing fails, nothing is committed.
- If what's staged changed since it was shown, or files outside the chat's folder are staged, Commit refuses. While the agent is working it warns that files may change ([ADR 0079](adr/0079-stage-and-commit-from-changes.md)).

- Select lines to write a review comment for the agent.
- **Send to agent** puts the comments into the chat's box as reply cards, to send with your next message, and takes you back to the chat.
- Comments not sent yet show in the header ("Changes 2") and over the box, with Send to agent and Show.
- Taking a comment's card out of the box (or its queued message out of the queue) removes the comment: it doesn't come back with the next Send to agent.
- A comment on a file the view no longer shows (committed, reverted), or made in another view, shows above the list with the lines it was on, to remove, or to edit while not sent. A sent one goes once the turn that took it has ended and its lines or its file changed, or the file was committed.

## Previews and artifacts

A file a chat's agent (or one of its subagents) wrote previews beside the chat, kept current as it changes:

- **Markdown**, rendered;
- **images**;
- **HTML pages and SVG** in a web view: the CSS, scripts and images beside them load, and the network too. A link out opens in your browser. Reload, and Open in browser;
- **PDF**;
- **CSV** as a table (its first 500 rows);
- **code and text** (JSON, YAML, logs, source files) as their source, highlighted.

Markdown, HTML, SVG and CSV have Preview and Source.

**Artifacts** are the files made to be looked at: everything but code and text, which Changes shows. Open one from:

- its tool row's Preview;
- the Artifacts widget in the details panel, the open one marked. The palette's Artifacts… shows the panel and the widget, or lists them in a window too narrow for the panel;
- the preview's own name, while one file is open.

Each list shows the files the chat wrote that way, each with its folder and when it changed, in the same order:

1. those you pinned (the pin shows when the pointer is over a row; pins are kept per chat);
2. the recent: what the agent wrote in the last turn, the file open now, and those you opened in the last hour, newest first;
3. the rest, folded under "Older (n)".

The widget, collapsed, counts the pinned and recent; with none of either, the three newest show. The phone's Artifacts list the same way, without pins.

**An agent can open a preview itself.** Claude and Codex have a `show` tool, for a finished page, document or image. Their own permission prompt asks first, as for any MCP tool, and names the file; opening an HTML page runs it, so allowing the tool for good means pages open unasked. The file opens beside the chat if that chat's transcript is showing. If you're in another chat, in Changes or in a view, nothing moves: the latest file opens when you next come back to the transcript, and the row ("Showed report.html") keeps its Preview button either way. The phone doesn't open anything by itself; use the row's Preview. A file can be shown only if Preview could open it: an artifact inside the chat's folder or worktree, or one the chat wrote.

**Preview tabs.** A second file opens beside the first: with two or more, the pane's title row shows their names as tabs in place of the file name, and nothing else moves. Every way of opening a file does this, the agent's `show` too, and a file already open goes to its tab. Click a name to show it. Its ✕ closes it, on the tab showing or under the pointer; the next one shows, and closing the last closes the pane, as the pane's own Close does with all of them. Names too long for the row shrink, then the row scrolls. Tabs aren't kept: they go with the pane. Only the tab showing has a view, so an HTML page starts again when you come back to it. The phone has no tabs: it opens previews full screen.

**Files** (⇧⌘E, View › Files, the chat's ⋯ or the palette) opens a tree of the chat's folder (its worktree, for a worktree chat) beside the chat, left of the preview; Nushi remembers it per chat.

- Folders open with a click or →, and close with a click or ←; ↑↓ move, ⏎ opens. The tree keeps up as files come and go, and keeps what's open and selected.
- A file that previews opens in the preview as an artifact does, in a tab of its own. One the preview can't show (a zip, say) is dimmed. Nothing is edited here.
- The files the chat wrote or edited have a green dot, and so do the folders holding them.
- What git ignores is left out; the eye in the pane's header shows it, dimmed. `.git` never shows.
- A folder with more than 500 entries shows the first 500 and "N more".
- **Filter files** over the tree finds any file in the folder by name, in folders not opened too: the start of its name first, then anywhere in its name or path, then its letters in order ("trvw" finds `tree_view.dart`). The matches show as a tree, the best one picked; ⏎ opens it, Esc clears the filter.
- On the phone, the chat's ⋯ › Files shows the same tree; a file opens full screen ([ADR 0090](adr/0090-a-files-pane-beside-the-chat.md)).

**Open file** (⌘P, File › Open File…) opens any file that previews (code and text too) in the chat's folder that git doesn't ignore, matched as you type.

**Paths in messages.** A path in an agent's message, in code or plain text (`lib/a.dart:12` too), that names a file that previews, in the chat's folder or one the chat wrote, opens it too. It's underlined when the pointer is over it; on the phone it opens the full-screen preview.

### Mermaid diagrams

Mermaid diagrams draw where they appear:

- A `.mmd` or `.mermaid` file previews as its diagram, with Preview and Source.
- A ```` ```mermaid ```` block in an agent's message or a Markdown preview shows as the diagram, with Diagram and Source in its bar. It's drawn once complete; one that doesn't parse shows its source and the error.
- On the phone a file's diagram shows full screen, and a message's block has Show diagram.

Mermaid comes with Nushi (`make mermaid` fetches the pinned copy at build time), never from the network.

## Worktrees

A chat in a git repository can run in a worktree of its own, `.worktrees/<two words>`, on a new branch `nushi/<two words>` ([ADR 0016](adr/0016-a-worktree-per-chat.md)).

- **New worktree**, under the box of a chat without messages, starts one. The details panel's Worktree row does too, and also moves a chat to the repository's other worktrees. This is per chat: every new chat starts in the folder itself.
- **The branch's name.** Once a turn ends with the chat titled, the branch is named after the chat (`nushi/bump-go-1-27-3`), unless it was pushed or renamed. A quiet line in the transcript says so. The folder keeps its name.
- **Rename branch…** (the pencil beside the branch in the details panel) names it yourself, between turns.
- **The Worktrees widget** lists the worktrees the chat's subagents work in: each branch, its subagent's mark, what it changed, its commits ahead, and "merged" or "removed". A click opens it in Changes. "Merged" means git shows its commits on the chat's branch or base; a squash merge leaves nothing for git to see, so it reads "removed". The same branch shows on the subagent's line and in Background tasks.
- **The agent is told** with your next message, in a sentence of Nushi's before yours (`[Nushi] This worktree's branch was renamed from … to …. Use the new name.`), and the line then says "· told the agent". The agent's history keeps that sentence as part of your message, so a terminal resume shows it.

## Terminals

⌃\` (or the terminal button in the chat's header) shows the chat's terminals, in tabs under it, in the chat's folder ([ADR 0022](adr/0022-the-daemon-owns-terminals.md)).

- The daemon owns them, so they keep running when the app quits and reopens. A daemon restart ends them.
- The shell is your login shell. Archiving or deleting the chat closes its terminals.
- ⌘T opens another, ⌘W closes one, ⌥⌘1 – ⌥⌘9 pick one, and ⌘F finds in its scrollback.

### Running a code block

A shell block in the agent's message (` ```bash `, `sh`, `shell`, `zsh`, `console`, `terminal`) has ▷ beside Copy, on the Mac, once it has finished streaming ([ADR 0084](adr/0084-a-code-block-runs-in-your-terminal.md)).

- **▷ types the block into the chat's terminal**, as if you had: the tab it ran in last or the one the panel shows, while its shell is at a prompt; if that tab is busy (or there's none), a new tab in the chat's folder. The panel stays as it is. A leading `$ ` or `% ` is taken off; in a `console` block the lines without one are output and are left out. Several lines go in as one paste, so the shell runs them together (into bash, one by one).
- **While it runs**, ▷ is a spinner; under the pointer it's ✕ ("Running — click to cancel"), which sends ⌃C. A line under the block shows the newest line of its output, and `>_` opens the terminal on its tab. When it ends, the line keeps its last output and its exit (`exit 0`, or the code in red), and ▷ runs it again.
- **Its output goes with your next message**: a run that ends on its own, failed or not, puts a card in the box ("Output of `make check` · exit 2 · 42 lines"); your message carries the last 400 lines (32 KB at most) as a fenced block after your text, or alone. ✕ on the card drops it; running the block again replaces it. Nothing is sent by itself. A run you stop (✕, or ⌃C in the terminal) sends nothing, nor does one still running, such as a server.
- **Where it starts and ends** comes from the shell's marks (OSC 133), which fish 4 sends, and zsh or bash with shell integration. Without them the line under the block follows the terminal's newest output, ▷ shows running while the terminal runs a program, and no card comes: the end can't be told.
- The line under each block stays while the app runs, across chats; it isn't saved.

## Sleep

A chat whose agent isn't needed can sleep: its agent stops, the chat stays, and the next message wakes it (`session/load`). Chats sleep on their own after 30 idle minutes when nothing would be lost (Settings changes the time), or from a chat's menu ([ADR 0032](adr/0032-idle-chats-sleep.md)). Sleep, Archive and Reload ask first while the chat's background tasks run, since they stop with its agent, whether or not the chat is open.

## History

A chat's history is its agent's: a chat reopens from the agent's session, and resumes in a terminal from it.

**Nushi's copy.** Nushi also keeps its own read-only copy of each chat's transcript as it was shown, for what the agent no longer replays (Settings › Chat history, on by default; [ADR 0047](adr/0047-nushis-copy-of-transcripts.md)). The copy is never sent to the agent.

- After `/compact` (or Claude compacting on its own), Claude replays only what follows. A reopened chat shows the earlier part from the copy, with "Compacted here" where Claude's history starts again; a click shows the summary Claude kept.
- If the session changed elsewhere (rewound or edited in a terminal), Claude's version shows from where they differ, after a divider.

**Settings › Chat history** lists every chat's copy in a table: title, folder, agent, size, last used.

- Sort by size, last used or title; search by title and folder.
- Filter to archived chats, those whose agent no longer has them, or deleted chats' leftovers.
- Clear one (a row's Clear), those picked (click, ⇧-click a range, ⌘-click), or all; or have them cleared on their own after 30, 90 or 365 days.
- A row's title opens its chat.
- Turning the copies off asks whether to keep or delete the ones there are.

**Sessions the agent deleted.** Claude Code deletes sessions older than `cleanupPeriodDays` (30 days by default, in Claude's settings) when it starts ([ADR 0015](adr/0015-delete-takes-the-agents-history.md)).

- A chat with a copy stays, read-only. Its transcript is the copy, with Delete… and Start a new chat here (in its folder).
- A chat without one is forgotten, when you open it or when Nushi finds the session's file gone from Claude's history (at most hourly, starting nothing). The app says once which chats went.
- Nothing else is touched: a worktree and its branch stay. A chat whose worktree has uncommitted changes or commits stays too, saying Claude no longer has its session, with Delete… to deal with the worktree.
- A Codex session you archived isn't gone: run `codex unarchive <id>`, then Try again.

## Notifications

The Mac notifies you, in the phone's words, with the chat's title under each:

- when a chat needs you ("Claude needs you", "Claude has a question");
- when a turn ends ("Claude finished", 2 s after; none if the agent goes straight on or you stopped it);
- when a turn fails.

The Dock icon counts the chats that need you.

- A notification shows while Nushi isn't the app in front, or for a chat other than the one showing.
- A click opens its chat, and showing the chat clears its notifications. A "needs you" goes once the chat no longer does.
- A prompt or question ends "cancelled" when its agent stops (sleep, a crash, the daemon's restart): the agent can't take an answer then. It asks again, with a new card, if it still wants one.
- macOS asks to allow them on the first one. Settings › General › Notifications turns each kind, the sound (off at first) and the badge on or off.

Nothing leaves the Mac.
