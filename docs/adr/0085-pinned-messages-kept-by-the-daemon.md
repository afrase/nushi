# 0085. Pinned messages are the daemon's, keyed by item id and opening

## Context
The owner, from Claude Code's desktop app: a pin on a message's actions marks it, and marks at the transcript's top left open a list of them, with where the session starts; a pick jumps there. The phone and another Mac should show the same pins, as they do a chat's pin (ADR [0064](0064-the-daemon-keeps-pinned-chats.md)).

A pin needs a key that holds while the chat does. An item's id holds across a restart, a reopen, a Reload, a move and a fork while Nushi's copy of the transcript is kept (ADR [0047](0047-nushis-copy-of-transcripts.md)): the copy's items stand where they line up with the replay, and a fork starts with its chat's items. Without a copy (Keep transcripts off, or the copy cleared) a reopen shows the agent's replay alone, which names the user's messages anew (the agent's ids, or Nushi's `item-N` again) and the agent's too when it gives them no ids.

## Decision
- **The chat's record keeps its pins** (`ChatRecord.Pins`, in the order pinned), sent as `Chat.pinned_messages`, the items' ids (API 102). `PinMessage` pins or unpins one message, the user's or the agent's own (not a subagent's, a tool call or a card): one call per message, so two clients pinning different messages both land.
- **A pin keeps its item's id and its message's opening**: the kind, a hash of its first 200 runes, and how many messages of that kind before it open the same. When a reopen makes the transcript (copy and replay merged), each pin is looked for: its id, if that item still opens the same; else, for an id Nushi gave (`item-N`), the nth message that opens as it did. The agent's own ids are the same live and replayed, so a pin on one isn't moved to another message that only opens alike ("Done."). A pin whose message isn't found goes.
- **It follows the transcript**: a rewind that cuts a pinned message drops its pin, as does a message taken back unsent; Delete drops them with the record; a fork, and a side chat kept as a chat, keep the pins of the messages they keep; Archive keeps them.
- **The app** shows the pin among a message's hover actions (Pin, Unpin) and a mark beside a pinned message; the chip over the transcript's top left (a pin and the count, only while there are pins) opens the list, "Start of the chat" first, then the pins in the transcript's order. A pick jumps there as find does and tints the message for a moment. The phone has no actions row: it shows the marks and the list, taking the older pages its pins are on first.

## Consequences
- A pin doesn't survive its message leaving the agent's history while there's no copy: a compaction (Claude replays only what follows it), a rewind or edit in a terminal, or a session the agent deleted. With the copy it does, as the copy shows the message.
- Without a copy, two of the user's messages that open with the same 200 characters are told apart by their order only: one gone from before the pinned one moves the pin to the next that opens alike.
- The record holds a hash of each pinned message's opening, not its text.

## Alternatives considered
- The id alone: simplest, but every pin of a user's message is lost on a reopen without a copy.
- The whole list in one call, as `PinChats`: a list has no order to set here, and two clients would overwrite each other's pins.
- The app's `app.json`: no phone, and another Mac wouldn't see them.
