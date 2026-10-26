# Demos

Each milestone's demo script (what to run, what to see), newest first. An archive.

## Demo (controls that look like controls, steps 281–290)

1. Settings › General: the terminal's font and size and Sleep idle are boxes with a ▾; hover one (it darkens), Tab to it (a blue ring), Space opens it. Show logs is an outlined button. The preview shows a folder, Go and Apple icon.
2. A chat: the composer's mode and model end in a ▾ and tint under the pointer; the header's ⋯ is a button with a tooltip.
3. The details panel: point at a card's title: the open hand and six dots on the right (on a collapsed card, in place of "57%"); drag it: the closed hand.
4. Hold ⌘ for a moment: ⌘1, ⌘2… on the sidebar's chats. ⌘2 opens the second; ⌘] and ⌘[ step through them. A quick ⌘J shows no numbers.
5. ⌘J: every row has a Start work ▾ button; the site is a picker with a ▾; ⌥⌘2 switches to the second list. In a terminal, ⌥⌘1 is the first tab, ⌘1 still the first chat.
6. Delete… a chat, or Remove a Jira site: the button that loses something is red.

## Demo (Nushi's copy of transcripts, steps 272–280)

1. In a throwaway folder, start a Claude chat; ask for two small changes (it reads and edits files). Send `/compact`, then one more message.
2. Quit Nushi and restart the daemon (or wait for a sleep and reopen): the whole chat shows again, with "Compacted here" where Claude's own history starts; a click on it shows the summary Claude kept.
3. Settings › General › Transcripts: the chat's copy with its size and last use. Clear it, restart the daemon and reopen: only what follows the compaction shows, as before.
4. Move the session's `<id>.jsonl` out of `~/.claude/projects/<the folder's name>/` (a chat with a copy) and restart the daemon: the chat stays, "expired", its transcript the copy, with Delete… and Start a new chat here in place of the box.
5. Turn Keep transcripts off: it asks whether to keep or delete the copies.

## Demo (the expired sessions fix, steps 269–270)

1. In a throwaway folder, start a Claude chat, send "say ok", Sleep it, quit the app.
2. Move the session's `<id>.jsonl` out of `~/.claude/projects/<the folder's name>/` (this chat's only), and restart the daemon.
3. Open Nushi: a bar says "Removed “…”: Claude no longer had its session (Claude Code deletes sessions after 30 days by default)."; the chat is gone from the sidebar. OK dismisses the bar.
4. The same with a chat in a worktree that has an uncommitted change: the chat stays, "expired" with a quiet clock, its notice says why, Delete… asks about the worktree.

## Demo (milestone AF)

With gh signed in: ⌘G shows the inbox (Review requested, My pull requests, Assigned issues); "My folders' repositories" narrows it. ⏎ on a pull request: its header, Conversation, Checks (click a failed one for its log), Files (threads at their lines; select lines to write an inline comment; Review… sends it). Start work on it opens the New chat dialog: the chat runs in a worktree on the pull request's branch, and its header shows the pull request's state; Fix checks puts a message for the agent in its box. Settings › GitHub shows your login and what's left of the rate limits.

## Demo (the transcript as chapters, steps 235–237)

1. Open a chat with a few exchanges: each of your messages is a blue band across the transcript, bigger and semibold; Claude's replies run between them with no "Claude" above them.
2. Tool rows are teal, subagent lines violet; a failed call is red.
3. Ask Claude to run `sleep 20; echo done` in the background and end its turn: when the command ends, its answer starts under "On its own, after a background task" (after the installed daemon has restarted).
4. Switch to the light theme: the same, in the light tokens.

## Demo (the background-subagent fix, steps 226–230)

1. In a Claude chat: "Start a background general-purpose subagent that runs `sleep 90; date` and reports the date; don't wait for it." Claude answers in a few seconds; the status line and its timer go, the composer says its usual hint, the subagent's line runs on.
2. Send "What is 17 times 3?": it goes at once and Claude answers while the subagent sleeps. Open the Context card: it fills.
3. Open the subagent's pane and send it "also say hello": the message shows in its steps, "waiting for Claude to pass it on", then "passed on". When it reports, Claude answers on its own.
4. Start another, ask Claude to run a slow command itself, and Stop (⌘⏎ or Esc) mid-command: "Stopped", and the subagent still reports. Sleep the chat while one runs: it asks first, and the line then says "stopped".

