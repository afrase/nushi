package chats

import (
	"bytes"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"sync"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
	"github.com/afrase/nushi/internal/regularfile"
)

// A workflow writes many files, nearly all in the chat's own folder, and
// a chat with no related worktree and no subagent runs no git for them
// (ADR 0081's amendment of 2026-11-26). So its files bring a look only
// when one could make a record: Claude's word on a worktree, or a file
// written in a linked worktree of the chat's repository other than the
// chat's own (the one its folder is the top of or inside), told without
// git from the nearest .git above it (a linked worktree's is a file
// naming a folder in the repository's worktrees/; the main checkout's is
// a folder, a submodule's names another place).

const (
	// gitFileLimit is the most of a .git file read: git writes one line.
	gitFileLimit = 4 << 10
	// maxGateAnswers is the most folders the gate keeps an answer for:
	// past it, it forgets them all and walks again.
	maxGateAnswers = 4096
)

// worktreeGate keeps what the gate found, under its own lock (the walks
// run on no lock of the chat's), for the chat's life: the repository's
// common folder as the last look found it, for the chat's folder it was
// found for, and its answer for each folder a written file was named in,
// yes or no, so a look asked for again walks nothing it walked. The
// answers are for one chat folder, one common folder and one list of
// git's worktrees: a change in any forgets them, as a worktree made or
// removed changes what a folder is in. A chat moved to another folder
// finds its common folder again (a folder of another repository has
// another).
type worktreeGate struct {
	mu        sync.Mutex
	common    string
	commonFor string          // the chat's folder common was found for
	folder    string          // the chat's folder the answers are for
	listed    []string        // git's worktrees as the last look listed them, sorted
	answers   map[string]bool // by a written file's folder as named

	// lstat and resolve are os.Lstat and filepath.EvalSymlinks, or a
	// test's that counts them; read under mu.
	lstat   func(string) (fs.FileInfo, error)
	resolve func(string) (string, error)
}

// setCommon keeps the common folder (a real path) a look found for the
// chat in folder.
func (g *worktreeGate) setCommon(common, folder string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.common != "" && g.common != common {
		g.answers = nil
	}
	g.common, g.commonFor = common, folder
}

// setListed keeps the worktrees a look's git listed: a list unlike the
// last look's forgets the answers. At the first look nothing is
// forgotten: the answers were found from the same disk.
func (g *worktreeGate) setListed(list []model.WorktreeEntry) {
	paths := make([]string, 0, len(list))
	for _, e := range list {
		paths = append(paths, e.Path)
	}
	slices.Sort(paths)
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.listed != nil && !slices.Equal(g.listed, paths) {
		g.answers = nil
	}
	g.listed = paths
}

// answer is the gate's answer for dir, kept for the chat in folder.
func (g *worktreeGate) answer(dir, folder string) (yes, known bool) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.folder != folder {
		return false, false
	}
	yes, known = g.answers[dir]
	return yes, known
}

// keep keeps the answer for dir, for the chat in folder.
func (g *worktreeGate) keep(dir, folder string, yes bool) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.folder != folder || len(g.answers) >= maxGateAnswers {
		g.folder, g.answers = folder, nil
	}
	if g.answers == nil {
		g.answers = map[string]bool{}
	}
	g.answers[dir] = yes
}

// couldCount says one of claims could make a record of a related worktree
// of the chat in folder: Claude's word on a worktree, or a file written in
// a linked worktree that isn't the chat's own. A folder with an answer
// kept is not walked again.
func (g *worktreeGate) couldCount(claims []workflowClaim, folder string) bool {
	var w *gateWalk
	for _, cl := range claims {
		if cl.word {
			return true
		}
		dir := filepath.Dir(cl.path)
		yes, known := g.answer(dir, folder)
		if !known {
			if w == nil {
				w = g.walk(folder)
			}
			yes = w.inLinked(dir)
			g.keep(dir, folder, yes)
		}
		if yes {
			return true
		}
	}
	return false
}

// freshClaims says the run read now (got) brings, beside what the chat
// had of it (was), a claim that could make a record: one under no present
// record (present, as the chat's record had them) that the gate passes.
// Each new written path's folder is walked once a read, but one kept as
// in a linked worktree: a folder once outside one may be in one made
// since. It runs on no lock of the chat's.
func (g *worktreeGate) freshClaims(was, got model.Workflow, folder string, present []string) bool {
	run := func(w model.Workflow) []workflowClaim {
		return workflowClaims([]model.Item{{Kind: model.ToolCall, Workflow: &w}}, folder)
	}
	type claimKey struct {
		word bool
		path string
	}
	old := map[claimKey]bool{}
	for _, o := range run(was) {
		old[claimKey{o.word, o.path}] = true
	}
	w := g.walk(folder)
	walked := map[string]bool{}
	for _, cl := range run(got) {
		if old[claimKey{cl.word, cl.path}] {
			continue
		}
		p := w.reals.file(cl.path)
		if slices.ContainsFunc(present, func(r string) bool { return realpath.Under(p, w.reals.of(r)) }) {
			continue
		}
		if cl.word {
			return true
		}
		dir := filepath.Dir(cl.path)
		yes, done := walked[dir]
		if !done {
			if kept, known := g.answer(dir, folder); known && kept {
				yes = true
			} else {
				yes = w.inLinked(dir)
				g.keep(dir, folder, yes)
			}
			walked[dir] = yes
		}
		if yes {
			return true
		}
	}
	return false
}

