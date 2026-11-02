package chats

import (
	"cmp"
	"context"
	"fmt"
	"log/slog"
	"path/filepath"
	"slices"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// A chat's related worktrees (ADR 0081) are the worktrees its subagents
// work in. git says what exists: its list of the chat's repository. The
// chat's tool calls say whose a worktree is. Neither is trusted for more
// than that, as both are the agent's to write (.git/worktrees/*/gitdir
// included): a path counts only if git lists it and it is the top of a work
// tree of the chat's repository, by real path (verified), and nothing
// here adds to what a chat may read (Roots) or runs more of git than
// rev-parse, worktree list, merge-base and rev-list, so no look runs a
// filter or a hook, whoever asks for it.

const (
	// maxRelated is the most worktrees a chat keeps: each costs a run of
	// git at every look, and an agent can list as many as it likes.
	maxRelated = 64
	// relatedEvery is how often a subagent's finished steps bring a look;
	// its end always does.
	relatedEvery = 5 * time.Second
	// relatedTimeout bounds a look the chat starts on its own.
	relatedTimeout = 30 * time.Second
)

// RelatedWorktrees looks at the chat's related worktrees, recording their
// heads, and returns them. A chat with none that has no subagents costs
// no run of git.
func (s *Service) RelatedWorktrees(ctx context.Context, chatID string) ([]model.RelatedWorktree, error) {
	c, err := s.lookup(chatID)
	if err != nil {
		return nil, err
	}
	if c.parent != nil {
		return nil, fmt.Errorf("%q is a side chat", chatID)
	}
	c.lookRelated(ctx)
	c.mu.Lock()
	defer c.mu.Unlock()
	return slices.Clone(c.record.RelatedWorktrees), nil
}

// KnownRelated is the chat's folder and its related worktrees as last
// looked at: no run of git, for what asks often.
func (s *Service) KnownRelated(chatID string) (string, []model.RelatedWorktree, error) {
	c, err := s.lookup(chatID)
	if err != nil {
		return "", nil, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.record.Folder, slices.Clone(c.record.RelatedWorktrees), nil
}

// plainText says a worktree's path and branch are valid UTF-8. git takes
// any bytes for both, so an agent chooses them, and the API's strings
// can't hold what isn't: one such string in an event fails its marshalling,
// which ends the client's Events stream, and in a stored record would do
// so again at each reconnect. They're left out rather than mended, as a
// mended path no longer reads the worktree.
func plainText(path, branch string) bool {
	return utf8.ValidString(path) && utf8.ValidString(branch)
}

// sendable is what of a stored chat's related worktrees can reach a
// client. The log doesn't say the bytes: they are the agent's.
func sendable(chatID string, list []model.RelatedWorktree) []model.RelatedWorktree {
	return slices.DeleteFunc(slices.Clone(list), func(r model.RelatedWorktree) bool {
		if plainText(r.Path, r.Branch) {
			return false
		}
		slog.Warn("dropping a related worktree that isn't valid UTF-8", "chat", chatID)
		return true
	})
}

// ownedWorktrees lists what a look must leave alone for chat id: the
// worktrees chats run in or ran in, the folders of the others, and the
// related worktrees still present of the others. A worktree found in one
// of those is that chat's, not a subagent's here.
func (s *Service) ownedWorktrees(id string) ([]string, error) {
	stored, err := s.sessions.Sessions()
	if err != nil {
		return nil, err
	}
	var owned []string
	for _, sess := range stored {
		if wt := sess.Worktree; wt != nil {
			owned = append(owned, wt.Path)
		}
		for _, wt := range sess.EarlierWorktrees {
			owned = append(owned, wt.Path)
		}
		if sess.ID == id {
			continue
		}
		owned = append(owned, sess.Folder)
		for _, r := range sess.RelatedWorktrees {
			if r.State == model.RelatedPresent {
				owned = append(owned, r.Path)
			}
		}
	}
	return owned, nil
}

// lookRelatedLocked has the chat look at its related worktrees, off the
// chat's lock, unless it is a side chat or replaying: one look at a time,
// and one more if asked during it.
//
//nolint:contextcheck // a look runs on the chat's own life, not a caller's: a subagent's end comes with no request
func (c *chat) lookRelatedLocked() {
	if c.worktrees == nil || c.parent != nil || c.quiet || c.replaying {
		return
	}
	c.relatedAt = time.Now()
	if c.relating {
		c.relateAgain = true
		return
	}
	c.relating = true
	go func() {
		for again := true; again; {
			ctx, cancel := context.WithTimeout(c.ctx, relatedTimeout)
			c.lookRelated(ctx)
			cancel()
			c.mu.Lock()
			again = c.relateAgain
			c.relating, c.relateAgain = again, false
			c.mu.Unlock()
		}
	}()
}

// relatedStepLocked is a subagent's step ending: a look, unless one
// started just now. Its end looks anyway.
func (c *chat) relatedStepLocked() {
	if time.Since(c.relatedAt) >= relatedEvery {
		c.lookRelatedLocked()
	}
}

// relatedStep is what one tool call says about the worktree its subagent
// works in.
type relatedStep struct {
	call  string   // the tool call that started the subagent
	paths []string // the files it worked on
	shell string   // its command, for one that runs one
}

// relatedStepsLocked is what the chat's subagents' tool calls name, in the
// order they came.
func (c *chat) relatedStepsLocked() []relatedStep {
	var steps []relatedStep
	for i := range c.items {
		it := &c.items[i]
		switch {
		case it.Kind != model.ToolCall:
		case it.WorktreePath != "":
			steps = append(steps, relatedStep{call: it.ID, paths: []string{it.WorktreePath}})
		case it.Parent != "":
			st := relatedStep{call: it.Parent, paths: slices.Clone(it.Paths)}
			for _, d := range it.Diffs {
				st.paths = append(st.paths, d.Path)
			}
			if it.ToolKind == "execute" {
				st.shell = strings.ReplaceAll(it.Input, `\n`, " ") // JSON's, between a script's lines
			}
			steps = append(steps, st)
		}
	}
	return steps
}

// lookRelated brings the chat's related worktrees up to date and, when they
// changed, stores them and tells the app. What can't be read leaves them
// as they are: nothing is called removed for an error of git's.
func (c *chat) lookRelated(ctx context.Context) {
	c.looking.Lock()
	defer c.looking.Unlock()
	c.mu.Lock()
	if c.worktrees == nil || c.parent != nil || c.record.Archived || c.halting {
		c.mu.Unlock()
		return
	}
	folder, sid, known := c.record.Folder, c.sid, slices.Clone(c.record.RelatedWorktrees)
	base := ""
	if wt := c.record.Worktree; wt != nil {
		base = wt.Base
	}
	steps := c.relatedStepsLocked()
	c.mu.Unlock()
	if len(known) == 0 && len(steps) == 0 {
		return
	}
	var given map[string]string
	if c.kind.worktreeFinder != nil && sid != "" {
		given = c.kind.worktreeFinder.SubagentWorktrees(sid, folder)
	}
	next, err := c.related(ctx, folder, known, steps, given)
	if err != nil {
		c.log().Debug("looking at related worktrees", "err", err)
		return
	}
	c.markMerged(ctx, folder, base, next)
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.halting || slices.Equal(next, c.record.RelatedWorktrees) {
		return
	}
	c.saveLocked(func(r *model.ChatRecord) { r.RelatedWorktrees = next })
	list := slices.Clone(next)
	c.publish(model.Event{ChatID: c.id, Related: &list})
}

// markMerged says which of list git shows on the chat's branch or base
// (base). A worktree with no commits of its own isn't merged, though its
// head is on the branch: there was nothing to merge. If git can't say,
// they stay as they were.
func (c *chat) markMerged(ctx context.Context, folder, base string, list []model.RelatedWorktree) {
	var tips []string
	for _, k := range list {
		if k.BaseCommit != "" && k.LastHead != k.BaseCommit && git.ObjectID(k.LastHead) {
			tips = append(tips, k.LastHead)
		}
	}
	merged, err := c.worktrees.Merged(ctx, folder, base, tips)
	if err != nil {
		c.log().Debug("looking at what's merged", "err", err)
		return
	}
	for i := range list {
		k := &list[i]
		k.Merged = k.LastHead != k.BaseCommit && slices.Contains(merged, k.LastHead)
	}
}

// relatedLook is one look's view of git.
type relatedLook struct {
	c      *chat
	folder string
	common string                         // the repository's common folder
	head   string                         // the commit folder has out
	listed map[string]model.WorktreeEntry // git's worktrees, by path
}

// related is known brought up to date with git's list of folder's
// repository, and the worktrees found in it for the subagents: steps and
// given (a worktree by the call that started its subagent) say whose.
func (c *chat) related(ctx context.Context, folder string, known []model.RelatedWorktree, steps []relatedStep, given map[string]string) ([]model.RelatedWorktree, error) {
	list, err := c.worktrees.List(ctx, folder)
	if err != nil {
		return nil, err
	}
	common, _, err := c.worktrees.Locate(ctx, folder)
	if err != nil {
		return nil, err
	}
	r := relatedLook{c: c, folder: folder, common: common, listed: map[string]model.WorktreeEntry{}}
	for _, e := range list {
		r.listed[e.Path] = e
		if e.Current {
			r.head = e.Head
		}
	}
	next := slices.Clone(known)
	for i := range next {
		if err := r.refresh(ctx, &next[i]); err != nil {
			return nil, err
		}
	}
	owned, err := c.owned(c.id)
	if err != nil {
		return nil, err
	}
	for _, e := range list {
		if len(next) >= maxRelated {
			break
		}
		if e.Main || e.Current || slices.ContainsFunc(next, func(k model.RelatedWorktree) bool { return k.Path == e.Path }) || isOwned(e.Path, owned) {
			continue
		}
		call := whose(e.Path, folder, steps, given)
		if call == "" {
			continue
		}
		if !plainText(e.Path, e.Branch) {
			c.log().Warn("leaving out a worktree that isn't valid UTF-8", "call", call)
			continue
		}
		if ok, err := r.verified(ctx, e.Path); err != nil {
			return nil, err
		} else if ok {
			next = append(next, r.found(ctx, e, call))
		}
	}
	return next, nil
}

// verified says a path git listed is what it says: the top of a work tree
// of the chat's repository, by real path. Only ctx ending is an error: any
// other answer of git's there says it isn't.
func (r relatedLook) verified(ctx context.Context, path string) (bool, error) {
	common, top, err := r.c.worktrees.Locate(ctx, path)
	if ctxErr := ctx.Err(); ctxErr != nil {
		return false, ctxErr
	}
	return err == nil && common == r.common && top == git.RealPath(path), nil
}

// refresh brings a known worktree up to date: removed unless git lists it
// and it passes, else its branch and head as they are now. A branch
// renamed to what isn't valid UTF-8 doesn't pass.
func (r relatedLook) refresh(ctx context.Context, k *model.RelatedWorktree) error {
	e, ok := r.listed[k.Path]
	ok = ok && plainText(e.Path, e.Branch)
	if ok {
		var err error
		if ok, err = r.verified(ctx, k.Path); err != nil {
			return err
		}
	}
	if !ok {
		k.State = model.RelatedRemoved
		return nil
	}
	k.State, k.Branch = model.RelatedPresent, cmp.Or(e.Branch, k.Branch)
	if git.ObjectID(e.Head) {
		k.LastHead = e.Head
	}
	return nil
}

// found is the record of a worktree seen for the first time.
func (r relatedLook) found(ctx context.Context, e model.WorktreeEntry, call string) model.RelatedWorktree {
	k := model.RelatedWorktree{Path: e.Path, Branch: e.Branch, CallID: call, State: model.RelatedPresent}
	if git.ObjectID(e.Head) {
		k.LastHead = e.Head
		if base, err := r.c.worktrees.MergeBase(ctx, r.folder, e.Head, r.head); err == nil {
			k.BaseCommit = base
		}
	}
	return k
}

// isOwned says path is one of owned, or holds one: a chat that works in a
// folder of the worktree has it.
func isOwned(path string, owned []string) bool {
	path = git.RealPath(path)
	return slices.ContainsFunc(owned, func(o string) bool { return within(git.RealPath(o), path) })
}

// whose is the tool call of the subagent the worktree at path is for, ""
// when none shows: the agent's word first, then the first of the steps to
// name it, in any of the ways a step can.
func whose(path, folder string, steps []relatedStep, given map[string]string) string {
	here := git.RealPath(path)
	var calls []string
	for call, p := range given {
		if git.RealPath(p) == here {
			calls = append(calls, call)
		}
	}
	if len(calls) > 0 {
		slices.Sort(calls) // a forged file can name one worktree twice: the same answer each look
		return calls[0]
	}
	names := spellings(path, folder)
	for _, st := range steps {
		if st.names(names) {
			return st.call
		}
	}
	return ""
}

// spellings are the ways a tool call may name the worktree at path: git's
// path, its real path, the same under the chat's folder as the chat spells
// it, and relative to that folder, as Paths are inside it and as a
// command in it would say it.
func spellings(path, folder string) []string {
	names := []string{path, git.RealPath(path)}
	if rel, err := filepath.Rel(git.RealPath(folder), git.RealPath(path)); err == nil {
		names = append(names, filepath.Join(folder, rel), rel)
	}
	slices.Sort(names)
	return slices.Compact(names)
}

// names says the step names one of the spellings of a worktree: a file
// in it, or a command with it in it.
func (st relatedStep) names(spelled []string) bool {
	return slices.ContainsFunc(spelled, func(name string) bool {
		return mentions(st.shell, name) || slices.ContainsFunc(st.paths, func(p string) bool {
			return p == name || strings.HasPrefix(p, name+"/")
		})
	})
}

// mentions says text has path in it as a whole path: not the end of a
// longer one, nor the start of a name that goes on (a/b in a/bc), though
// a file under it counts.
func mentions(text, path string) bool {
	for at := 0; path != ""; {
		i := strings.Index(text[at:], path)
		if i < 0 {
			return false
		}
		i += at
		if end := i + len(path); startsPath(text, i) && !namePart(text[end:]) {
			return true
		}
		at = i + 1
	}
	return false
}

// startsPath says a path can start at text[i:]: nothing of a name or a
// folder comes before it, but for a "./".
func startsPath(text string, i int) bool {
	before := strings.TrimSuffix(text[:i], "./")
	if before == "" {
		return true
	}
	r, _ := utf8.DecodeLastRuneInString(before)
	return r != '/' && !nameRune(r)
}

// namePart says text goes on with more of a file's name.
func namePart(text string) bool {
	r, n := utf8.DecodeRuneInString(text)
	return n > 0 && nameRune(r)
}

func nameRune(r rune) bool {
	return unicode.IsLetter(r) || unicode.IsDigit(r) || r == '-' || r == '_' || r == '.'
}
