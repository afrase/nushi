# 0140. What a chat's pull requests ask of GitHub

Status: accepted, 2026-11-20. Amends [0117](0117-github-links-as-chips-and-a-chats-pull-requests.md) (fetching) and [0138](0138-a-chat-needs-you-when-its-checks-fail.md) (the states each minute).

## Context
Since ADR 0138 the app asks for its chats' pull requests' states for its whole life. Beside that, the open chat asked each minute for its branch's pull request, its rows and the pull request whole, whether its Pull request tab showed or not (issue #87). With five chats and one open, an idle hour cost 241 asks, each a request to GitHub (the daemon keeps states and rows 20 to 30 s; the pull request whole not at all): 181 GraphQL queries (60 states, 61 rows, 60 whole pull requests, the heaviest query Nushi makes) and 60 conditional REST requests for the branch. The window in the background asked as much.

## Decision
- **One poll for every chat's rows.** From API 133 the rows' items say the commit their checks are of (`checks_oid`), so the chats' states are asked as the rows' items: one `GetGitHubItems` a minute for every chat not archived that has a pull request (50 to a query, a host each). A chat's own rows ride on it; its timer asks only for a link without a node id.
- **The pull request whole only while the tab shows it.** The widget's summary, cue and new comments come from the row's item: new comments are those its count has past what the chat last saw (`pullSeenComments` in `app.json`, by chat and node id; what's there when a chat first knows a pull request isn't new). Fix checks, Merge…, Clean up… and Ask to fix read it whole as they start, unless the tab shows it.
- **The branch looked up only while needed.** The timer asks for the branch's pull request only while the chat has none open; a push or `gh pr create` from the chat, a turn's end and the window to the front still look.
- **Slower when nothing moves.** Once all of the chats' pull requests are merged or closed, every 15 minutes (the daemon keeps their states 10 minutes too). While the window isn't in front, every 5 minutes; back in front, at once if a minute has passed.
- **Kept**: the daemon asks GitHub only when the app asks (ADR 0045); REST reads send their ETag (a 304 costs no rate limit); polls are held back while a bucket runs low and stop while it's spent (`githubapi/limits.go`). GraphQL has no conditional request; batching is its saving.
- **The primary** (ADR 0117: the one the chat started from, else the first still open, else the first) is the daemon's pick now: each link remembers whether GitHub last said it was merged or closed, from those same answers.

## Consequences
- The same idle hour, focused: 60 asks, one GraphQL query each; in the background, 12; all merged, 4 (and the branch looked up 4 times). The Pull request tab adds its whole pull request each minute while it shows.
- A failure flags a chat (ADR 0138) up to 5 minutes later while the window is in the background.
- The widget's "N new comments" counts comments, not their times: a deleted comment can hide a new one.
- The phone's chip still reads its primary whole each minute while the chat shows.
- 2026-11-24: the GitHub view's pull request pane, outside a chat, polls the same way (each minute, every 15 once merged or closed, every 5 in the background), in place of its fixed 30 s (ADR 0046).
- 2026-11-24: the header's chip of a chat's issue reads GitHubItems (asked once when built, as a link's chip is), and the chats' issues ride on the minute's `GetGitHubItems`; its own minute `GetGitHubStates` goes. The daemon answers an older app's `GetGitHubStates` from the items it keeps by number; its states cache and query are gone, and a write made in Nushi makes its host's items old.