// gateWalk is one ask of the gate: the chat's folder and the common folder
// found once, when first needed, and each folder resolved once.
type gateWalk struct {
	g      *worktreeGate
	reals  *realPaths
	lstat  func(string) (fs.FileInfo, error)
	folder string // the chat's; resolved once found
	common string
	found  bool // folder resolved and common looked for
}

// resolver is the gate's resolve, filepath.EvalSymlinks or a test's: a
// look resolves through it too.
func (g *worktreeGate) resolver() func(string) (string, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.resolve == nil {
		return filepath.EvalSymlinks
	}
	return g.resolve
}

// walk starts an ask of the gate for the chat in folder.
func (g *worktreeGate) walk(folder string) *gateWalk {
	g.mu.Lock()
	defer g.mu.Unlock()
	w := &gateWalk{g: g, reals: newRealPaths(g.resolve), lstat: g.lstat, folder: folder}
	if w.lstat == nil {
		w.lstat = os.Lstat
	}
	return w
}

// inLinked says a file in dir (as named) lies in a linked worktree of the
// chat's repository that isn't the chat's own.
func (w *gateWalk) inLinked(dir string) bool {
	if !w.found {
		w.found = true
		w.g.mu.Lock()
		if w.g.commonFor == w.folder { // else found for a folder the chat has left
			w.common = w.g.common
		}
		w.g.mu.Unlock()
		w.folder = w.reals.of(w.folder)
		if w.common == "" {
			w.common = w.commonOf(w.folder)
		}
	}
	return w.linkedTop(w.reals.of(dir), w.common, w.folder) != ""
}

// linkedTop is the top of the worktree dir is in, when that is a linked
// worktree of the repository whose common folder is common and not the
// chat's own (folder is that top or inside it: a chat started in repo/app
// with a worktree runs in <worktree>/app); "" otherwise. It looks up from
// dir for the nearest .git: only a regular file counts, whose gitdir
// names a folder in common's worktrees/.
func (w *gateWalk) linkedTop(dir, common, folder string) string {
	if common == "" {
		return ""
	}
	for d := dir; ; {
		// No .git there, or one that can't be seen: look further up.
		if fi, err := w.lstat(filepath.Join(d, ".git")); err == nil {
			if realpath.Under(folder, d) || !fi.Mode().IsRegular() { // the chat's own: its folder is the top or inside it
				return ""
			}
			if under, err := filepath.Rel(filepath.Join(common, "worktrees"), gitDirOf(d)); err == nil && filepath.IsLocal(under) && under != "." {
				return d
			}
			return ""
		}
		up := filepath.Dir(d)
		if up == d {
			return ""
		}
		d = up
	}
}

// gitDirOf is the folder the .git file in dir names (its gitdir line,
// relative to dir if it is), resolved; "" when it names none.
func gitDirOf(dir string) string {
	f, fi, err := regularfile.Open(filepath.Join(dir, ".git"), false)
	if err != nil {
		return ""
	}
	defer f.Close() //nolint:errcheck // read-only
	b, err := regularfile.ReadAll(f, fi, gitFileLimit)
	if err != nil {
		return ""
	}
	line, _, _ := bytes.Cut(b, []byte("\n"))
	p, ok := bytes.CutPrefix(bytes.TrimSpace(line), []byte("gitdir:"))
	if !ok {
		return ""
	}
	gitdir := string(bytes.TrimSpace(p))
	if gitdir == "" || bytes.IndexByte(p, 0) >= 0 {
		return ""
	}
	if !filepath.IsAbs(gitdir) {
		gitdir = filepath.Join(dir, gitdir)
	}
	return realpath.Of(gitdir)
}

// commonOf is the common folder of the repository folder is in, told
// without git, for a chat no look has found it for yet: the nearest .git
// above it, a folder (the main checkout's) or, for a file, the folder it
// names, or that one's repository for a linked worktree's.
func (w *gateWalk) commonOf(folder string) string {
	for d := folder; ; {
		fi, err := w.lstat(filepath.Join(d, ".git"))
		if err == nil {
			if fi.IsDir() {
				return realpath.Of(filepath.Join(d, ".git"))
			}
			gitdir := gitDirOf(d)
			if gitdir != "" && filepath.Base(filepath.Dir(gitdir)) == "worktrees" {
				return filepath.Dir(filepath.Dir(gitdir))
			}
			return gitdir
		}
		up := filepath.Dir(d)
		if up == d {
			return ""
		}
		d = up
	}
}
