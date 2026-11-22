# 0147. Enter starts a new line

Status: accepted, 2026-11-22.

## Context
Enter sends in every box that sends to an agent or saves a reply (the composer, a reply box, the reply dialog, a subagent's box, a review comment), and ⇧⏎, ⌥⏎ or ⌃⏎ starts a line. The owner wants an option for people who press Enter for new lines, as Slack's "When writing a message, press Enter to: start a new line (⌘Enter to send)". While a turn runs, Enter queues and ⌘⏎ stops the turn and sends.

## Decision
- **One app preference**, `enterStartsLine` in `app.json`, off at first, a switch in Settings › General: "Enter starts a new line". On, Enter (alone or with ⇧, ⌥ or ⌃) starts a line and the command key with Enter sends (⌘⏎; Ctrl+Enter where Control is the command key), as does the Send button.
- **One rule for every box.** `isSendKey` in `composer_parts.dart` reads the preference, so every box that uses it changes together; no box reads it itself. The boxes that already send with ⌘⏎ only (a GitHub comment, a commit, a pull request's edit) are untouched.
- **While a turn runs, the ordinary send key keeps the ordinary meaning.** On, ⌘⏎ queues and ⇧⌘⏎ stops the turn and sends: the key that sends while the agent is idle never becomes the destructive one. Off, as before (⏎ queues, ⌘⏎ stops and sends, ⇧⌘⏎ starts a line).
- **A menu over the box takes plain Enter in both modes** (the commands' and files' list, the spelling menu): Enter picks, never sends nor starts a line.
- **The keys shown come from the rule** (`sendKeyLabel`, `sendNowKeyLabel`): Send's, Queue's and Stop and send's tooltips, the busy box's hint, a reply box's button; they change with the setting.
- **The phone has no such setting**: its Return always sends (the rule ignores the preference on the web build).

## Consequences
A new box that sends uses `EnterSends` or `enterKey` and follows the setting for free; a hint or tooltip naming its send key reads `sendKeyLabel`. Undoing this is the preference and its row; the rule's off branch is the old behaviour.
