package chats

import (
	"path/filepath"
	"slices"
	"strings"
	"unicode"
)

// The agent hears of the files the user edited in Nushi's preview (ADR
// 0096): a file saved there goes, by its path, with each chat's next
// prompt as a note of its own, once, so the agent reads it again before it
// changes it. Kept in memory, as the commands Nushi stopped are: a daemon
// restart forgets what wasn't told yet.

// editNote is the note for the files at paths (relative to the chat's
// folder, or absolute): noteName checked each.
func editNote(paths []string) string {
	names := make([]string, len(paths))
	for i, p := range paths {
		names[i] = "`" + p + "`"
	}
	it := "it"
	if len(paths) > 1 {
		it = "them"
	}
	return "[Nushi] The user edited " + strings.Join(names, ", ") + " in Nushi since your last turn; re-read " + it + " before changing " + it + "."
}

// noteName says a path can go in a note: no backquote, no line break or
// other control character, and no bidi or other format mark, so the note
// reads as one line, as written, and the replay finds it again
// (noteTexts).
func noteName(p string) bool {
	return p != "" && !strings.ContainsFunc(p, func(r rune) bool {
		return r == '`' || unicode.IsControl(r) || unicode.Is(unicode.Cf, r)
	})
}

// UserEdited notes that the user saved the file at path (absolute, its
// links followed) from chatID's preview: that chat and every other open
// one whose folder or worktree holds it tell their agent at their next
// prompt. A side chat isn't told; its chat is.
func (s *Service) UserEdited(chatID, path string) {
	for _, c := range s.openChats() {
		c.mu.Lock()
		if c.parent == nil {
			if name, ok := c.holdsLocked(path); ok || c.id == chatID {
				if !ok {
					name = path
				}
				if noteName(name) && !slices.Contains(c.edited, name) {
					c.edited = append(c.edited, name)
				}
			}
		}
		c.mu.Unlock()
	}
}

// holdsLocked says the chat's folder or worktree holds path, and its name
// there: relative to the folder, or absolute when it's in the worktree
// alone.
func (c *chat) holdsLocked(path string) (string, bool) {
	roots := []string{c.record.Folder}
	if wt := c.record.Worktree; wt != nil && wt.Path != c.record.Folder {
		roots = append(roots, wt.Path)
	}
	for i, r := range roots {
		for _, r := range []string{r, realPath(r)} {
			if rel, err := filepath.Rel(r, path); err == nil && filepath.IsLocal(rel) {
				if i > 0 {
					return path, true
				}
				return rel, true
			}
		}
	}
	return "", false
}

// realPath is p with its links followed, or p if that fails.
func realPath(p string) string {
	if r, err := filepath.EvalSymlinks(p); err == nil {
		return r
	}
	return p
}
