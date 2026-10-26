# 0046. The GitHub view is an inbox the app polls while it shows; a pull request's details poll faster; a chat's status chip once a minute

## Context
The GitHub view should be a place to see what needs the user (reviews asked of them or their teams, their pull requests, issues assigned to them) and to work on a pull request without leaving Nushi. A desktop app gets no webhooks. GitHub's limits are shared with the user's own tools.

## Decision
- **The view is an inbox** in the chat's place, as Jira's (⌘G): three searches in one GraphQL query (about two points), the latest 50 each, by when they changed; on one host at a time; all repositories, or only those of the folders Nushi knows (`repo:` qualifiers, six at most, then filtered). An item's details replace the list (a pull request: header, Conversation, Checks, Files; an issue: its text and comments).
- **Polling follows what shows:** the inbox every minute while the view shows; a pull request's details every 30 s while open; a chat's status chip (its pull request's or issue's state, checks, review, threads not resolved) every minute while the chat shows, one query a host for the states asked (by node id). The daemon keeps answers 20 s (the inbox) and 30 s (states), so two windows ask once, and feeds the states from the inbox. Every poll is quiet: held back while its bucket is low, and a failure keeps what shows, saying when it's from. Nothing polls when nothing shows.
- **Files are read once a head:** a comparison of two commits and files' texts at a commit don't change, so the daemon keeps them (32 MB of texts) and asks again only for a new head. A failed job's log is read when its check is opened, and kept.
- **No notifications API, no background sync:** the inbox is what the user looks at; notifications as a source are a later idea.

## Consequences
- With the view, a pull request and a chat open, Nushi spends at most about 3 GraphQL points a minute on polls (the inbox about 2, a pull request about 2 every 30 s, states 1), under 400 an hour of the 5,000; REST only when a log or files are opened.
- What happens on GitHub shows within a minute (30 s for an open pull request), not at once.
- A closed view costs nothing.
