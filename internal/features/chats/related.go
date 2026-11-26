package chats

import (
	"cmp"
	"context"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
)

// A chat's related worktrees (ADR 0081) are the worktrees its subagents
// work in, and its workflows' subagents (related_workflow.go). git says what exists: its list of the chat's repository. The
// chat's tool calls say whose a worktree is. Neither is trusted for more
// than that, as both are the agent's to write (.git/worktrees/*/gitdir
// included): a path counts only if git lists it and it is the top of a work
// tree of the chat's repository, by real path (verified), and nothing
// here adds to what a chat may read (Roots) or runs more of git than
// rev-parse, worktree list, merge-base and rev-list, so no look runs a
// filter or a hook, whoever asks for it.

const (
	// maxRelated is the most worktrees a chat keeps of its subagents', and
	// the most of its workflows' (counted): each costs a run of git at
	// every look, and an agent can list as many as it likes. Each kind has
	// its own, so a big run can't keep a subagent's worktree out, nor the
	// other way round.
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
	c, err := s.find(chatID) // its steps are read from the copy while its items are let go
	if err != nil {
		return nil, err
	}
	if c.parent != nil {
		return nil, fmt.Errorf("%q is a side chat", chatID)
	}
	c.lookRelated(ctx)
	c.mu.Lock()
	defer c.mu.Unlock()
	return visible(c.record.RelatedWorktrees), nil
}

// presentRelatedLocked is the paths of the chat's related worktrees still
// there, as last looked at.
func (c *chat) presentRelatedLocked() []string {
	var paths []string
	for _, k := range c.record.RelatedWorktrees {
		if k.State == model.RelatedPresent {
			paths = append(paths, k.Path)
		}
	}
	return paths
}

