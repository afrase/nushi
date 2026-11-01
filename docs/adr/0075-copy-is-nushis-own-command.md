# 0075. `/copy` is Nushi's own command

## Context
The owner: selecting text and copying "sometimes doesn't copy it correctly", so a whole message should be copyable with its formatting. Claude Code has `/copy`; through ACP there's nothing for it to run, and the other agents have none.

## Decision
- `/copy` puts the agent's latest message on the clipboard as the Markdown it wrote; `/copy 2` the one before, and so on. It counts the main agent's messages, each text between tool calls being one, and skips subagents'.
- The composer answers it (`copy_command.dart`): the agent never sees it, in any chat, whether or not a turn runs. It's offered among the `/` commands, in place of an agent's own `copy` if one has it.
- Only exactly `/copy` or `/copy N` is taken; anything else starting that way goes to the agent.

## Consequences
- Only messages loaded in the chat count: a long chat's older pages aren't reached.
- A `/copy` of the agent's own can't be run from Nushi.

## Amendment (2026-11-01)
Each message's hover row has a Copy too ([ADR 0076](0076-messages-as-bubbles-with-actions-on-hover.md)).

## Alternatives considered
- Copying rendered text: it loses the formatting this is for.
