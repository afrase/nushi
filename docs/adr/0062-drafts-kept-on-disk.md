# 0062. Drafts kept on disk

## Context
"Save what the user types into the input box. I have a large message, and if the app crashed or reset, it would suck to lose it." A chat's draft (the box's text, @-mentioned files, reply cards, images, the subagents' boxes) lived on the chat in memory only: it outlived the box, not the app.

## Decision
- The Mac keeps every chat's draft in `drafts.json` in the data folder (0600, written whole: a file beside it renamed over it), with each image as a file in `drafts/` (0600; the folder 0700) named in the draft. Saved 500 ms after the draft stops changing, at once when it empties (sent or cleared), and when the app goes to the back or quits; put back when the app lists the chat.
- What's kept: the text with its cursor, the mentions, the reply cards, the images, a quote not yet taken, the subagent a taken-back message was for, and each subagent box's text. Not the reply box over a selection or a review comment being written: both are short and tied to what's on screen.
- An empty draft isn't written (no drafts: no file). A draft goes with its chat: deleted (here or while the app was away) or archived. Nothing is truncated: a draft over 1 MB is kept whole.
- The phone keeps the text and the reply cards (no images) in IndexedDB, one record beside its pairing, saved the same way and when the page hides; Forget this Mac removes it.
- `Drafts` (the app's `drafts.dart`) does the when; a `DraftStore` does the where (`drafts_mac.dart`, `phone/phone_drafts.dart`), given to the `Daemon` at start. Tests get none.

## Consequences
- What you write sits on disk in clear until sent, as the transcripts' copies do (ADR 0047).
- A crash loses at most the last 500 ms of typing.

## Alternatives considered
- The daemon keeping drafts: one store for both, but a round trip per pause and a draft per device is what each wants.
- `app.json`: rewritten whole on every setting; a 1 MB draft would ride along each time.
