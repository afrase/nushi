# 0117. GitHub links are chips with a hover card; a chat has several pull requests, each a row of the PR widget

Status: accepted, 2026-11-14. Amends [0059](0059-a-chats-pull-request.md) (one pull request a chat) and [0092](0092-the-details-panel-is-claude-codes-rail.md) (the PR widget).

## Context
The owner liked three things in Claude's desktop app: a pull request or issue link in a message is an inline chip (its icon, `owner/repo#N · title`) with a hover card (state, author, age, size); its rail lists a session's pull requests, one row each (icon in the state's color, title, `#N +adds −dels`, a CI badge `● 1/2` with a popover, a ⋯ menu); and a session has several. In Nushi such a link is underlined text, a chat has one pull request (`ChatRecord.Pull`: found by its branch's head or linked by hand), and the PR widget is a tall summary of it (checks bar, reviewers, threads with Address, the Merge control, comments). An agent that opens two pull requests, or a stack, leaves all but one outside the chat. Claude's Auto-fix is out of scope (the roadmap's "Fixing CI from the chat").

## Decision
**1. Chips in the transcript.**
- **Which links**: in a message, the user's or the agent's, once it has finished streaming (as file links), an address `https://<host>/<owner>/<repo>/pull/<n>` or `/issues/<n>` (a sub-path or fragment after it allowed) on a host Nushi gives a token to (github.com always; ADR 0045), whose text is the address itself or names the same item (`#n`, `owner/repo#n`, after "PR", "pull request" or "issue" or not). A link with words of its own stays words, with the same hover card. Code, code blocks and tool output are left alone; another host's link stays a plain link and nothing is asked about it.
- **The chip**: one line: the state's icon in its color, `owner/repo#n` in the code font (from the address, so a title can't pose as another item), ` · ` and the title, cut past 420. Fill `raised` (`userBandCodeBlock` in the user's bubble), the hover tint under the pointer, corners `tag`. Without data, the icon muted and `owner/repo#n` alone. A click opens the address as any link does; right-click: Open on GitHub, Copy link, Show in GitHub view, and Link to this chat for a pull request the chat hasn't.
- **The hover card**, after 400 ms, held while the pointer is on it: a `floatBox`, 320 wide: the state pill (Open, Draft, Merged, Closed; an issue closed as completed violet, as not planned grey), `owner/repo #n`, its age; the title, two lines at most; the author's avatar (initials, as Nushi draws people) and login; `+adds −dels` and files, or an issue's comments. No buttons. With nothing to show it says why: GitHub doesn't show it to the account (private or missing: GitHub doesn't say which), sign in (Settings › GitHub), or couldn't ask (with the last known and its age).
- **Icons**: drawn in `line_icons.dart` after GitHub's shapes (pull request open, draft, merged, closed; issue open, completed, not planned), for chips, rows, the header's chip and `StatePill`.

**2. The PR widget becomes rows.** "Pull request", "Pull requests" with two or more; its ⋯: Link pull request…. A row is 44 tall:
- the state's icon, the title (ellipsis), then the CI badge: a dot (red with any failing, amber with any running, else green) and `passed/total`; none when merged, closed or without checks. The row's ⋯ shows under the pointer or focus.
- Under it `#n`, `+adds −dels` and at most one cue, the first that applies: `Merged into main · Clean up…` (when ADR 0063 offers it), `Closed without merging`, `changes requested`, `N threads`, `N new comments`, `Ready to merge`.
- A click opens the Pull request tab on it. The badge's click opens a popover: In progress, Passed, Failed, with Fix checks, Show checks and Open on GitHub.
- Its ⋯: Open on GitHub, Copy link, View changes (the tab's Files), Merge… (ADR 0069's dialog, off with why while blocked), Send open threads to agent (Address), Ready for review on GitHub, Clean up…, Unlink.
- **Leaves the widget**, kept by the tab: the checks bar, the reviewer rows, the threads row, the Merge control, the comments row, the merged and closed notes. Folded: one pull request as today (`pullSummary`); several as "3 open, 1 merged" and the worst checks.
- **Order**: as linked, except that a stack (one's base is another's head, one repository) lists base first.

