package git

import (
	"bytes"
	"cmp"
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/regularfile"
)

// Why a file has no blame (FileBlame.None), in words the app turns into
// its own.
const (
	NoBlameRepository   = "not a repository" // the folder isn't in one
	NoBlameIgnored      = "ignored"          // git ignores the file
	NoBlameUntracked    = "untracked"        // git doesn't track it
	NoBlameNew          = "new"              // staged, not in HEAD yet (or no HEAD)
	NoBlameLink         = "a link"
	NoBlameBinary       = "binary"
	NoBlameTooLarge     = "too large"      // over 1 MiB, as a diff's side
	NoBlameTooManyLines = "too many lines" // over 10,000, as change marks
)

const (
	// maxBlameLines is the most lines blamed, the file viewer's change
	// marks' limit (the app's maxDiffLines).
	maxBlameLines = 10_000
	// blameTimeout bounds one blame: a file with a long history can take
	// seconds, and a stuck one must not hold the call.
	blameTimeout = 30 * time.Second
	// maxBlameOutput bounds what git's answer is read to: ten thousand
	// runs of distinct commits, their headers and subjects capped below,
	// fit with room to spare.
	maxBlameOutput = 16 << 20
	// maxAuthor and maxSubject cap the text anyone who made a commit
	// chose, as GetGitHubCommits caps a commit's (docs/security.md).
	maxAuthor  = 256
	maxSubject = 1 << 10
)

// FileBlame is who last changed each line of a file: its runs in order,
// covering every line, or why there are none (None, one of the NoBlame
// words).
type FileBlame struct {
	Runs []BlameRun
	None string
}

// BlameRun is Count lines from line Start (1-based) that one commit last
// changed: its id, its author's name (never the address), the author's
// time (Unix seconds) and its subject's first line, plain. Lines not
// committed yet have no Commit and nothing else.
type BlameRun struct {
	Start, Count int
	Commit       string
	Author       string
	Time         int64
	Subject      string
}

// Blame runs git blame on one of folder's files as it is on disk now:
// the text read (a regular file inside folder, not through a link out of
// it, as File reads it) goes to git on stdin, so what's blamed is what
// was checked, and its lines not committed yet come back so. The
// repository's own filters and textconv drivers and its list of commits
// to skip are off, as for Nushi's other reads of a folder anyone may have
// made. A file git has no history for, a link, a binary one or one past
// the limits has a reason instead of runs.
func Blame(ctx context.Context, folder, path string) (FileBlame, error) {
	if !filepath.IsLocal(path) {
		return FileBlame{}, fmt.Errorf("%q is not inside the folder", path)
	}
	hasHead, err := repo(ctx, folder)
	if errors.Is(err, ErrNotRepository) {
		return FileBlame{None: NoBlameRepository}, nil
	}
	if err != nil {
		return FileBlame{}, err
	}
	text, none, err := blameText(folder, path)
	if err != nil || none != "" {
		return FileBlame{None: none}, err
	}
	rel := filepath.ToSlash(filepath.Clean(path))
	if none, err := blameHistory(ctx, folder, rel, hasHead); err != nil || none != "" {
		return FileBlame{None: none}, err
	}
	out, err := runBlame(ctx, folder, rel, text)
	if err != nil {
		return FileBlame{}, err
	}
	runs, err := readBlame(out, lines(text))
	return FileBlame{Runs: runs}, err
}

// blameText reads the file to blame, or says why it isn't blamed.
func blameText(folder, path string) (text []byte, none string, err error) {
	root, err := os.OpenRoot(folder)
	if err != nil {
		return nil, "", err
	}
	defer root.Close() //nolint:errcheck // read-only
	if fi, err := root.Lstat(path); err == nil && fi.Mode()&fs.ModeSymlink != 0 {
		return nil, NoBlameLink, nil
	}
	f, _, err := regularfile.OpenIn(root, path, false)
	if err != nil {
		return nil, "", err
	}
	defer f.Close() //nolint:errcheck // read-only
	b, err := io.ReadAll(io.LimitReader(f, maxText+1))
	switch {
	case err != nil:
		return nil, "", err
	case bytes.IndexByte(b, 0) >= 0:
		return nil, NoBlameBinary, nil
	case len(b) > maxText:
		return nil, NoBlameTooLarge, nil
	case lines(b) > maxBlameLines:
		return nil, NoBlameTooManyLines, nil
	}
	return b, "", nil
}

// blameHistory says why git has no history to blame rel (relative to
// folder, slashed) with: not tracked (ignored or not), or not in HEAD.
func blameHistory(ctx context.Context, folder, rel string, hasHead bool) (string, error) {
	out, err := run(ctx, folder, "ls-files", "-z", "--", ":(literal)"+rel)
	if err != nil {
		return "", err
	}
	if len(out) == 0 {
		// check-ignore exits 1, saying nothing, for a path not ignored, and
		// 128 for one it can't look at (in a submodule, past a link, a name
		// it reads as pathspec magic, which it takes no :(literal) to stop):
		// ls-files listed none of those, so they aren't tracked, as the
		// change marks say.
		cmd := command(ctx, folder, nil, "check-ignore", "-q", "--", rel)
		var stderr bytes.Buffer
		cmd.Stderr = &stderr
		err := cmd.Run()
		var exit *exec.ExitError
		switch {
		case err == nil:
			return NoBlameIgnored, nil
		case errors.As(err, &exit) && (exit.ExitCode() == 1 || exit.ExitCode() == 128):
			return NoBlameUntracked, nil
		case exit != nil:
			return "", fmt.Errorf("git check-ignore: %s", strings.TrimSpace(stderr.String()))
		default:
			return "", fmt.Errorf("git check-ignore: %w", err)
		}
	}
	if !hasHead {
		return NoBlameNew, nil
	}
	if _, err := verify(ctx, folder, "HEAD:./"+rel); err != nil {
		return NoBlameNew, nil //nolint:nilerr // not in HEAD: staged, never committed
	}
	return "", nil
}

