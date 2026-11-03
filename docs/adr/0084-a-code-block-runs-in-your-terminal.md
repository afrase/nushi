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