**3. Several pull requests a chat.**
- **How they join**: found by the branch's head, as now (it follows the branch); **opened in the chat**: when a tool call that ran `gh pr create` or a `create_pull_request` tool completes, the daemon links the first pull request address on a known host in its output, and it stays when the branch changes, so a stack built branch by branch stays whole; **by hand**: Link pull request… (Link another pull request… once there's one; it adds, and its list leaves out those linked), or a chip's Link to this chat. A link merely mentioned is never linked. At most 10.
- **The primary** (`Chat.pull`, all an older client sees, and where the tab first opens): the one the chat started from, else the first open one, else the first.
- **Unlink** is a row's ⋯, remembered by node id, so it isn't found or opened again. Clean up… on a row deletes that pull request's branch on GitHub; the worktree, local branch and archive parts come only once every pull request on the chat's branch has merged or closed.
- **The header's chip** is the chat's pull requests, found ones too (the roadmap's "A found pull request's chip"): the primary's icon, `#n` and badges as today, then `+2`; its hover is the card for one, the rows (no ⋯) for several; a click opens the tab. A narrow header drops the badges first. An issue the chat started from keeps its own chip.
- **The Pull request tab** shows one; with several its head starts with a menu field of the rows, its pick remembered per chat. The sidebar's dot is the worst checks of the open ones.
- **The phone**: the chat bar's chip is the primary's summary and `+2`; a tap opens a sheet of the rows, each opening GitHub. Chips are the Mac's; a tap opens the card as a sheet with Open on GitHub. No linking there.

**Data** (additive, ADR 0004; API 118 or the next free):
- `ChatRecord.Pulls []ChatGitHub` (`Branch` when found by head, `Opened` when the chat's tool opened it) and `NoPulls []string`. `Pull` is still written, as the primary, so the latest release reads the file (ADR 0108); a record without `Pulls` takes `Pull` as its first.
- `Chat.pulls = 22` (all, the primary too); `LinkChatPullRequest.add = 3` (beside the others; without it the link takes the primary's place, as before) and `unlink = 4` (that one; with neither `pull` nor `unlink` the primary goes, as before); `FindChatPullResponse.pulls = 7`.
- `GitHubItem` gains `additions`, `deletions`, `changed_files`, `created_ms`, `check_counts` (passed, failed, running, skipped; skipped count in neither side of `passed/total`, neutral as passed), `merge_state`, `state_reason`, `base`, `head`; the inbox leaves them unset.
- **`GetGitHubItems(refs, quiet) → items, unseen, error`**: up to 50 `owner/repo#n` of one host in one GraphQL query, an alias a repository and an item (`repository { issueOrPullRequest(number) }`), about a point; a `NOT_FOUND` alias is `unseen`, the rest still answer. Rows and chips both use it; `GetGitHubPull` is asked only for the tab's pull request and for Fix checks and Merge…. An older daemon gets the rows from `GetGitHubPull` of the primary.

**Fetching and limits.**
- The daemon keeps an item by its ref: 30 s while open, 10 minutes merged or closed, `unseen` 10 minutes, 1,000 at most; it feeds the states' cache.
- The app keeps a store a daemon, for the session, not on disk: a chip asks once when first built (quiet: held back while the bucket is under 200), gathered over 250 ms into one call a host; a hover asks again, not quiet, for what's over a minute old. Chips never poll. A chat's rows ask each minute while it's open and at ADR 0059's moments (a push, a turn's end, the window to the front): about a point a minute for three, less than today's whole pull request (about 2).
- **Enterprise**: a host gh is signed in to, or with a token, works as github.com; one that refuses a field (an old server) is asked again without the check counts, remembered for the host. A host Nushi doesn't know gets no chip and no request.
- **Others' text**: a title is one line of plain text (`githubapi.plain`), never Markdown, never sent to an agent. A chip asks GitHub, with the user's token, about any repository an agent names; the agent can already do that with `gh`, and nothing goes past the host. `docs/security.md` gets an entry.

## Consequences
- The rows are a glance, not a work surface: merging, reviewers and threads are a click further, in the tab or the ⋯.
- A second pull request the agent opens is no longer lost, and a found one finally has a header chip.
- A transcript full of links costs about a point per 50 links a session.
- Each reader of `Pull` (Clean up, the sidebar's dots, the phone) moves to the list; until then it sees the primary.

## Alternatives considered
- **Rows inside the Changes widget**, as Claude's rail: a card fewer, but local changes and GitHub's fold, hide and reorder separately, and Changes outside git would hold pull requests it can't have.
- **The tall widget once per pull request**: three fill the panel.
- **Linking every pull request a chat mentions**: an upstream fix isn't the chat's work.
- **Chips from the address alone**: no title, most of the point.
- **GitHub's avatar images**: another host to reach and a cache to keep.

**4. A card where the chat opened or merged one.** Live only, as in Claude's app: when a tool call of the open chat opens a pull request (`gh pr create`, a `create_pull_request` tool; the daemon links it, section 3, `Opened`) or merges one linked to the chat (`gh pr merge`, a `merge_pull_request` tool), the transcript shows a card for it after that tool call's turn group, so a collapsed group doesn't hide it. It lives in the app's memory for that open chat only: switching to another chat or restarting the app drops it, and it is never saved with the chat; the chip in the text and the rows stay. It should stand out, as opening or merging a pull request is a big moment in a chat:
- a filled `raised` card, corners `card`, full width of the messages column, with no coloured edge;
- a top line: the state pill (as the hover card; the current state, Open or Merged), `owner/repo #n · author · age` muted;
- the title, two lines at most, in the body's size and weight;
- on the right of the title, the files count and `+adds −dels` as two `tag` chips;
- under a hairline, one line: the CI badge and its words (`2 of 3 checks passed`, `Checks running`, `1 check failing`), or the cue from the row (section 2), or nothing;
- a click opens the Pull request tab on it; the right-click menu is the row's ⋯; no buttons on the card itself.
It reads the same `GetGitHubItems` data as the chips and rows; before it answers, the card shows `owner/repo #n` and the tool output's address. Not on the phone.

## Settled
1. Rows in their own widget, not inside Changes.
2. A chip's click opens the browser, as any link.
3. Only addresses become chips; bare `owner/repo#n` and `#n` stay text.
4. Merge only from the row's ⋯ and the tab.
5. No "Mentioned" list.
6. 10 a chat.
7. GitHub's shapes wherever `StatePill` and the state icons are drawn.
8. The card of section 4: yes, live only, as Claude's app (the owner, 2026-11-14).