## Demo (the reopen fix, steps 211–215)

1. Settings › Agents › Remove on Claude; in a Claude chat, send a message: "Couldn't reopen the chat: Claude isn't set up: Settings › Agents", Set up…, the header "couldn't start".
2. Set up… opens Settings on Claude's row (marked); Set up; close Settings: the chat reopens by itself and the notice goes, the queued message is sent.
3. Scroll a long chat to its bottom and past it: it stops, no bounce.

## Demo (the Jira follow-up, steps 204–210)

1. ⌘N in a repository's folder (its +): I, paste an issue's link from the browser (or type its key, or words of it), Enter: "Chat on ABC-12", a worktree on `ABC-12-…` ticked. B to rename the branch, W to drop the worktree, ⌫ to drop the issue.
2. Enter with Claude: the box is empty, the key in the header. Ask "which issue is this chat for?", then to comment on it: its permission card, then the comment in the issue's details, "by Claude in …".
3. ⌘J: your open issues by status. Move one from its status; Start work › a folder › the dialog with it picked; ⏎ for its details, Esc back.

## Demo (milestone AE)

1. Settings › Jira: Add a site (your-site.atlassian.net, your email, an API token from id.atlassian.com): "Connected as <you>".
2. ⌘J: your open issues. Sprint: pick the board once; its active sprint lists. JQL: type `project = ABC AND sta`, Tab, `= In`, pick "In Progress", Enter; Save… as "Doing".
3. Pick an issue: its status menu moves it; write a comment in Markdown, ⌘⏎.
4. Start a chat ▾ › a repository, pick Claude, W for a worktree, Enter: the chat opens with the issue in the box, on a branch `ABC-12-…`. Send it; ask Claude to comment on the issue with what it found: its permission card, then the comment in the issue view, "by Claude in …".

## Demo (PiG follow-up, steps 172–175)

1. In a PiG chat with a few turns, type `/`: `/compact` and `/name` are listed. Send `/compact keep the file names`: a "Compact conversation" card; open it for PiG's summary. The Context card's size drops and its list says "Compactions: 1".
2. `/name Release work`: the chat's title changes.
3. Restart daemon, open the chat: the card is where it was.

## Demo (milestone AB)

1. Install `pig` and Restart daemon: Settings › Agents shows PiG with its pig, version and path, Ready.
2. ⌘N, pick PiG: the header shows PiG, the model (your default) and the thinking level. Ask it to edit a file and run `ls`: the edit's diff and the command's output show; nothing asks first.
3. Sleep the chat, send another message: it wakes on the model it had. Rewind to the second message; open a side chat.
4. In a terminal, `pig -p "remember avocado"` in the same folder; ⌘N, PiG, →: the session is listed; Enter opens it; send a turn; `pig -p --session <id> "what did I say?"` in the terminal sees both.
5. Delete the chat: its session file is in the Trash.

## Demo (milestone Z)

1. Restart daemon, then open Settings › Agents: each agent with its version and path; Claude and Codex say Set up.
2. Set up Claude: the sheet says what it downloads and where; a second later the row says "Adapter 0.94.0". Start a Claude chat: `ps` shows your `~/.local/bin/claude` under `node …/Nushi/agents/claude/…`.
3. Remove Codex: its chats sleep; ⌘N shows Codex dimmed with Set up, which opens Settings › Agents.

## Demo (milestone Y)

1. With Nushi open, quit it: no "Nushi" stays in the Dock. Activity Monitor lists "Nushi Daemon" with the Nushi icon.
2. Settings › Start at login: turn it on. System Settings › General › Login Items lists Nushi under Allow in the Background.
3. Log out and in: the daemon runs before the app is opened (`pgrep -l nushid`), with your PATH: start a Codex chat from the app.
4. "Restart daemon" (when offered) brings up the helper; `make stop` still stops it.

## Demo (milestone X)

