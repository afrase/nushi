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

// Link gives Claude a shared skill by a relative link to it: for the
// project's, <its folder>/.claude/skills/<name> → ../../.agents/skills/<name>
// beside the .agents holding it; for yours, in your skills folder. Only a
// skill right in a shared root Nushi lists; nothing replaced; a linked
// .claude or .claude/skills refused.
func (Claude) Link(_ context.Context, folder, path string) error {
	project, yours := sharedRoots(folder)
	root := filepath.Dir(path)
	if filepath.Clean(path) != path || !slices.Contains(append(project, yours), root) {
		return fmt.Errorf("%s isn't a shared skill here", path)
	}
	if _, err := os.Stat(filepath.Join(path, "SKILL.md")); err != nil {
		return fmt.Errorf("%s isn't a skill's folder", path)
	}
	if root == yours {
		link := filepath.Join(userRoot(), filepath.Base(path))
		if _, err := os.Lstat(link); !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("%s is already there", link)
		}
		if err := os.MkdirAll(userRoot(), 0o755); err != nil { //nolint:gosec // your skills folder, as Claude makes it
			return err
		}
		rel, err := filepath.Rel(realOf(userRoot()), path)
		if err != nil {
			rel = path
		}
		return os.Symlink(rel, link)
	}
	dir := filepath.Dir(filepath.Dir(root)) // the folder holding .agents
	if home, _ := os.UserHomeDir(); dir == home || skillfile.Linked(dir, ".claude/skills") {
		return fmt.Errorf("Claude doesn't read %s's .claude/skills as the project's", dir)
	}
	// Through an os.Root of the repository: a .claude swapped for a link
	// meanwhile can't put the link outside it.
	base := cmp.Or(skillfile.Top(dir), dir)
	r, err := os.OpenRoot(base)
	if err != nil {
		return err
	}
	defer r.Close() //nolint:errcheck // done with it
	at, err := filepath.Rel(base, filepath.Join(dir, ".claude", "skills"))
	if err != nil {
		return err
	}
	link := filepath.Join(at, filepath.Base(path))
	if _, err := r.Lstat(link); !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("%s is already there", filepath.Join(base, link))
	}
	if err := r.MkdirAll(at, 0o755); err != nil {
		return err
	}
	return r.Symlink(filepath.Join("..", "..", ".agents", "skills", filepath.Base(path)), link)
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
