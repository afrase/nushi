package chats

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"io/fs"
	"slices"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// Switched is what SwitchBranch did, or the refusal the user can act on:
// the branch is checked out in another worktree (open that instead), the
// folder has uncommitted changes, or other chats work in the same folder
// and the switch would move them too (asked once).
type Switched struct {
	Switched bool
	Worktree string   // the worktree that has the branch checked out
	Changed  int      // the folder's uncommitted changes to tracked files
	Others   []string // the other chats' titles, for the user to confirm
}

// SwitchBranch checks out branch in a chat's folder (git switch), or a new
// branch from HEAD with create, as the user asked from the Environment
// widget. Refused for a worktree chat (it moves to another worktree instead)
// and while this chat or another in the same checkout works; returned
// without switching when the branch is another worktree's, the folder has
// uncommitted changes (not for a new branch: they go along), or, unless
// withOthers, other chats work there. Every chat in the checkout gets the
// line and is told with its next prompt.
func (s *Service) SwitchBranch(ctx context.Context, chatID, branch string, create, withOthers bool) (Switched, error) {
	var none Switched
	c, err := s.stored(chatID)
	if err != nil {
		return none, err
	}
	c.mu.Lock()
	folder, wt := c.record.Folder, c.record.Worktree
	switch err = c.closedLocked(); {
	case err != nil:
	case wt != nil:
		err = errors.New("this chat works in a worktree: move it to the worktree of another branch instead")
	case s.worktrees == nil:
		err = errors.New("no git")
	}
	c.mu.Unlock()
	if err != nil {
		return none, err
	}
	// From here to its end no turn starts in the folder: git switches it
	// under the agent (holdFolder), and the agent is told with the next
	// prompt, which must come after.
	release, err := holdFolder(switching, mustBeQuiet("the agent is working: switch the branch once it's done"), c)
	if err != nil {
		return none, err
	}
	defer release()
	list, err := s.worktrees.List(ctx, folder)
	if err != nil {
		return none, errors.New("the chat's folder isn't in a git repository")
	}
	from := s.worktrees.Branch(ctx, folder)
	if !create {
		if branch == from {
			return Switched{Switched: true}, nil
		}
		if i := slices.IndexFunc(list, func(e model.WorktreeEntry) bool { return e.Branch == branch && !e.Current }); i >= 0 {
			return Switched{Worktree: list[i].Path}, nil
		}
		if n, err := s.worktrees.Changed(ctx, folder); err != nil || n > 0 {
			return Switched{Changed: n}, err
		}
	}
	others, titles, letGo, err := s.inCheckout(c, list, folder)
	defer letGo()
	if err != nil || len(titles) > 0 && !withOthers {
		return Switched{Others: titles}, err
	}
	if err := s.worktrees.Switch(ctx, folder, branch, create); errors.Is(err, fs.ErrNotExist) {
		return none, fmt.Errorf("there's no branch %s any more", branch)
	} else if errors.Is(err, fs.ErrExist) {
		return none, fmt.Errorf("a branch named %s is there already", branch)
	} else if err != nil {
		return none, err
	}
	c.log().Info("branch switched", "chats", len(others)+1, "new", create) // not the names: often the chat's subject
	for _, o := range append(others, c) {
		o.mu.Lock()
		o.switchedLocked(from, branch)
		o.mu.Unlock()
	}
	return Switched{Switched: true}, nil
}

// switching is what a branch switch does to a chat's folder (holdFolder).
const switching = "branch is being switched"

// inCheckout returns the chats besides c whose folders are in folder's
// checkout (the same worktree, not one inside it) and the titles of
// those not archived, for the user to confirm; an error names one that
// works now. Each is held for the switch (holdFolder) until letGo.
func (s *Service) inCheckout(c *chat, list []model.WorktreeEntry, folder string) (others []*chat, titles []string, letGo func(), err error) {
	var releases []func()
	letGo = func() {
		for _, release := range releases {
			release()
		}
	}
	stored, err := s.sessions.Sessions()
	if err != nil {
		return nil, nil, letGo, err
	}
	for _, sess := range stored {
		if sess.ID == c.id || sess.Worktree != nil || !git.Same(list, folder, sess.Folder) {
			continue
		}
		o, err := s.lookup(sess.ID)
		if err != nil {
			return nil, nil, letGo, err
		}
		var title string
		release, err := holdFolder(switching, func(o *chat) error {
			if title = cmp.Or(o.record.Name, o.record.Title, "a chat without a title"); !o.quietLocked() {
				return fmt.Errorf("“%s” is working in this folder: switch the branch once it's done", title)
			}
			return nil
		}, o)
		if err != nil {
			return nil, nil, letGo, err
		}
		releases = append(releases, release)
		others = append(others, o)
		if !sess.Archived {
			titles = append(titles, title)
		}
	}
	return others, titles, letGo, nil
}

