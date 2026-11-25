package git

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"path/filepath"
	"slices"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// Staging a change block at a time (ADR 0079's hunk amendment). The app
// names the blocks it shows and those the user pressed; the daemon reads
// the file's texts from git and the disk itself, works out the index, and
// writes the index alone, never the work tree.

// ErrFileMoved is a request about a file whose HEAD text, work tree text
// or index entry isn't what the app showed: an agent or a terminal
// changed or staged it since.
var ErrFileMoved = errors.New("the file changed since it was shown; look again")

// ErrWholeFileOnly is a block press on a file whose index isn't made of
// its blocks (staged, then changed again): only the whole file stages.
var ErrWholeFileOnly = errors.New("what's staged of this file isn't made of its changes as shown; stage or unstage the whole file")

// entry is a path's line in git diff --raw: the modes and object ids on
// each side, and git's status letter.
type entry struct {
	srcMode, dstMode, dstOID string
	status                   byte
}

// rawEntries reads git diff --raw -z --no-renames: each path's entry.
func rawEntries(out []byte) (map[string]entry, error) {
	fields := split(out)
	entries := make(map[string]entry, len(fields)/2)
	for i := 0; i+1 < len(fields); i += 2 { // ":<mode> <mode> <oid> <oid> <status>", the path
		f := strings.Fields(fields[i])
		if len(f) < 5 || f[4] == "" {
			return nil, fmt.Errorf("git diff: can't read %q", fields[i])
		}
		entries[fields[i+1]] = entry{srcMode: strings.TrimPrefix(f[0], ":"), dstMode: f[1], dstOID: f[3], status: f[4][0]}
	}
	return entries, nil
}

// indexEntries are the folder's staged entries (HEAD to the index) and
// unstaged ones (the index to the work tree), by path relative to folder;
// with paths, only theirs.
func indexEntries(ctx context.Context, folder string, paths ...string) (staged, unstaged map[string]entry, err error) {
	var spec []string
	if len(paths) > 0 {
		spec = append(spec, "--")
		for _, p := range paths {
			spec = append(spec, ":(literal)"+p)
		}
	}
	read := func(cached bool) (map[string]entry, error) {
		args := []string{"diff"}
		if cached {
			args = append(args, "--cached")
		}
		args = append(args, "--raw", "-z", "--no-abbrev", "--no-renames", "--relative", "--ignore-submodules=dirty", "--no-ext-diff")
		out, err := run(ctx, folder, append(args, spec...)...)
		if err != nil {
			return nil, err
		}
		return rawEntries(out)
	}
	if staged, err = read(true); err != nil {
		return nil, nil, err
	}
	unstaged, err = read(false)
	return staged, unstaged, err
}

// regular says a mode is a regular file's.
func regular(mode string) bool { return mode == "100644" || mode == "100755" }

// blockable says a change is one whose blocks stage on their own: a text
// file modified in place, read whole, a regular file on every side (no
// link, submodule or type change) and not unmerged. A new, deleted or
// renamed file, a binary or over-large one and the rest stage whole.
func blockable(c model.FileChange, staged, unstaged map[string]entry) bool {
	if c.Status != "modified" || c.OldPath != "" || c.Skipped != "" {
		return false
	}
	s, isStaged := staged[c.Path]
	u, isUnstaged := unstaged[c.Path]
	if !isStaged && !isUnstaged || isStaged && s.status != 'M' || isUnstaged && u.status != 'M' {
		return false
	}
	modes := []string{s.srcMode, s.dstMode}
	if !isStaged {
		modes = []string{u.srcMode}
	}
	if isUnstaged {
		modes = append(modes, u.dstMode)
	}
	return !slices.ContainsFunc(modes, func(m string) bool { return !regular(m) })
}

// hunkToken names what the app is shown of a file that stages in blocks:
// its HEAD text, its work tree text and its index entry when staged.
func hunkToken(old, cur string, staged entry, isStaged bool) string {
	h := sha256.New()
	for _, part := range []string{old, cur} {
		h.Write([]byte(strconv.Itoa(len(part)) + ":" + part))
	}
	if isStaged {
		h.Write([]byte("index:" + staged.dstMode + " " + staged.dstOID))
	}
	return hex.EncodeToString(h.Sum(nil)[:16])
}

// markHunks gives each change that stages in blocks its token
// (FileChange.Hunks): a file a filter driver cleans (git-lfs and the like)
// stages whole, since a filter's part file is no file at all.
func markHunks(ctx context.Context, folder string, changes []model.FileChange, staged, unstaged map[string]entry) error {
	var paths []string
	for _, c := range changes {
		if blockable(c, staged, unstaged) {
			paths = append(paths, c.Path)
		}
	}
	filtered, err := filteredOf(ctx, folder, paths)
	if err != nil {
		return err
	}
	for i := range changes {
		c := &changes[i]
		if blockable(*c, staged, unstaged) && !filtered[c.Path] {
			s, isStaged := staged[c.Path]
			c.Hunks = hunkToken(c.Old, c.New, s, isStaged)
		}
	}
	return nil
}

