# 0088. Claude's `/plan` runs in the daemon

## Context
The owner typed `/plan` in a Claude chat and got "/plan isn't available in this environment.": claude, run headless by both the adapter and the Go agent, refuses the commands only its terminal runs, and neither agent lists them ([docs/facts/claude.md](../facts/claude.md)). Plan mode itself is a chat option Nushi has (the mode menu's Plan). The phone sends prompts through the same call as the Mac.

## Decision
- **An agent's harness may name commands of its terminal that set a chat option** (`chats.TerminalCommands`, met by `claude.Harness`): the chat offers them with the agent's own commands, and `Prompt` runs one in the daemon instead of sending it, so the Mac and the phone get the same. Claude's is `/plan`, setting the `mode` option to `plan`.
- **It does what the mode menu does** (`SetConfig`: the agent's own call, the mode remembered for the agent), leaves a `command` notice with the terminal's words ("Enabled plan mode"), then sends the text after the command, if any, as an ordinary message, queued or refused as any message would be.
- **In plan mode already**, `/plan` alone says "Already in plan mode."; `/plan <text>` sends the text, with no notice and no mode change. The terminal drops the text there: losing the user's message isn't worth the parity. Otherwise Nushi does as the terminal: `/plan open` and `/plan share` are `/plan`.
- **The answer says so** (`SendPromptResponse.ran_command`), so the app drops the message it showed while sending instead of waiting for an echo that doesn't come.
- Other agents' `/plan` and every other command go to the agent as typed.

## Consequences
- Nushi doesn't show the plan file or open it in an editor, as the terminal's `/plan` does in plan mode.
- `/plan <text>` in plan mode differs from the terminal, which drops the text.
- A command claude starts running headless one day is still run by Nushi while the harness names it.

## Alternatives considered
- Answering it in the app, as `/copy` ([ADR 0075](0075-copy-is-nushis-own-command.md)): the phone would need its own copy, and the agent-specific knowledge would sit in the app.
- Dropping `/plan <text>`'s text in plan mode, as the terminal does: parity, at the cost of the user's message.
