# 0148. A message starting with "!" runs a command

Status: accepted, 2026-11-22.

## Context
The owner wants Claude Code's `!`: type a shell command in the chat's box, it runs, and its output reaches the agent; the box should look plainly different while it's a command, as Claude Code colours its prompt. Nushi already had half of it: ▷ on a code block runs it in the chat's terminal and puts its output in a card over the box for the next message (ADR 0084). Claude Code 2.1.327 answers a `!` command with a turn of its own by default (`respondToBashCommands`, docs/facts/claude.md).

## Decision
- **Command mode**: the box is in it exactly when its text starts with `!` (a space before makes it a message). Its look changes, not only its hint: code's sunk fill, a ring in the accent all round, drawn inside its edge, the text in the code font, the `!` drawn as a solid mark (a terminal glyph on the accent), "Runs in <folder>" with the send key in the pickers' place, and Run (▷) in Send's place. Nothing moves or resizes as it flips. No `/` or `@` completions and no spelling marks in it. The code is `command_mode.dart`; the composer only calls it.
- **The send key runs it** (ADR 0147's rule, either setting); a menu over the box still takes Enter first. An empty command runs nothing. Only the command leaves the box: other cards, files and images stay for the next message.
- **It runs at once, in a terminal of its own**: `OpenTerminal` with `command` (API 143) starts the login shell running it (`<shell> -l -c`) in the chat's folder and ends with it, so its end and exit are known in every shell, unlike ▷'s OSC 133 marks, which macOS's zsh and bash don't send. While the agent works too: it is the user's own act and sends nothing.
- **Its output waits in a card**, as ▷'s does (ADR 0084): running (Show, ✕), then done with its exit; it goes with the next message as Claude Code's own bare tags (`<bash-input>`, `<bash-stdout>`, `<bash-stderr>`, `<bash-exit-code>`; ADR 0084's amendment), for every agent; ✕ or ⌃C sends nothing. No turn of its own: the owner chose the card, which the user can drop before sending.
- **The desktop app only**, as ▷, **and the chat's own box**: on the phone `!x` is a message, as before, and in a side chat's box too, since its pane has no terminal panel to show a command's terminal in. A daemon older than API 143 can't run one: the box says "Running commands needs a newer daemon" and runs nothing, never sending `!x` to the agent by surprise.

## Consequences
`-l -c` reads the login files, not `.zshrc` or `.bashrc`, so aliases made only for interactive shells aren't there (the docs say so). Its terminal is a PTY, so it has no pager (`PAGER`, `GIT_PAGER` and `MANPAGER` are `cat`, `SYSTEMD_PAGER` empty): `git log` or `man` would otherwise wait in `less` and never end. A command that asks for input is answered in its terminal from the card's Show. A message that really starts with `!` needs a space first on the desktop.

## Alternatives considered
- **Typing it into the chat's terminal session, as ▷**: its end is known only from OSC 133 marks, so on most Macs it would never report.
- **A turn of its own, as Claude Code by default**: costs a turn per command and can't be dropped; the card waits for the user's words.
- **Each agent's own shell command** (Pi's `bash`, Codex's): one per agent, and none for most; one shape for all is leaner.
