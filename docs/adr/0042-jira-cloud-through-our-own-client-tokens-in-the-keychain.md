# 0042. Jira Cloud through a client of Nushi's own, API tokens in the keychain

## Context
Jira is the first integration with a UI of its own in Nushi: lists, an issue view, chats started from an issue. Jira Cloud's OAuth (3LO) needs a client secret a desktop app can't keep, and every 3LO app shares one rate-limit pool across all its users; API tokens (email and token, Basic auth) don't, and expire within a year. A classic token works against the site; a scoped one only through Atlassian's gateway, `api.atlassian.com/ex/jira/<cloud id>` (the cloud id from the site's `/_edge/tenant_info`). Rich text in v3 is ADF, a JSON tree, and no Go package converts it well. Go SDKs exist (`go-atlassian`, `go-jira`), large and unsure about `/search/jql`. Data Center is v2 with wiki markup and personal access tokens, and ends in 2029.

## Decision
- The daemon owns Jira; the app only asks it. A thin client of the endpoints Nushi uses, `internal/jiracloud` (myself, `/search/jql` with `nextPageToken`, boards and the active sprint, JQL autocompletion, an issue whole, comments, transitions, attachments, remote links), behind the `Client` interface `internal/features/jira` declares, so a Data Center client can slot in beside it. Text crosses that interface as Markdown; `internal/adf` converts both ways (goldmark parses Markdown).
- API tokens only. Connecting tries the token as classic on the site, then as scoped through the gateway; `/myself` says who it is. Several sites, one token each; the site's host is its id.
- The token lives in the login keychain, written and read by the daemon through the Security framework (`internal/keychain`, cgo): never in a file, a log, an agent's environment or a command line. Its item is the daemon's: a new build of Nushi (ad-hoc signed, so a new program to macOS) reads it only after the user's OK in macOS's prompt, which Nushi asks for only when the user presses Allow; otherwise it never prompts, and says the token needs an OK. A daemon on another data folder (`NUSHI_DATA`) uses the service "Nushi Jira (test)", the real one "Nushi Jira".
- Nothing reaches Jira unless the user (or, through its tools, a chat's agent: ADR 0043) asks: the app asks for lists and the open issue while the Jira view shows (each minute, and on Refresh); nothing polls or writes in the background. 429 and 503 are retried after `Retry-After` (with Atlassian's jitter) twice, at most 20 s each.
- A token's expiry is warned about when the user gave its date: Jira's API doesn't say it.
- The log has each request's method, path template, status and time (ADR 0038); never a token, a query, an issue's text or a comment.

## Consequences
- After each `make install` (a new build), the Jira view and Settings say the keychain wants an OK; Allow shows macOS's prompt once ("Always Allow").
- Another program of the user's, an agent included, can't read the token without that prompt; it can still delete the item (`security delete-generic-password` asks nothing), which costs the user a token to paste again.
- Images in an issue come from its attachments, fetched by the daemon with the token; a URL in an issue's text is never fetched.
- Data Center, OAuth (or Rovo MCP's public-client OAuth) and webhooks are later adapters, not in the code.

## Alternatives considered
- `go-atlassian` or `go-jira`: much more than Nushi uses, and the search endpoint Jira moved to is new in them; the client is about 830 lines.
- `zalando/go-keyring` (jira-cli's): it runs `/usr/bin/security`, so the item is the `security` tool's, and any process of the user's could read the token without a prompt.
- `security add-generic-password -w <token>`: the token on a command line, where `ps` shows it.
- The data protection keychain: it needs an entitlement and a team id that an ad-hoc signed app doesn't have.
