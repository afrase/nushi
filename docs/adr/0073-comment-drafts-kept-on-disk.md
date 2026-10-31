# 0073. GitHub's and Jira's drafts kept on disk

## Context
ADR 0062 keeps a chat's draft across a crash or restart and left comment boxes off disk; ADR 0027's amendment of 2026-10-30 kept them for as long as the app runs, with a review's inline comments in memory the same way. A long review lost on a restart costs as much as a long message.

## Decision
- The Mac keeps every comment box's text and each pull request's unsent inline comments in `comment_drafts.json` in the data folder (0600, written whole), read at start, saved 500 ms after they stop changing and when the app goes to the back or quits, and removed once none is left.
- A draft goes as it did: posted, emptied or cancelled, an inline comment removed or sent with the review.
- The phone keeps none: it has no such boxes.

## Consequences
- A draft for a pull request or issue you never go back to stays in the file; it's small, and it shows if you do go back.
- What you write sits on disk in clear until posted, as a chat's draft does.
- A crash loses at most the last 500 ms of typing.
- Which file or lines Files had open, and a pull request's tab, are still kept only while the app runs.

## Alternatives considered
- `drafts.json`: it's keyed by chat and goes with the chat, and these belong to a pull request or issue.
- Dropping a draft when its pull request closes: it needs the state of every drafted pull request at start, for little.