// runBlame runs git blame --incremental on text, rel's as it is now.
func runBlame(ctx context.Context, folder, rel string, text []byte) ([]byte, error) {
	off, err := noFilters(ctx, folder)
	if err != nil {
		return nil, err
	}
	parent := ctx
	ctx, cancel := context.WithTimeout(ctx, blameTimeout)
	defer cancel()
	// --no-ignore-revs-file clears the list a repository's
	// blame.ignoreRevsFile names (a file of its choosing, whose commits
	// would be passed over) before git opens it, so a pipe there can't
	// hold the call nor a missing file fail it; an empty --ignore-revs-file
	// is only appended after the config's, which git still reads.
	cmd := command(ctx, folder, off, "blame", "--incremental", "--no-textconv", "--no-ignore-revs-file",
		"--contents", "-", "--", rel)
	cmd.Stdin = bytes.NewReader(text)
	var out bounded
	cmd.Stdout = &out
	err = finish(cmd, "blame")
	switch {
	case out.over:
		return nil, errors.New("git blame said more than a file's blame holds")
	case parent.Err() != nil: // the caller went away or gave less time
		return nil, fmt.Errorf("git blame: %w", parent.Err())
	case ctx.Err() != nil:
		return nil, fmt.Errorf("git blame took longer than %s", blameTimeout)
	case err != nil:
		return nil, err
	}
	return out.b, nil
}

// bounded keeps what's written to it, failing past maxBlameOutput (git
// then stops on the closed pipe).
type bounded struct {
	b    []byte
	over bool
}

func (w *bounded) Write(p []byte) (int, error) {
	if len(w.b)+len(p) > maxBlameOutput {
		w.over = true
		return 0, errors.New("past the limit")
	}
	w.b = append(w.b, p...)
	return len(p), nil
}

// blameHeader is what blame says of a commit, once, the first time it
// names it.
type blameHeader struct {
	author, summary string
	time            int64
}

// readBlame reads git blame --incremental's entries (in any order) into
// runs in line order, neighbours from one commit joined, which must cover
// lines 1 to total once each.
func readBlame(out []byte, total int) ([]BlameRun, error) {
	headers := map[string]*blameHeader{}
	var runs []BlameRun
	var cur *BlameRun
	for line := range strings.Lines(string(out)) {
		line = strings.TrimSuffix(line, "\n")
		if cur == nil {
			f := strings.Fields(line)
			if len(f) != 4 || !ObjectID(f[0]) {
				return nil, fmt.Errorf("git blame: %q is not an entry", line)
			}
			start, err1 := strconv.Atoi(f[2])
			count, err2 := strconv.Atoi(f[3])
			if err1 != nil || err2 != nil || start < 1 || count < 1 {
				return nil, fmt.Errorf("git blame: %q is not an entry", line)
			}
			cur = &BlameRun{Start: start, Count: count, Commit: f[0]}
			if headers[f[0]] == nil {
				headers[f[0]] = &blameHeader{}
			}
			continue
		}
		h := headers[cur.Commit]
		key, value, _ := strings.Cut(line, " ")
		switch key {
		case "author":
			h.author = value
		case "author-time":
			h.time, _ = strconv.ParseInt(value, 10, 64)
		case "summary":
			h.summary = value
		case "filename": // an entry's last line
			runs = append(runs, *cur)
			cur = nil
		}
	}
	if cur != nil {
		return nil, errors.New("git blame: its answer was cut off")
	}
	slices.SortFunc(runs, func(a, b BlameRun) int { return cmp.Compare(a.Start, b.Start) })
	var joined []BlameRun
	next := 1
	for _, r := range runs {
		switch {
		case r.Start < next:
			return nil, fmt.Errorf("git blame: line %d is blamed twice", r.Start)
		case r.Start > next:
			return nil, fmt.Errorf("git blame: line %d is never blamed", next)
		}
		next += r.Count
		if n := len(joined); n > 0 && joined[n-1].Commit == r.Commit {
			joined[n-1].Count += r.Count
			continue
		}
		joined = append(joined, r)
	}
	if next-1 != total {
		return nil, fmt.Errorf("git blame: %d lines blamed of %d", next-1, total)
	}
	for i := range joined {
		r := &joined[i]
		if strings.Trim(r.Commit, "0") == "" { // not committed yet
			r.Commit = ""
			continue
		}
		h := headers[r.Commit]
		r.Author, r.Time, r.Subject = plainLine(h.author, maxAuthor), h.time, plainLine(h.summary, maxSubject)
	}
	return joined, nil
}

// plainLine is text someone else chose, for a line of its own, shown and
// never rendered: valid UTF-8, without control or format characters (bidi
// marks, zero-width ones, which could hide or reorder what's around it),
// at most limit bytes, cut at a character.
func plainLine(s string, limit int) string {
	var b strings.Builder
	for _, r := range strings.ToValidUTF8(s, "�") {
		if unicode.IsControl(r) || unicode.Is(unicode.Cf, r) || r == ' ' || r == ' ' {
			continue
		}
		if b.Len()+utf8.RuneLen(r) > limit {
			break
		}
		b.WriteRune(r)
	}
	return b.String()
}
