# GitHub

## Signing in

If you're signed in to `gh` (`gh auth login`), GitHub works as is. The daemon reads gh's token for each host gh knows, as gh does (the environment's `GH_TOKEN`, gh's config, or `gh auth token`), in its own process.

Settings › GitHub shows each host, who its token is and where it's from, and what's left of GitHub's rate limits this hour (shared with your `gh` and agents that run it).

For a host without gh, or instead of gh's login, add a token there:

- A classic token with `repo` and `read:org` covers what Nushi does.
- A fine-grained token sees one owner's repositories, and no checks.

Nushi checks it with GitHub and keeps it in your login keychain ([ADR 0045](adr/0045-github-through-our-own-client-gh-login-first.md)). A token is only ever sent to its own host.

## The inbox

⌘G (View › GitHub, or GitHub at the sidebar's foot) shows GitHub in the chat's place, as an inbox of three cards:

- **Review requested**: pull requests whose review is asked of you by name, or of your teams too ("Only me ▾" picks, remembered);
- **My pull requests**;
- **Assigned issues**.

Drag a card by its title row to reorder the cards, and click its title to collapse it. Both are remembered.

**Each row** shows its title with `owner/repo#123` under it and its chats, then its review decision, checks, review threads not resolved (else comments), and when it changed ("12d", "5w", "3mo"; the date and time on hover). Start work shows on the row under the pointer and the selected one (⌘⏎), and in its right-click menu with Open on GitHub and Hide this repository.

**The bar** picks what's listed, remembered:

- "Last 90 days ▾": 30 days, a year, or any time. A card ends with "3 older than 90 days · Show" to see them until Nushi quits.
- The repositories: all, those of the folders Nushi knows, or only some owners' (such as `octo-org acme`). The owners and repositories are listed, checked while shown, to hide one or show it again.

The filters go into GitHub's searches, so what they leave out doesn't take the 50 places of a card.

**Details.** ⏎ or a click shows an item's details:

- a pull request's header: base ← head, author, reviewers and their states, whether it can merge;
- its conversation, with a comment box;
- its checks: a failed one opens to its annotations and the end of its job's log;
- its files in Nushi's diff view, with the review threads at their lines (Reply, Resolve, Unresolve). Select lines to write an inline comment of your review, then Review… sends it with all of them (comment, approve, request changes).

**What you're writing waits.** A reply, a comment, an inline comment or a review's text not sent yet is still there when you come back from a chat or Settings, with the pull request's tab and file as you left them; each thread's reply is its own. Sending it, emptying the box or Cancel (a reply's or an inline comment's) clears it; quitting Nushi loses it. Jira's comment box keeps its text the same way.

**Going back.** Esc or ← goes back to the inbox, and so does a swipe back, as in Safari: two fingers right on the trackpad (three if macOS's Swipe between pages says so), not while a diff or code block under them scrolls. An arrow at the left edge fills as the swipe gets far enough; short of it nothing happens. The mouse's back button goes back too, here, in Jira and in New chat's lists.

**Freshness.** The inbox shows as GitHub gave it last while it's asked again. It's asked for again each minute while it shows, an open pull request every 30 s ([ADR 0046](adr/0046-the-github-inbox-and-polling.md)). Nothing reaches GitHub otherwise, and Nushi writes to it only what you send. Merging isn't offered yet.

## Starting work

Start work on a pull request or an issue picks a folder (a clone of its repository first), then opens the New chat dialog with it.

- **A pull request's** worktree starts on its head, fetched from the folder's remote that is its repository. A branch of it is checked out and tracks it, so a push goes to the pull request. A fork's comes from `refs/pull/<n>/head`, read-only, on `pr-<n>-<branch>`.
- **An issue's** starts on a branch named after it (`123-add-a-thing`).

The chat's header shows the pull request's or issue's state, checks, review and threads (hover for more; a click shows it), and its details list its chats.

A pull request's To do list (below) puts reply cards in its chat's box: the chat picked when it has several, or Start work first when it has none. It works as in a chat's Pull request tab (a failed check with its log's failing part; a review thread; a finding): read, change and send them with your message. What GitHub holds goes in as data, never as instructions, and authors outside the repository are marked.

## A chat's pull request

A chat on a branch finds its pull request by itself: the one whose head is the branch ([ADR 0059](adr/0059-a-chats-pull-request.md)). It looks:

- when the chat opens, and each minute while it's open (the details panel shown or not);
- a few seconds after the agent pushes or runs `gh pr create`, and after each turn;
- when Nushi's window comes to the front.

The widget's title says when it last looked ("Checked 20 s ago · every minute").

### The Pull request widget

The details panel's **Pull request** widget sums it up:

- its state, number and title;
- the checks as a bar with their counts, and Fix checks while some fail;
- a row for each reviewer who counts: one asked and waiting, or how they reviewed, so an approval can't hide a missing code owner;
- the open review threads, with Address;
- Ready to merge, or Merge blocked and by what (checks, review, threads, conflicts);
- the comments, and how many are new.

A draft says its reviewers aren't asked yet (Ready for review opens GitHub); a merged one says what it merged into; a closed one where its commits stay (Reopen on GitHub).

Collapsed, it's one line: the number in its state's color, then failing or running checks, changes requested or a reviewer waited on, open threads and new comments; or Ready, Draft, Merged, Closed.

Its menu opens it on GitHub, links another (a link, `owner/name#n`, a number, or one of yours) or unlinks it. Without one it says "No pull request for `branch`", with Link….

### The Pull request tab

**Pull request**, beside Chat and Changes, is the GitHub view's pull request in the chat's place.

**Its head** says its state, title, branches, commits and size, then whose move it is ("Your move. 5 things block the merge. After them, @team has to approve.", "Waiting on checks.", "Ready to merge."). Under it are four status lights, each a click from its section:

- **Checks**;
- **Review** (a code owner waiting says so);
- **Threads**;
- **Branch** (conflicts, behind its base).

**To do** comes next: what blocks the merge, first.

- each failing check (Log shows its log's failing part);
- each review thread not resolved (Reply, Resolve);
- each finding a review bot's comment lists under a heading such as "Must address". This is a guess at the common shapes: a review it can't read shows only in the conversation, and a finding on a thread's lines joins it (one item, two voices).

Each has Send; Send picked or Send all to agent put them in the chat's box as reply cards saying whose they are. Its last line says who's next ("Then waiting on @team: approval required as code owner.").

Under it are three sections, with replies and comments:

- **Activity**: the description, comments and reviews beside their authors' avatars. A review's findings and threads point at To do instead of repeating them, its resolved threads take one line each, and a bot's trailing line of numbers is muted.
- **Checks**: failing first, each opening to its annotations and log, with **Re-run failed** (it asks GitHub to re-run the failed jobs of their workflow runs) and Fix checks; then the passed in two columns, then the skipped.
- **Files**: those with review threads not resolved first, the side-by-side diff with the threads at their lines.

Its text reads in a column of 860 points at most. A bot's comment is one line (its first words, Show), a long review its first lines (Show the whole review), and a table fits the column, its cells wrapping and its empty columns gone.

**Send to agent** on a comment, a thread or a failed check puts it into the chat's box as a reply card (a failed check with the failing part of its log), to send with the rest when you're ready.

### Cleaning up

Once the pull request merged, the widget offers **Clean up…** ([ADR 0063](adr/0063-clean-up-after-a-pull-request.md)). Not now hides the offer; its ⋯ and the chat's ⋯ keep it (the chat's for any worktree chat).

A dialog ticks what loses nothing, and says what each costs:

- deleting the worktree: one with uncommitted files starts unticked and, ticked, turns the button red and names the files;
- deleting the local branch, which waits for its worktree;
- deleting the branch on GitHub;
- archiving the chat.

Mid-turn, it waits for the turn to end, or stops it. The daemon refuses again what the dialog didn't clear: another chat in the worktree, a branch that moved on since the pull request, the default branch.

The widget then shows each part as it goes and what it kept, with Restore branch (on GitHub, at the pull request's head) and Unarchive.

### Elsewhere

- A chat's row in the sidebar gets a red dot while its pull request's checks fail, amber while they run.
- The phone shows the widget's one-line summary in the chat's bar (the number in its state's color, failing or running checks, changes requested or a reviewer waited on, open threads; or Ready, Draft, Merged, Closed), asked each minute while the chat shows. A tap opens it on GitHub. The phone has no Pull request tab.