// KnownRelated is the chat's folder and its related worktrees as last
// looked at, as the app is sent them (visible): no run of git, for what asks
// often.
func (s *Service) KnownRelated(chatID string) (string, []model.RelatedWorktree, error) {
	c, err := s.find(chatID)
	if err != nil {
		return "", nil, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.record.Folder, visible(c.record.RelatedWorktrees), nil
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
	if c.worktrees == nil || c.parent != nil || c.muted || c.replaying {
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
			ctx, cancel := context.WithTimeout(c.svc.ctx, relatedTimeout)
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

// workflowLookLocked is a workflow's read bringing a claim that could make
// a record (fresh), or following one the limiter dropped: a look, unless
// one started just now, and then one is owed, asked for again at the
// follower's next read (it reads about once a second), so a claim isn't
// lost when its run goes quiet. A look that reads the chat's calls pays it.
func (c *chat) workflowLookLocked(fresh bool) {
	if !fresh && !c.relatedOwed {
		return
	}
	if time.Since(c.relatedAt) < relatedEvery {
		c.relatedOwed = true
		return
	}
	c.lookRelatedLocked()
}

// relatedStep is what one tool call says about the worktree its subagent
// works in.
type relatedStep struct {
	id      string   // its item's: where it is in the chat's order
	call    string   // the tool call that started the subagent
	paths   []string // the files it worked on
	shell   string   // its command, for one that runs one
	running bool     // it ran (or waited for a permission) when read: its status says so and its end isn't stamped
	ended   int64    // when it ended (Unix nanoseconds), 0 if not stamped
}

// runningAt says the step hadn't ended at the look that read the chat's
// steps at (Unix nanoseconds): it still runs, or it ended after. A step
// whose end wasn't stamped (a replayed one) ended before; at 0 (a point
// kept before this was) says none did.
func (st relatedStep) runningAt(at int64) bool {
	return st.running || at != 0 && st.ended > at
}

// relatedCallsLocked is what the chat's subagents' tool calls name, in the
// order they came, and what its workflows claim; of a chat whose items
// were let go, only the subagents' calls are read from the copy, picked
// from its heads (which opening it read), and the workflows' claims come
// from the heads, which carry them.
func (c *chat) relatedCallsLocked() ([]relatedStep, []workflowClaim) {
	if !c.inCopy {
		return relatedSteps(c.items), workflowClaims(c.items, c.record.Folder)
	}
	heads, err := c.headsLocked()
	if err != nil {
		c.logLocked().Warn("transcript copy not read", "err", err)
		return nil, nil
	}
	claims := workflowClaims(heads, c.record.Folder)
	calls, err := c.wholeLocked(slices.DeleteFunc(heads, func(it model.Item) bool {
		return it.Kind != model.ToolCall || it.WorktreePath == "" && it.Parent == ""
	}))
	if err != nil {
		c.logLocked().Warn("transcript copy not read", "err", err)
	}
	return relatedSteps(calls), claims
}

// relatedSteps is what the subagents' tool calls among items name.
func relatedSteps(items []model.Item) []relatedStep {
	var steps []relatedStep
	for i := range items {
		it := &items[i]
		switch {
		case it.Kind != model.ToolCall:
		case it.WorktreePath != "":
			steps = append(steps, relatedStep{id: it.ID, call: it.ID, paths: []string{it.WorktreePath}, running: callRuns(it), ended: endedAt(it)})
		case it.Parent != "":
			st := relatedStep{id: it.ID, call: it.Parent, paths: slices.Clone(it.Paths), running: callRuns(it), ended: endedAt(it)}
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

// callRuns says the tool call it runs: its status says so, and its end
// isn't stamped. A call its turn's end left running (endCallsLocked: its
// end stamped, the agent's status kept) is over, or it would count as
// running for as long as the agent lives.
func callRuns(it *model.Item) bool {
	return callRunning(it.Status) && it.Ended.IsZero()
}

// endedAt is when the tool call it ended, in Unix nanoseconds; 0 if it
// hasn't, or its end wasn't stamped.
func endedAt(it *model.Item) int64 {
	if it.Ended.IsZero() {
		return 0
	}
	return it.Ended.UnixNano()
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
	since := c.record.Since
	if since.IsZero() {
		since = c.record.Created
	}
	base := ""
	if wt := c.record.Worktree; wt != nil {
		base = wt.Base
	}
	steps, claims := c.relatedCallsLocked()
	readNano := time.Now().UnixNano()
	c.relatedOwed = false
	if c.rewound {
		known = c.rewoundPointsLocked(steps)
	}
	c.mu.Unlock()
	if len(known) == 0 && len(steps) == 0 && !c.gate.couldCount(claims, folder) {
		return
	}
	var given map[string]string
	if c.kind.worktreeFinder != nil && sid != "" {
		given = c.kind.worktreeFinder.SubagentWorktrees(sid, folder)
	}
	next, err := c.related(ctx, folder, known, relatedRead{steps, claims, readNano}, given)
	if err != nil {
		c.log().Debug("looking at related worktrees", "err", err)
		return
	}
	c.markMerged(ctx, folder, base, next)
	c.askPulls(ctx, folder, since, next)
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.halting || slices.Equal(next, c.record.RelatedWorktrees) {
		return
	}
	was := visible(c.record.RelatedWorktrees)
	c.saveLocked(func(r *model.ChatRecord) { r.RelatedWorktrees = next })
	if list := visible(next); !slices.Equal(list, was) {
		c.publish(model.Event{ChatID: c.id, Related: &list})
	}
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

const (
	// maxPullAsks is the most worktrees one look asks GitHub about: records
	// kept from before it asked are asked over the next looks, not at once.
	maxPullAsks = 8
	// pullsBackoff is how long looks leave GitHub alone after it failed
	// (no network, a rate limit), rather than ask at every look.
	pullsBackoff = 5 * time.Minute
	// pullsOpenFirst is how long a worktree whose pull request is open
	// waits before it's asked again; each wait after is twice the last, up
	// to pullsOpenMax. A pull request can wait days for review, and looks
	// come every few seconds while subagents work: asking at each would use
	// up the sign-in's hourly limit, which the chats' pull request cards
	// share.
	pullsOpenFirst = 5 * time.Minute
	pullsOpenMax   = time.Hour
)

// pullOpen is a related worktree whose pull request GitHub said was open:
// when it may be asked again, and how long it waited last.
type pullOpen struct {
	next time.Time
	wait time.Duration
}

// pullKey is k's in pullsOpen: its path, branch and last head, as a path
// made again is another record (issue #118), on another branch or on the
// same one redone, and each waits on its own.
func pullKey(k *model.RelatedWorktree) string {
	return k.Path + "\x00" + k.Branch + "\x00" + k.LastHead
}

// askPulls asks GitHub whether the worktrees of list that went away with
// commits of their own that git doesn't show merged had their branch
// merged by a pull request opened since the chat began (a squash merge;
// issue 83). The answer is kept, but for a pull request still open, which
// is asked again once its wait ([pullOpen]) is over, after those not yet
// asked and those waiting longest first: open ones can't take every ask,
// nor some of them every turn. One GitHub couldn't give is asked again at
// a later look, after [pullsBackoff]. Without GitHub nothing is asked. It
// runs under c.looking.
func (c *chat) askPulls(ctx context.Context, folder string, since time.Time, list []model.RelatedWorktree) {
	now := time.Now()
	if c.svc.gitHub == nil || now.Before(c.pullsAfter) {
		return
	}
	var ask, open []*model.RelatedWorktree
	for i := range list {
		k := &list[i]
		o, waits := c.pullsOpen[pullKey(k)]
		switch {
		case k.State != model.RelatedRemoved || k.Merged || k.PullAsked || k.Branch == "" || k.BaseCommit == "" || k.LastHead == k.BaseCommit:
		case !waits:
			ask = append(ask, k)
		case !now.Before(o.next):
			open = append(open, k)
		}
	}
	slices.SortStableFunc(open, func(a, b *model.RelatedWorktree) int {
		return c.pullsOpen[pullKey(a)].next.Compare(c.pullsOpen[pullKey(b)].next)
	})
	if c.pullsOpen == nil {
		c.pullsOpen = map[string]pullOpen{}
	}
	ask = append(ask, open...)
	answered := map[string]string{} // by branch: records of one branch are asked about once a look
	for _, k := range ask[:min(maxPullAsks, len(ask))] {
		state, ok := answered[k.Branch]
		if !ok {
			var err error
			if state, err = c.svc.gitHub.BranchPull(ctx, folder, k.Branch, since); err != nil {
				c.log().Debug("asking GitHub about a related worktree's branch", "err", err)
				c.pullsAfter = time.Now().Add(pullsBackoff)
				return
			}
			answered[k.Branch] = state
		}
		if state == "open" {
			o := c.pullsOpen[pullKey(k)]
			o.wait = min(max(2*o.wait, pullsOpenFirst), pullsOpenMax)
			o.next = now.Add(o.wait)
			c.pullsOpen[pullKey(k)] = o
			continue
		}
		delete(c.pullsOpen, pullKey(k))
		k.PullAsked, k.PullMerged = true, state == "merged"
	}
}

// relatedLook is one look's view of git.
type relatedLook struct {
	c      *chat
	folder string
	common string                         // the repository's common folder
	head   string                         // the commit folder has out
	tips   []string                       // the default branch's commits (DefaultTips)
	moved  bool                           // tips aren't the last look's
	listed map[string]model.WorktreeEntry // git's worktrees, by path
	last   string                         // the last step's id: a record removed now went before what comes after
	at     int64                          // when this look read the steps: one still running then counts as after last
	before string                         // the last look's last: one made again unseen went after it
	since  int64                          // the last look's at
}

// relatedRead is the chat's steps and its workflows' claims as a look
// read them, and when.
type relatedRead struct {
	steps  []relatedStep
	claims []workflowClaim
	at     int64
}

// related is known brought up to date with git's list of folder's
// repository, and the worktrees found in it for the subagents: steps and
// given (a worktree by the call that started its subagent) say whose.
func (c *chat) related(ctx context.Context, folder string, known []model.RelatedWorktree, read relatedRead, given map[string]string) ([]model.RelatedWorktree, error) {
	steps := read.steps
	list, err := c.worktrees.List(ctx, folder)
	if err != nil {
		return nil, err
	}
	common, _, err := c.worktrees.Locate(ctx, folder)
	if err != nil {
		return nil, err
	}
	c.gate.setCommon(common, folder)
	c.gate.setListed(list)
	r := relatedLook{c: c, folder: folder, common: common, tips: c.worktrees.DefaultTips(ctx, folder), listed: map[string]model.WorktreeEntry{}}
	r.before, r.last, r.since, r.at = c.lookedStep, c.lookedStep, c.lookedAt, read.at
	if len(steps) > 0 {
		r.last = steps[len(steps)-1].id
	}
	r.moved = !slices.Equal(r.tips, c.lookedTips)
	for _, e := range list {
		r.listed[e.Path] = e
		if e.Current {
			r.head = e.Head
		}
	}
	next, again, err := r.refreshAll(ctx, known)
	if err != nil {
		return nil, err
	}
	owned, err := c.svc.ownedWorktrees(c.id)
	if err != nil {
		return nil, err
	}
	for i, o := range owned {
		owned[i] = realpath.Of(o) // once a look, not once for each worktree git lists
	}
	j := newClaimsJudge(folder, steps, given, read.claims, c.gate.resolver())
	held := counted(next)
	for _, e := range list {
		if held.full() {
			break
		}
		cut, back := again[e.Path]
		if e.Main || e.Current || !back && slices.ContainsFunc(next, func(k model.RelatedWorktree) bool { return k.Path == e.Path }) || isOwned(e.Path, owned) {
			continue
		}
		call, run := j.owner(cut, e.Path, held)
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
			k := r.found(ctx, e, call)
			k.RunID = run
			next = append(next, k)
			held = counted(next)
		}
	}
	c.lookedTips, c.lookedStep, c.lookedAt = r.tips, r.last, r.at // the bases are moved on to them
	return forgetHidden(next), nil
}

// claimsJudge weighs, in one look, the claims on a listed worktree with no
// record: the subagents' steps and Claude's word on their worktrees
// (given), and the workflows' claims, resolving through one resolver
// (the gate's), each folder once.
type claimsJudge struct {
	folder string
	steps  []relatedStep
	given  map[string]string
	claims []workflowClaim
	reals  *realPaths
	of     func(string) string // realpath.Of, through the same resolver
}

// newClaimsJudge is a claimsJudge for a look of the chat in folder.
func newClaimsJudge(folder string, steps []relatedStep, given map[string]string, claims []workflowClaim, resolve func(string) (string, error)) claimsJudge {
	of := func(p string) string {
		if p == "" {
			return ""
		}
		if r, err := resolve(p); err == nil {
			return r
		}
		return filepath.Clean(p)
	}
	return claimsJudge{folder, steps, given, claims, newRealPaths(resolve), of}
}

// owner is the call, and its run ("" for a subagent's), that has the
// worktree at path, of a kind under its cap (h); "" when none. A kind
// at its cap judges nothing more: a subagent's claim comes before a
// run's, so with the subagents full theirs are weighed only for a
// worktree a run claims, to leave it out.
func (j claimsJudge) owner(cut madeAgain, path string, h held) (call, run string) {
	if h.roomForSubagents() {
		if call = cut.whose(path, j.folder, j.steps, j.given, j.of); call != "" || !h.roomForRuns() {
			return call, ""
		}
		return cut.workflowWhose(path, j.claims, j.reals)
	}
	if call, run = cut.workflowWhose(path, j.claims, j.reals); call != "" && cut.whose(path, j.folder, j.steps, j.given, j.of) != "" {
		return "", ""
	}
	return call, run
}

// refreshAll is known brought up to date with what git lists, and the
// paths made again (refresh's back), each with what may own its new
// record. Only a path's latest record is looked at: those before it went
// for good, and only it can be present.
func (r relatedLook) refreshAll(ctx context.Context, known []model.RelatedWorktree) ([]model.RelatedWorktree, map[string]madeAgain, error) {
	next := slices.Clone(known)
	latest := map[string]int{}
	for i := range next {
		latest[next[i].Path] = i
	}
	again := map[string]madeAgain{}
	for i := range next {
		if latest[next[i].Path] == i {
			back, err := r.refresh(ctx, &next[i])
			if err != nil {
				return nil, nil, err
			}
			if back {
				again[next[i].Path] = madeAgain{after: next[i].RemovedAfter, at: next[i].RemovedAt, before: callsAt(next, next[i].Path), made: madeAt(next[i].Path)}
			}
		} else {
			next[i].State = model.RelatedRemoved // an older daemon refreshed every record of a path, so more than one could be left present
		}
		if r.moved || next[i].LastHead != known[i].LastHead || !git.ObjectID(next[i].BaseCommit) {
			r.moveBase(ctx, &next[i]) // else it would find the base it found last time
		}
	}
	return next, again, nil
}

// verified says a path git listed is what it says: the top of a work tree
// of the chat's repository, by real path. Only ctx ending is an error: any
// other answer of git's there says it isn't.
func (r relatedLook) verified(ctx context.Context, path string) (bool, error) {
	common, top, err := r.c.worktrees.Locate(ctx, path)
	if ctxErr := ctx.Err(); ctxErr != nil {
		return false, ctxErr
	}
	return err == nil && common == r.common && top == realpath.Of(path), nil
}

// refresh brings a path's latest record up to date: removed unless git
// lists it and it passes, else its branch and head as they are now. A
// branch renamed to what isn't valid UTF-8 doesn't pass. A removed one
// whose path git lists again on another branch, or at a head that isn't
// its last or after it, is another worktree made there (issue #118): it
// stays removed, with its last commit, and back says so, for a new record.
// So is a present one whose .git file changed since it was first seen
// (Made), which a look saw no gap in: it goes removed as it was at the
// last look, after which it went.
func (r relatedLook) refresh(ctx context.Context, k *model.RelatedWorktree) (back bool, err error) {
	e, ok := r.listed[k.Path]
	ok = ok && plainText(e.Path, e.Branch)
	if ok {
		if ok, err = r.verified(ctx, k.Path); err != nil {
			return false, err
		}
	}
	if !ok {
		if k.State != model.RelatedRemoved {
			k.State, k.RemovedAfter, k.RemovedAt = model.RelatedRemoved, r.last, r.at
		}
		return false, nil
	}
	made := madeAt(k.Path)
	if k.State == model.RelatedRemoved || k.Made != 0 && made != 0 && made != k.Made {
		same, err := r.sameWork(ctx, *k, e)
		if err != nil || !same {
			if err == nil && k.State != model.RelatedRemoved {
				k.State, k.RemovedAfter, k.RemovedAt = model.RelatedRemoved, r.before, r.since
			}
			return !same && err == nil, err
		}
	}
	k.State, k.Branch, k.RemovedAfter, k.RemovedAt = model.RelatedPresent, cmp.Or(e.Branch, k.Branch), "", 0
	if made != 0 {
		k.Made = made
	}
	if git.ObjectID(e.Head) {
		k.LastHead = e.Head
	}
	return false, nil
}

// sameWork says the worktree git lists as e, at a removed record k's path,
// is k's back again: on its branch, at its last head or one after it. A
// head git can't place (k's collected) is not after it; only ctx ending is
// an error.
func (r relatedLook) sameWork(ctx context.Context, k model.RelatedWorktree, e model.WorktreeEntry) (bool, error) {
	if e.Branch != k.Branch {
		return false, nil
	}
	if !git.ObjectID(k.LastHead) || !git.ObjectID(e.Head) || e.Head == k.LastHead {
		return true, nil // nothing to tell them apart by but the branch
	}
	base, err := r.c.worktrees.MergeBase(ctx, r.folder, e.Head, k.LastHead)
	if ctxErr := ctx.Err(); ctxErr != nil {
		return false, ctxErr
	}
	return err == nil && base == k.LastHead, nil
}

// callsAt are the tool calls of list's records of path, the latest last.
func callsAt(list []model.RelatedWorktree, path string) []string {
	var calls []string
	for _, k := range list {
		if k.Path == path {
			calls = append(calls, k.CallID)
		}
	}
	return calls
}

// moveBase moves k's base on to where its head left the default branch,
// when that is later: the chat's folder can have an old branch out while
// an agent's worktree starts from origin/main, and a base taken from that
// branch counts every commit since as the worktree's (issue #16). Records
// kept from before are put right the same way. A head on the default
// branch (merged there) keeps its base, so its work and "merged" stay. One
// whose first look found no base (git failed then) gets one now.
func (r relatedLook) moveBase(ctx context.Context, k *model.RelatedWorktree) {
	if len(r.tips) == 0 || !git.ObjectID(k.LastHead) || k.LastHead == k.BaseCommit {
		return
	}
	from := r.tips
	if git.ObjectID(k.BaseCommit) {
		from = append([]string{k.BaseCommit}, r.tips...)
	}
	base, err := r.c.worktrees.MergeBase(ctx, r.folder, k.LastHead, from...)
	if err == nil && base != k.LastHead && git.ObjectID(base) {
		k.BaseCommit = base
	}
}

// found is the record of a worktree seen for the first time. Its base is
// where it left the chat's branch or the default branch, the later.
func (r relatedLook) found(ctx context.Context, e model.WorktreeEntry, call string) model.RelatedWorktree {
	k := model.RelatedWorktree{Path: e.Path, Branch: e.Branch, CallID: call, State: model.RelatedPresent, Made: madeAt(e.Path)}
	if git.ObjectID(e.Head) {
		k.LastHead = e.Head
		from := slices.Clone(r.tips)
		if git.ObjectID(r.head) {
			from = append(from, r.head)
		}
		if len(from) > 0 {
			if base, err := r.c.worktrees.MergeBase(ctx, r.folder, e.Head, from...); err == nil {
				k.BaseCommit = base
			}
		}
	}
	return k
}

// madeAt is when the .git file of the worktree at path last changed, in
// Unix nanoseconds: git writes it when it makes the worktree, and when it
// moves it or a repair changes it (ADR 0081 lists which), not when a
// branch is switched in it. One stat, no git; 0 when it can't be read.
func madeAt(path string) int64 {
	fi, err := os.Lstat(filepath.Join(path, ".git"))
	if err != nil {
		return 0
	}
	return fi.ModTime().UnixNano()
}

// isOwned says path is one of owned (real paths), or holds one: a chat
// that works in a folder of the worktree has it.
func isOwned(path string, owned []string) bool {
	path = realpath.Of(path)
	return slices.ContainsFunc(owned, func(o string) bool { return realpath.Under(o, path) })
}

// madeAgain is what may own a new record at a path whose latest record
// went (issue #118): only the steps after the one it went after (after),
// and those before it still running at the look that took it (at), and of
// the agent's word what names none of the path's records before (their
// calls, before), whose steps go last too. A step whose end was stamped
// before the new worktree's .git file was written (made) can only have
// seen the old one, or none: it doesn't count, wherever it stands. A
// record removed before that was kept (after "") is judged by every step
// as it was, a call that had none of those first.
type madeAgain struct {
	after  string
	at     int64
	before []string
	made   int64
}

// over says st ended before the worktree at the path was made again: an
// end stamped before its .git file's time. A step with no end stamped (a
// replayed one, or one still running), or a time not read, is judged as
// before this was kept.
func (m madeAgain) over(st relatedStep) bool {
	return m.made != 0 && st.ended != 0 && st.ended < m.made
}

// whose is whose (below) for a path made again, or for one seen the
// first time (a zero madeAgain). A point gone from the chat was cut by a
// rewind that kept no step: a rewind that keeps one moves the point back
// to it (rewoundLocked), so then every step there now came after
// the rewind, and all count.
func (m madeAgain) whose(path, folder string, steps []relatedStep, given map[string]string, of func(string) string) string {
	if m.after == "" {
		return whose(path, folder, slices.DeleteFunc(slices.Clone(steps), m.over), given, m.before, of)
	}
	i := slices.IndexFunc(steps, func(st relatedStep) bool { return st.id == m.after })
	var since []relatedStep
	for j, st := range steps {
		if (j > i || st.runningAt(m.at)) && !m.over(st) {
			since = append(since, st)
		}
	}
	mine := map[string]string{}
	for call, p := range given {
		if !slices.Contains(m.before, call) {
			mine[call] = p
		}
	}
	return whose(path, folder, since, mine, m.before, of)
}

// rewoundLocked is a rewind that keeps kept: the related worktrees' points
// it cut (a removed record's RemovedAfter) moved back to the last step it
// kept, the list the rewind saves with the record, so a restart before the
// next look keeps them. It also notes the rewind, so the next look moves
// what a look in flight during it read before the cut (its records and its
// last step) back the same way (rewoundPointsLocked). Of two rewinds before
// a look, the one that cut further back holds.
func (c *chat) rewoundLocked(kept []model.Item) []model.RelatedWorktree {
	steps := relatedSteps(kept)
	to := ""
	if len(steps) > 0 {
		to = steps[len(steps)-1].id
	}
	if !c.rewound || c.rewoundTo != "" && !slices.ContainsFunc(steps, func(st relatedStep) bool { return st.id == c.rewoundTo }) {
		c.rewoundTo = to
	}
	c.rewound = true
	list, _ := movePoints(c.record.RelatedWorktrees, steps, to)
	return list
}

// rewoundPointsLocked moves the points a rewind cut (a removed record's
// RemovedAfter, the last look's step) back to the last step it kept, and
// returns the records as they are then: what a look in flight during the
// rewind read and saved from before it. Every step kept came before the
// cut point, so a reader of the old worktree stays before it, and the
// steps after the rewind count. A rewind that kept no step leaves them,
// and madeAgain counts every step. It runs under looking.
func (c *chat) rewoundPointsLocked(steps []relatedStep) []model.RelatedWorktree {
	to := c.rewoundTo
	c.rewound, c.rewoundTo = false, ""
	if cutBy(c.lookedStep, steps, to) {
		c.lookedStep = to
	}
	list, moved := movePoints(c.record.RelatedWorktrees, steps, to)
	if moved {
		c.saveLocked(func(r *model.ChatRecord) { r.RelatedWorktrees = slices.Clone(list) })
	}
	return list
}

// movePoints is list with each removed record's point that steps no longer
// hold moved back to step to, and whether any moved; with to "" (a rewind
// that kept no step) none moves.
func movePoints(list []model.RelatedWorktree, steps []relatedStep, to string) ([]model.RelatedWorktree, bool) {
	list = slices.Clone(list)
	moved := false
	for i := range list {
		if cutBy(list[i].RemovedAfter, steps, to) {
			list[i].RemovedAfter, moved = to, true
		}
	}
	return list, moved
}

// cutBy says a rewind to step to cut the step id: it isn't among steps.
func cutBy(id string, steps []relatedStep, to string) bool {
	return id != "" && to != "" && !slices.ContainsFunc(steps, func(st relatedStep) bool { return st.id == id })
}

// whose is the tool call of the subagent the worktree at path is for, ""
// when none shows: the agent's word first, then the first of the steps to
// name it, in any of the ways a step can, but that a call that had none
// of the path's records before (their calls, before) goes first. of is
// realpath.Of, or the look's own.
func whose(path, folder string, steps []relatedStep, given map[string]string, before []string, of func(string) string) string {
	here := of(path)
	var named []string
	for call, p := range given {
		if of(p) == here {
			named = append(named, call)
		}
	}
	slices.Sort(named) // a forged file can name one worktree twice: the same answer each look
	names := spellings(path, folder, of)
	for _, st := range steps {
		if st.names(names) {
			named = append(named, st.call)
		}
	}
	if i := slices.IndexFunc(named, func(call string) bool { return !slices.Contains(before, call) }); i >= 0 {
		return named[i]
	}
	if len(named) > 0 {
		return named[0]
	}
	return ""
}

// spellings are the ways a tool call may name the worktree at path: git's
// path, its real path, the same under the chat's folder as the chat spells
// it, and relative to that folder, as Paths are inside it and as a
// command in it would say it.
func spellings(path, folder string, of func(string) string) []string {
	names := []string{path, of(path)}
	if rel, err := filepath.Rel(of(folder), of(path)); err == nil {
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
