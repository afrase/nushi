package model

// Worktree is a git worktree of a repository, on a branch of its own.
type Worktree struct {
	Repo   string // the repository's folder (its main worktree)
	Path   string // the worktree's folder
	Branch string // its branch, made for it
	Base   string // the branch it started from (a commit, if HEAD was detached)
	// BaseCommit is the commit it started from; empty for worktrees made
	// before Nushi kept it.
	BaseCommit string `json:",omitempty"`
	// AutoName says Branch is the name Nushi made up for it (nushi/<two
	// words>), to be named after the chat once it has a title; off once it
	// is, or when the user renamed it or it couldn't be.
	AutoName bool `json:",omitempty"`
	// Told is the branch's name as the agent last had it: Branch when its
	// session started there (Claude's system prompt takes git's status
	// then) or the chat's last prompt went. A rename since is told with
	// the next prompt. Empty for worktrees made before Nushi kept it.
	Told string `json:",omitempty"`
	// Found says the worktree was there already (made outside Nushi, or
	// for another chat) when the chat moved or started in it: Nushi never
	// removes it or deletes its branch, and doesn't name it after the chat.
	Found bool `json:",omitempty"`
}

// RelatedWorktree is a worktree of the chat's repository that one of its
// subagents worked in. It stays after the worktree goes, as what was last
// seen of it. Path and Branch are as git lists them, which an agent can
// write: they are data.
type RelatedWorktree struct {
	Path, Branch string
	// BaseCommit is where it left the chat's branch, as first seen; ""
	// when they share no history.
	BaseCommit string `json:",omitempty"`
	// LastHead is its commit the last time Nushi looked: what is left to
	// diff once the worktree and its branch are gone, while git keeps the
	// commit.
	LastHead string `json:",omitempty"`
	// CallID is the tool call that started the subagent.
	CallID string
	State  RelatedState
	// Merged says git shows LastHead on the chat's branch or its base, and
	// it has commits of its own. git can't see a squash merge.
	Merged bool `json:",omitempty"`
}

// RelatedState says whether a related worktree is still there.
type RelatedState string

// A related worktree is present while git lists it for the chat's
// repository, and removed otherwise.
const (
	RelatedPresent RelatedState = "present"
	RelatedRemoved RelatedState = "removed"
)

// WorktreeEntry is one of a repository's worktrees, as git lists them.
type WorktreeEntry struct {
	Path   string // its folder
	Branch string // its branch; "" when HEAD is detached
	Head   string // its HEAD commit
	Main   bool   // the repository's own folder (its main worktree)
	Locked bool   // git worktree lock: kept from pruning and removal
	// Current says the folder asked about is in it.
	Current bool
}

// Branch is one of a repository's local branches.
type Branch struct {
	Name string
	Time int64 // its last commit's time (Unix seconds)
	// Worktree is the folder of the worktree that has it checked out, if
	// one does.
	Worktree string
}

// BranchUse is who else has a worktree's branch, for renaming it.
type BranchUse struct {
	OnIt      bool // the worktree has it checked out
	Elsewhere bool // another worktree has it checked out
	Upstream  bool // it tracks a remote's branch
	Pushed    bool // a remote has a branch of its name
}

// WorktreeState is what removing a worktree and deleting its branch would
// lose.
type WorktreeState struct {
	Gone       bool // its folder was removed outside Nushi
	Changed    int  // files with uncommitted changes, untracked ones included
	Ignored    int  // files and folders git ignores, which removing it deletes too
	Commits    int  // commits on its branch that its base doesn't have
	BranchGone bool // its branch was deleted outside Nushi
}

// FileChange is one file's uncommitted change: its text at HEAD and now.
// Status is "added", "modified", "deleted", "renamed" (from OldPath) or
// "untracked". Skipped says why the texts are left out ("binary", "too
// large"), if they are. Added and Removed count its lines.
type FileChange struct {
	Path, OldPath, Status, Old, New, Skipped string
	Added, Removed                           int
	// Staged is how much of an uncommitted change is in the index: "", or
	// StagedPart or StagedAll.
	Staged string
}

// FileChange.Staged's values.
const (
	StagedPart = "part" // staged, and changed again or staged in part since
	StagedAll  = "all"
)

// FolderStatus sums up a git folder's uncommitted changes. Branch is the
// branch checked out, or the commit when none is.
type FolderStatus struct {
	Branch                string
	Files, Added, Removed int
}
