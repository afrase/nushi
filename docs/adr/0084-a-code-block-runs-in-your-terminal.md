# 0084. A code block runs in your terminal, its output sent only with your message

## Context
The owner wanted Claude Code's ▷ on a shell block: click it, the block runs, a line under the block follows its output, and the output goes to the agent. Claude Code types the block into the user's own terminal session (a second ▷ after ⌃C ran in the same session, under the first run's traceback), and doesn't send a run the user stopped.

## Decision
- **▷ types the block into a terminal of the chat's**, the user's own login shell's session, as the user would; no hidden terminal or `-c` script of Nushi's, so the run has the shell's history, aliases and environment, and `>_` shows it where it ran. Lines go as one bracketed paste (into bash, which on macOS lacks it, one by one).
- **Which tab**: the one the block ran in last, else the panel's, only while its shell is at a prompt. **A busy tab gets a new one**, opened in the chat's folder and not shown, rather than ▷ disabled: a server running in the tab is the usual case, and the next block (a `curl`) should still run. Typing into a busy tab would feed the running program.
- **The shell's OSC 133 marks say where the run's output starts (C) and ends (D, with its exit)**, read by the app from the terminal's stream (`ShellMarks`); the daemon is unchanged. fish 4 sends them; zsh and bash with an integration script do. Without marks the output is what follows the typed line, the end isn't known, ▷ shows running while the daemon lists a program in the tab's foreground, and no card comes.
- **The output joins the user's next message, never a turn of its own**, and only from a run that ended on its own, whatever its exit (a failure is often what the agent should see). A run the user stopped (its ✕, or ⌃C: exit 130) sends nothing and drops an earlier run's card; a run still going sends nothing. The last 400 lines, 32 KB at most, fenced, after the user's text.
- **Runs live with the chat for the app's run**, not saved: they describe a terminal session, which a daemon restart ends anyway.

## Consequences
- What the user had half typed at the prompt is in front of the block when it's typed. Nushi can't see it.
- A shell without marks never sends output. Turning on its shell integration fixes that; Nushi doesn't change the user's shell config.
- Output is read twice from the daemon (the panel's emulator and the run's follower), each with its own replay.
- Anything printed can forge an OSC 133 mark: at worst the run ends early or its output is cut wrong.

## Alternatives considered
- **A hidden terminal per block running `$SHELL -l -c '<block>'`**, its exit the shell's: the end and exit are always known, but the run isn't in the user's session, a fish user's bash block runs under fish, and the owner's screenshots show Claude Code typing into the session.
- **▷ disabled with "The terminal is busy"**: honest, but blocks the common server-then-request flow.
- **Sending the output as it comes, or when a run is stopped**: the owner's testing of Claude Code: stopping sends nothing, and nothing is sent until it ends.

## Amendment, 2026-11-22: the output goes as bare tags
The lead line "Output of `cmd` (exit N):" and its fence were words of Nushi's in the user's message; the owner's rule since is that structure goes to the agent as bare tags only. A run's output now goes as the tags Claude Code writes for its own `!` command, plus `<bash-exit-code>` (which Claude Code 2.1.314 wrote and 2.1.327 no longer does, docs/facts/claude.md; the exit says whether it failed), the same for every agent and for a command typed after `!` in the box: `<bash-input>` with the whole script, then `<bash-stdout>` with the output, an empty `<bash-stderr>` (a terminal merges the two) and `<bash-exit-code>`, a blank line between runs, after the user's text as before. The kept part is the same, the last 400 lines and 32 KB at most, without the line that said how many were left out; the card's view says it. The transcript reads the tags back (`splitCommands`): a sent message shows each command as a card in its bubble (the command, its exit, its output folded), as does a Claude session that ran `!` in a terminal (its two messages, the command then its output). The text is unchanged, so Nushi's copy and the agent's replay still match. Read back, a command's output that itself holds a whole closing tail and a next command's start shows as two cards; the agent gets the same bytes either way, as with Claude Code's own tags (docs/security.md). A message sent before shows its sentence and fence, plain Markdown, as it did.
