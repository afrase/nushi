package model

import (
	"fmt"
	"strings"
	"time"
)

// GitHubRef names a pull request or an issue: its host (github.com or an
// Enterprise server), its repository (owner/name) and its number.
type GitHubRef struct {
	Host   string `json:"host"`
	Repo   string `json:"repo"`
	Number int    `json:"number"`
}

// GitHubItem is a pull request or an issue as a list shows it.
type GitHubItem struct {
	GitHubRef
	ID      string // GitHub's node id
	Pull    bool
	Title   string
	URL     string
	State   string // "open", "closed" or "merged"
	Draft   bool
	Author  string
	Updated time.Time
	// A pull request's checks ("success", "failure", "pending", or "" for
	// none), its review decision ("approved", "changes_requested",
	// "review_required" or ""), and its review threads not resolved.
	Checks, Review string
	Unresolved     int
	Comments       int
	// What GetGitHubItems adds (ADR 0117; the inbox leaves them unset): a
	// pull request's size, its checks counted, its merge state ("clean",
	// "blocked", …, as GitHubPull's), its base and head branches; an
	// issue's close reason ("completed", "not_planned" or "").
	Additions, Deletions, ChangedFiles int
	Created                            time.Time
	CheckCounts                        CheckCounts
	MergeState, StateReason            string
	Base, Head                         string
}

// CheckCounts are a pull request's checks by state, at its head: a
// neutral one counts as passed; skipped ones count in neither side of
// passed/total.
type CheckCounts struct {
	Passed, Failed, Running, Skipped int
}

// GitHubComment is a comment, or a review with what it said. Body is
// Markdown made safe to show (see githubapi.Markdown). Association is
// GitHub's author association ("OWNER", "MEMBER", "COLLABORATOR",
// "CONTRIBUTOR", "NONE", …).
type GitHubComment struct {
	ID, Author, Association, Body, URL string
	Bot                                bool
	Created                            time.Time
	// Review is a review's state ("approved", "changes_requested",
	// "commented", "dismissed"); "" for a comment.
	Review string
	// Commit is the head commit a review was made on (its oid); "" for a
	// comment.
	Commit string
}

// GitHubThread is a review thread on a pull request's diff: on Line (from
// StartLine) of Path's Side ("left", the base, or "right", the head), or
// on the file. An outdated thread's lines are the original ones.
type GitHubThread struct {
	ID, Path                                         string
	Side                                             string
	Line, StartLine, OriginalLine, OriginalStartLine int
	OnFile, Outdated, Resolved                       bool
	CanReply, CanResolve, CanUnresolve               bool
	Comments                                         []GitHubComment
}

// GitHubCheck is a check run (ID is its id, an Actions job's) or a commit
// status (ID 0). State is the conclusion once it ended ("success",
// "failure", "cancelled", "skipped", "neutral", "timed_out",
// "action_required", "startup_failure", "stale"), else "pending".
type GitHubCheck struct {
	ID                              int64
	Name, Workflow, App, State, URL string
	Title, Summary                  string
	Required                        bool
	Annotations                     []GitHubAnnotation
	Started, Completed              time.Time
}

// GitHubAnnotation is a check run's note on a file's lines.
type GitHubAnnotation struct {
	Path, Level, Title, Message string
	Line                        int
}

// GitHubReviewer is a reviewer of a pull request: asked to review (State
// "requested") or one who did ("approved", "changes_requested",
// "commented", "dismissed"). A team asked has Team set.
type GitHubReviewer struct {
	Login, State string
	Team         bool
	CodeOwner    bool // asked as a code owner of what the pull request changes
}

// GitHubPull is a pull request whole.
type GitHubPull struct {
	GitHubItem
	Body, Association string
	Base, Head        string // branches
	// HeadRepo is the head's repository (owner/name): another one than
	// Repo for a fork's pull request (CrossRepo).
	HeadRepo                           string
	CrossRepo                          bool
	BaseOID, HeadOID                   string
	Mergeable                          string // "mergeable", "conflicting" or "unknown"
	MergeState                         string // "clean", "blocked", "behind", "dirty", "unstable", "has_hooks", "unknown"
	Additions, Deletions, ChangedFiles int
	Commits                            int
	Reviewers                          []GitHubReviewer
	// Conversation is the comments and the reviews that said something,
	// oldest first (the latest 100 comments).
	Conversation []GitHubComment
	Threads      []GitHubThread
	Runs         []GitHubCheck
	// PendingReview is the id of the user's own review not yet submitted
	// on GitHub (one made in the browser), with its comments' count.
	PendingReview   string
	PendingComments int
	Merge           GitHubMerge
}

// GitHubMerge is what merging a pull request may do, as GitHub says for
// the viewer (ADR 0069).
type GitHubMerge struct {
	// Methods are the repository's, of "merge", "squash" and "rebase",
	// without what the base's rules forbid.
	Methods []string
	// Default is the method the viewer used last, or the repository's.
	Default string
	// Can says the viewer may merge here: write access or better.
	Can bool
	// Bypass says GitHub would let the viewer past the base's rules. Nushi
	// never offers that; it only trusts a clean state less (MergeBlocks).
	Bypass    bool
	CanRebase bool
	// AutoAllowed says the repository allows auto-merge.
	AutoAllowed                   bool
	CanEnableAuto, CanDisableAuto bool
	Auto                          *GitHubAutoMerge
	// Queue says the base branch has a merge queue, QueueMethod the method
	// it merges with ("" when GitHub doesn't say).
	Queue       bool
	QueueMethod string
	Entry       *GitHubQueueEntry
	// DeleteBranch says the repository deletes a merged head branch itself.
	DeleteBranch bool
	// Conversations says the base requires review threads resolved.
	Conversations bool
}

// GitHubAutoMerge is auto-merge turned on: by whom, with which method.
type GitHubAutoMerge struct {
	By     string
	Method string
}

// GitHubQueueEntry is a pull request's place in its base's merge queue;
// State is "queued", "awaiting_checks", "mergeable", "unmergeable" or
// "locked". Eta is GitHub's estimate of the wait in seconds, 0 for none.
type GitHubQueueEntry struct {
	Position int
	State    string
	By       string
	Eta      int
}

// GitHubIssue is an issue whole.
type GitHubIssue struct {
	GitHubItem
	Body, Association string
	Labels, Assignees []string
	Conversation      []GitHubComment
}

// ChatGitHub is the pull request or issue a chat was started from, or
// one of its pull requests (ID is its node id; "" for one the chat opened,
// known by its address alone). Branch is the head branch a pull request
// was found by; empty when it was linked by hand, opened in the chat, or
// the chat started from it. Opened says a tool call of the chat opened it
// (ADR 0117): it stays when the branch changes.
type ChatGitHub struct {
	GitHubRef
	Pull   bool   `json:"pull,omitempty"`
	ID     string `json:"id"`
	Branch string `json:"branch,omitempty"`
	Opened bool   `json:"opened,omitempty"`
}

// Key is the link's item as host/owner/repo#number, what a link opened in
// the chat is told apart by until its node id is known.
func (g ChatGitHub) Key() string {
	return fmt.Sprintf("%s/%s#%d", g.Host, strings.ToLower(g.Repo), g.Number)
}

// Same says two links are the same item: by node id when both have one,
// else by host, repository and number.
func (g ChatGitHub) Same(o ChatGitHub) bool {
	if g.ID != "" && o.ID != "" {
		return g.ID == o.ID
	}
	return g.Key() == o.Key()
}