// holdFolder holds chats' folder for a git step that changes it (why: what
// it does, as closedLocked says it): from check (under each chat's lock)
// until release, none takes a prompt, reopens or lets go. A chat held
// already, or that check refuses, leaves none held and is the error.
func holdFolder(why string, check func(*chat) error, chats ...*chat) (release func(), err error) {
	var held []*chat
	release = func() {
		for _, c := range held {
			c.mu.Lock()
			c.folder = ""
			c.mu.Unlock()
		}
	}
	for _, c := range chats {
		c.mu.Lock()
		if c.folder != "" {
			err = errors.New("the chat's " + c.folder)
		} else if err = check(c); err == nil {
			c.folder = why
			held = append(held, c)
		}
		c.mu.Unlock()
		if err != nil {
			release()
			return func() {}, err
		}
	}
	return release, nil
}

// mustBeQuiet is a holdFolder check that refuses, saying working, a chat whose
// agent isn't quiet (quietLocked).
func mustBeQuiet(working string) func(*chat) error {
	return func(c *chat) error {
		if !c.quietLocked() {
			return errors.New(working)
		}
		return nil
	}
}

// switchedLocked records that the chat's folder went from branch from to
// to: its transcript's line, and the agent told with the next prompt
// (from the branch it last had, which several switches keep).
func (c *chat) switchedLocked(from, to string) {
	c.saveLocked(func(s *model.ChatRecord) { s.BranchFrom = cmp.Or(s.BranchFrom, from) })
	c.noticeLocked(model.NoticeBranchSwitched, "Switched to branch "+to)
	c.copyLocked(false)
}

// place returns the note for the prompt, if the chat moved or its
// folder's branch was switched since the agent's last prompt (nil
// otherwise), the move's and switches' lines it told of, and whether
// there's a move or switch to clear once the prompt went.
//
//nolint:contextcheck // a turn starts on its own, after the request that queued its message
func (n *notes) place() (*acp.ContentBlock, []string, bool) {
	sess := n.sess
	if !sess.Moved && sess.BranchFrom == "" {
		return nil, nil, false
	}
	if n.git == nil {
		return nil, nil, true
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	branch := n.git.Branch(ctx, sess.Folder)
	for _, name := range []string{branch, sess.BranchFrom} {
		if err := n.git.CheckBranch(ctx, sess.Folder, name); name != "" && err != nil {
			n.log.Warn("the agent isn't told of its folder's branch", "err", err)
			return nil, nil, true // dropped: the next prompt doesn't try again
		}
	}
	var text string
	switch {
	case sess.Moved && (sess.Folder == "" || strings.ContainsAny(sess.Folder, "\r\n")): // a line break would split the note; the rest is escaped in it
		n.log.Warn("the agent isn't told where the chat moved: a folder name it can't be told")
		return nil, nil, true
	case sess.Moved:
		text = moveNote(sess.Folder, branch)
	case branch == "" || branch == sess.BranchFrom:
		return nil, nil, true // detached since, or back on the branch it had
	default:
		text = switchNote(sess.BranchFrom, branch)
	}
	return &acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: text}}, n.switched, true
}

// placedLocked records that a prompt went with place's note, if any:
// nothing's pending, and its lines, notices, are marked as told. No
// switch or move comes between the note and this: both wait for the
// turn's end.
func (c *chat) placedLocked(notices []string) {
	c.saveLocked(func(s *model.ChatRecord) { s.Moved, s.BranchFrom = false, "" })
	c.markToldLocked(notices)
	if len(notices) > 0 {
		c.copyLocked(false)
	}
}