1. In a terminal, in a repository, run `claude` and say something; quit it, or leave it open.
2. In Nushi, a folder's + (or ⌘N for every folder), then → on Claude: the session is listed with when it was last active (and "open in a terminal" if it still runs there). Enter opens it as a chat, with its transcript.
3. Send a message, then `claude --resume <id>` in the terminal: the history has both.
4. Do the same with `codex` left open: its session shows dimmed, "open in another app"; quit Codex (its background app-server may keep the thread a while) and it opens.

## Demo (milestone W)

1. Click "New chat" (or ⌘N): a small dialog lists the agents with their marks, the last one used picked. Enter starts it.
2. Click a folder's +: "New chat in <folder>"; press 3 to start Ante there, or ↓ and Enter.
3. The sidebar: each chat's status dot, then its agent's mark. The chat header shows the same mark.
4. Make an agent fail to start (say, move `~/.ante/bin/ante` away): the error shows, and the next dialog shows Ante dimmed, "Ante isn't installed".

## Demo (milestone V)

1. Run a relay: `make relay && bin/nushi-relay -addr 127.0.0.1:8080`.
2. Settings → Remote access: type `ws://127.0.0.1:8080`, turn it on: "Connected", and a phone appears at the bottom right of the window.
3. "Pair a phone": a QR code. Until the phone app exists, pair from Dart with `packages/remote_transport` (`pair(PairingOffer.parse(qr), …)`): the Mac then asks "Pair <name>?" with the code the phone prints; Allow, and the device is listed, connected.
4. Revoke it: it's gone, and its connection drops. Stop the relay: the state turns red with why.

## Demo (milestone U)

1. Right-click a chat in the sidebar and pick Sleep: its dot becomes a moon, and the bar's moon count goes up.
2. Open it: the transcript is there, the header says asleep. Send a message: it wakes, on the model it had, and answers.
3. Click the memory at the bottom right: the awake chats with what each takes, each with Sleep.
4. In Settings, "Sleep idle" picks when idle chats sleep (30 minutes by default).

## Demo (milestone T)

1. Open the menu beside "New chat" and pick Ante: the header says Ante with its model; the Context card shows Ante's own breakdown before any message.
2. Pick DeepSeek V4.1 Flash, ask Ante to write a file: a permission card with the diff (Allow, Allow for this session, Deny).
3. Ask Ante to use AskUser: a question card with an Other field.
4. Restart the daemon and open the chat: it comes back from Ante's session; Rewind on a message forks Ante's session after the turn before it.
5. Pick oh-my-pi: model and effort pickers from omp; a command asks first; Delete says omp keeps its history.

## Demo (milestone S)

1. Open the menu beside "New chat" and pick Codex: the button now reads "New Codex chat", and the header says Codex with DeepSeek V4.1 Flash; the pickers show the mode (Read-only, Workspace access, Auto review, Full access), the model and the effort.
2. In Read-only, ask Codex to run `printf hi > x.txt`: a permission card, then the command and its output in the transcript.
3. While Codex runs `sleep 8`, send another message: it goes into the running turn.
4. Restart the daemon and open the chat: it comes back from Codex's history; `codex resume <session id>` opens it in a terminal.
5. Put a `.codex/config.toml` in a repository and start a Codex chat there: the card shows the file whole.

## Demo (milestone R)

1. Put a `.claude/skills/x/SKILL.md` with a `hooks:` block in a repository and start a chat there: the trust card shows the skill's front matter, raw, in a box that scrolls.
2. Rebuild and reinstall the app while its daemon runs: a bar says a newer daemon is installed, with Restart daemon.
3. Queue a review while Claude works, then take it out of the queue: its comments count as unsent again.
4. In a worktree chat without messages, open a terminal, then move the chat back to the repository: the worktree stays, and Delete offers it.
5. Open a chat whose folder is gone: one "Couldn't reopen" notice, not one per look.

## Demo (milestone Q)

1. In a repository, ask Claude in Manual mode to run a long command that writes a file: the permission card shows the whole command, wrapped.
2. Open a terminal in the chat, run `sleep 300`, then pick Archive: it asks first, naming `sleep 300`.
3. With the terminal focused, ask Claude to use AskUserQuestion: Enter and digits stay in the terminal.
4. Ask Claude to run a 30-second foreground command, then stop the daemon: the command ends at once; after a restart the chat shows it interrupted.
5. In Changes, an untracked repository inside the folder reads "Not shown: … is a repository of its own" instead of failing the view.
