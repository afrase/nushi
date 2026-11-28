# 0135. The plan pinned over the composer

Status: accepted, 2026-11-18.

## Context
The owner: "I think this plan card should stick above the prompt input. You should be able to collapse it if you want though." The plan's card (a checklist in the transcript) is made early in a turn and scrolls out of sight as the agent works; the one line over the box (the running step, only while the turn ran) said too little and went with the turn. The point is to always see where the agent is in its plan.

## Decision
- **Which plan**: the chat's latest plan while any step of it isn't done, whichever turn made it (`pinnedPlan`). The daemon keeps one plan item a turn, updated in place, and a later turn gets a new item only once the plan changed (`planLocked`), so the latest is the one the agent works to. After its turn ends it stays, so a chat opened later shows where its plan stopped. A plan done to its last step goes once its last check has drawn; a new plan takes the old one's place. Only the chat's loaded items are looked in.
- **Where**: a card on the pane over the queued messages and the box, the composer's width, under the turn's line, as Claude Code's to-dos sit under its spinner. It is part of the composer, so the update card rises above it, Jump to latest floats above it, and it goes with the composer (archived, read-only). It replaces the old line over the box.
- **Its foot is the summary line**: "Plan · 1 of 3 done", collapsed the running step's dot and words (cut short), the thin bar, a chevron at the end. The steps open above it, so the chevron never moves (`docs/design.md`'s rule); the whole line is the button, from the keyboard too. Open, the steps scroll inside it past eight steps or 40% of the window's height. No dismiss: collapsing is how to make it small.
- **Collapsed or not is one app preference** (`planCollapsed`), for every chat, kept across launches; open by default. The phone shows the collapsed line, a tap opening it in place, never saved.
- **The transcript**: the pinned plan's card is a line in its place ("Plan · 1 of 3 done · shown over the box"), so the plan isn't on screen twice; once pinned no longer it's the card again where it was made. What the reader looks at stays put as that changes: the list keeps the first entry in sight where it was, or its bottom while it follows the bottom.
- Display only: nothing is sent to the agent. Its title, bar, steps, marks and motion are `plan_view.dart`'s, shared with the card.

## Consequences
A plan the agent abandoned stays pinned until a new plan comes; collapse it. The transcript's line turns back into the card as the pinned card's last check draws, a moment before the pinned card folds away.

## Amendment (2026-11-26): no dot between a line's parts
The owner reads a middle dot between parts as an AI tell (issue 119): the foot reads "Plan 1 of 3 done" ("Plan" in `text`, the count muted after it), and the transcript's line "Plan 1 of 3 done, shown over the box".
