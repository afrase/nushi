package claudeskills

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/skillfile"
)

// Claude Code 2.1.310 doesn't read .agents/skills (docs/facts/claude.md),
// but it follows a skill folder in .claude/skills that is a link: a shared
// skill linked there is Claude's too. Shared lists those; Link makes one.
// When Claude reads .agents/skills itself, Shared adds those roots and
// ReadsShared turns true.

// sharedRoots are the project's .agents/skills folders for folder, as the
// other agents read them (up to the repository's root; linked ones left
// out), and yours.
func sharedRoots(folder string) (project []string, yours string) {
	home, _ := os.UserHomeDir()
	folder = realOf(folder)
	return skillfile.Roots(folder, skillfile.Top(folder), ".agents/skills"), realOf(filepath.Join(home, ".agents", "skills"))
}

// Shared returns the shared skills Claude loads in folder: those a skill
// folder of yours or the project's links to, each named as the link is,
// on or off as that skill is, the link as its one agent's Via.
func (c Claude) Shared(ctx context.Context, folder string) []model.Skill {
	return c.shared(ctx, folder, claudemcp.Project(folder))
}

// shared is Shared, for folder whose project is key.
func (c Claude) shared(ctx context.Context, folder, key string) []model.Skill {
	project, yours := sharedRoots(folder)
	l, err := c.list(ctx, folder, key, false)
	if err != nil {
		return nil
	}
	var out []model.Skill
	for _, s := range l.Skills {
		if s.Linked == "" || s.Source == "plugin" {
			continue
		}
		target, err := filepath.EvalSymlinks(s.Path)
		if err != nil || !slices.Contains(append(project, yours), filepath.Dir(target)) {
			continue
		}
		out = append(out, model.Skill{Name: s.Name, Description: s.Description, Source: "shared", Path: target, State: s.State,
			SetIn: s.SetIn, Tokens: s.Tokens, Everywhere: filepath.Dir(target) == yours,
			Agents: []model.SkillAgent{{Agent: "claude", Via: s.Path}}})
	}
	return out
}

// link is the link Link makes for a shared skill: at in base saying to;
// base is "" for one of yours, whose at is a whole path.
type link struct{ base, at, to string }

// linkFor is the link that gives Claude the shared skill at path, or why
// Link makes none: only a skill's folder right in a shared root Nushi
// lists; nothing replaced; a linked .claude or .claude/skills refused.
func linkFor(folder, path string) (link, error) {
	project, yours := sharedRoots(folder)
	root := filepath.Dir(path)
	if filepath.Clean(path) != path || !slices.Contains(append(project, yours), root) {
		return link{}, fmt.Errorf("%s isn't a shared skill here", path)
	}
	if _, err := os.Stat(filepath.Join(path, "SKILL.md")); err != nil {
		return link{}, fmt.Errorf("%s isn't a skill's folder", path)
	}
	l := link{at: filepath.Join(userRoot(), filepath.Base(path))}
	if root == yours {
		rel, err := filepath.Rel(realOf(userRoot()), path)
		if err != nil {
			rel = path
		}
		l.to = rel
	} else {
		dir := filepath.Dir(filepath.Dir(root)) // the folder holding .agents
		if home, _ := os.UserHomeDir(); dir == home || skillfile.Linked(dir, ".claude/skills") {
			return link{}, fmt.Errorf("Claude doesn't read %s's .claude/skills as the project's", dir)
		}
		l.base = cmp.Or(skillfile.Top(dir), dir)
		at, err := filepath.Rel(l.base, filepath.Join(dir, ".claude", "skills", filepath.Base(path)))
		if err != nil {
			return link{}, err
		}
		l.at, l.to = at, filepath.Join("..", "..", ".agents", "skills", filepath.Base(path))
	}
	if _, err := os.Lstat(filepath.Join(l.base, l.at)); !errors.Is(err, os.ErrNotExist) {
		return link{}, fmt.Errorf("%s is already there", filepath.Join(l.base, l.at))
	}
	return l, nil
}

// CanLink says why Link wouldn't give Claude the shared skill at path,
// and makes nothing.
func (Claude) CanLink(_ context.Context, folder, path string) error {
	_, err := linkFor(folder, path)
	return err
}

// Link gives Claude a shared skill by a relative link to it: for the
// project's, <its folder>/.claude/skills/<name> → ../../.agents/skills/<name>
// beside the .agents holding it; for yours, in your skills folder. Only
// where CanLink passes.
func (Claude) Link(_ context.Context, folder, path string) error {
	l, err := linkFor(folder, path)
	if err != nil {
		return err
	}
	if l.base == "" {
		if err := os.MkdirAll(filepath.Dir(l.at), 0o755); err != nil { //nolint:gosec // your skills folder, as Claude makes it
			return err
		}
		return os.Symlink(l.to, l.at)
	}
	// Through an os.Root of the repository: a .claude swapped for a link
	// meanwhile can't put the link outside it. Symlink replaces nothing.
	r, err := os.OpenRoot(l.base)
	if err != nil {
		return err
	}
	defer r.Close() //nolint:errcheck // done with it
	if err := r.MkdirAll(filepath.Dir(l.at), 0o755); err != nil {
		return err
	}
	return r.Symlink(l.to, l.at)
}

// realOf is p with its links resolved, as far as it exists.
func realOf(p string) string {
	if r, err := filepath.EvalSymlinks(p); err == nil {
		return r
	}
	if parent := filepath.Dir(p); parent != p {
		return filepath.Join(realOf(parent), filepath.Base(p))
	}
	return p
}