// filteredOf says which of paths have a filter attribute set, in one git
// check-attr.
func filteredOf(ctx context.Context, folder string, paths []string) (map[string]bool, error) {
	if len(paths) == 0 {
		return map[string]bool{}, nil
	}
	cmd := command(ctx, folder, nil, "check-attr", "-z", "--stdin", "filter")
	cmd.Stdin = strings.NewReader(strings.Join(paths, "\x00") + "\x00")
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := finish(cmd, "check-attr"); err != nil {
		return nil, err
	}
	filtered := map[string]bool{}
	f := split(out.Bytes())
	for i := 0; i+2 < len(f); i += 3 { // the path, the attribute, its value
		if v := f[i+2]; v != "unspecified" && v != "unset" {
			filtered[f[i]] = true
		}
	}
	return filtered, nil
}

// blockFile is one file that stages in blocks, as read for a request.
type blockFile struct {
	old, cur, index []line
	mode            string // the index entry's
}

// readBlockFile reads path's texts and index entry, and refuses unless it
// still stages in blocks with token, what the app was shown.
func readBlockFile(ctx context.Context, folder, path, token string) (blockFile, error) {
	if !filepath.IsLocal(path) || strings.ContainsRune(path, 0) {
		return blockFile{}, fmt.Errorf("%q isn't inside the folder", path)
	}
	changes, err := Changes(ctx, folder, Span{Path: path})
	if err != nil {
		return blockFile{}, err
	}
	if len(changes) != 1 {
		return blockFile{}, ErrFileMoved // unchanged now
	}
	c := changes[0]
	staged, unstaged, err := indexEntries(ctx, folder, path)
	if err != nil {
		return blockFile{}, err
	}
	if err := markHunks(ctx, folder, changes, staged, unstaged); err != nil {
		return blockFile{}, err
	}
	if changes[0].Hunks == "" || changes[0].Hunks != token {
		return blockFile{}, ErrFileMoved
	}
	f := blockFile{old: splitLines([]byte(c.Old)), cur: splitLines([]byte(c.New)), index: splitLines([]byte(c.Old))}
	s, isStaged := staged[path]
	if !isStaged {
		f.mode = unstaged[path].srcMode
		return f, nil
	}
	f.mode = s.dstMode
	var out capped
	if _, err := runTo(ctx, folder, nil, &out, "cat-file", "blob", s.dstOID); err != nil {
		return blockFile{}, err
	}
	if len(out.b) > maxText || bytes.IndexByte(out.b, 0) >= 0 {
		return blockFile{}, ErrWholeFileOnly
	}
	f.index = splitLines(out.b)
	return f, nil
}

// HunkStates says which of a file's blocks are staged. token is the file's
// FileChange.Hunks as the app was shown it; blocks are every change of the
// file as the app shows them. ok is false when the index holds a version
// of the file that isn't made of them, which stages only whole.
func HunkStates(ctx context.Context, folder, path, token string, blocks []Block) (staged []bool, ok bool, err error) {
	f, err := readBlockFile(ctx, folder, path, token)
	if errors.Is(err, ErrWholeFileOnly) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	if err := checkBlocks(f.old, f.cur, blocks); err != nil {
		return nil, false, err
	}
	staged, ok = matchBlocks(f.old, f.cur, f.index, blocks)
	return staged, ok, nil
}

// StageHunks stages the blocks pressed (indexes into blocks), or with on
// false takes them out of the index, leaving every other block as it is,
// and returns every block's state after. A block already so is left as it
// is: pressing it twice on one look changes nothing more. It writes the
// index entry alone, with its mode kept, through the repository's clean
// filters and line-ending rules as git add would.
func StageHunks(ctx context.Context, folder, path, token string, blocks []Block, pressed []int, on bool) ([]bool, error) {
	f, err := readBlockFile(ctx, folder, path, token)
	if err != nil {
		return nil, err
	}
	if err := checkBlocks(f.old, f.cur, blocks); err != nil {
		return nil, err
	}
	staged, ok := matchBlocks(f.old, f.cur, f.index, blocks)
	if !ok {
		return nil, ErrWholeFileOnly
	}
	if len(pressed) == 0 {
		return nil, errors.New("no change was pressed")
	}
	want := slices.Clone(staged)
	for _, k := range pressed {
		if k < 0 || k >= len(blocks) {
			return nil, fmt.Errorf("change %d isn't one of the file's: %w", k+1, ErrBlocksDontFit)
		}
		want[k] = on
	}
	if slices.Equal(want, staged) {
		return staged, nil
	}
	text := assemble(f.old, f.cur, blocks, want)
	cmd := command(ctx, folder, nil, "hash-object", "-w", "--stdin", "--path="+path)
	cmd.Stdin = bytes.NewReader(text)
	var oid bytes.Buffer
	cmd.Stdout = &oid
	if err := finish(cmd, "hash-object"); err != nil {
		return nil, err
	}
	// hash-object's --path is the folder's, --cacheinfo's the top's.
	prefix, err := run(ctx, folder, "rev-parse", "--show-prefix")
	if err != nil {
		return nil, err
	}
	top := strings.TrimSuffix(string(prefix), "\n") + path
	if _, err := run(ctx, folder, "update-index", "--cacheinfo", f.mode+","+strings.TrimSpace(oid.String())+","+top); err != nil {
		return nil, err
	}
	return want, nil
}
