package codexskills

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

func write(t *testing.T, path, text string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
}

func skill(t *testing.T, root, dir, name string) {
	t.Helper()
	fm := "---\ndescription: " + dir + " does things\n"
	if name != "" {
		fm += "name: " + name + "\n"
	}
	write(t, filepath.Join(root, dir, "SKILL.md"), fm+"---\nbody\n")
}

func link(t *testing.T, target, at string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(at), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, at); err != nil {
		t.Fatal(err)
	}
}

// setup gives Codex a throwaway CODEX_HOME and HOME, and a repository
// (real paths) with a folder two levels down.
func setup(t *testing.T) (codexHome, home, top, deeper string) {
	t.Helper()
	codexHome, _ = filepath.EvalSymlinks(t.TempDir())
	home, _ = filepath.EvalSymlinks(t.TempDir())
	t.Setenv("CODEX_HOME", codexHome)
	t.Setenv("HOME", home)
	above, _ := filepath.EvalSymlinks(t.TempDir())
	top = filepath.Join(above, "repo")
	deeper = filepath.Join(top, "sub", "deeper")
	if err := os.MkdirAll(filepath.Join(top, ".git"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(deeper, 0o700); err != nil {
		t.Fatal(err)
	}
	return codexHome, home, top, deeper
}

func listed(skills []model.Skill) string {
	var out []string
	for _, s := range skills {
		extra := ""
		if s.Linked != "" {
			extra = " linked"
		}
		if s.Everywhere {
			extra += " everywhere"
		}
		out = append(out, fmt.Sprintf("%s %s %s%s", s.Source, s.Name, s.State, extra))
	}
	return strings.Join(out, "|")
}

// Codex's skills: yours, its own, ~/.agents/skills, and the project's
// .codex/skills and .agents/skills up to the repository's root; linked
// roots left out, linked skill folders listed as linked; a linked
// SKILL.md and one without a description skipped; config.toml's entries
// decide what's off.
func TestListReadsEachRoot(t *testing.T) {
	codexHome, home, top, deeper := setup(t)
	skill(t, filepath.Join(codexHome, "skills"), "mine", "")
	skill(t, filepath.Join(codexHome, "skills", ".system"), "imagegen", "")
	skill(t, filepath.Join(home, ".agents", "skills"), "everyday", "")
	skill(t, filepath.Join(top, ".agents", "skills"), "release", "notes")
	skill(t, filepath.Join(top, ".codex", "skills"), "codexonly", "")
	skill(t, filepath.Join(top, "sub", ".agents", "skills"), "near", "")
	skill(t, filepath.Join(filepath.Dir(top), ".agents", "skills"), "above", "") // above the repository: not read
	write(t, filepath.Join(top, ".agents", "skills", "nofm", "SKILL.md"), "no front matter\n")
	elsewhere := t.TempDir()
	skill(t, elsewhere, "outside", "")
	link(t, filepath.Join(elsewhere, "outside"), filepath.Join(top, ".agents", "skills", "linkedskill"))
	write(t, filepath.Join(elsewhere, "file.md"), "---\ndescription: x\n---\n")
	write(t, filepath.Join(top, ".agents", "skills", "linkedfile", "README"), "")
	link(t, filepath.Join(elsewhere, "file.md"), filepath.Join(top, ".agents", "skills", "linkedfile", "SKILL.md"))
	link(t, elsewhere, filepath.Join(deeper, ".agents")) // a linked root
	write(t, filepath.Join(codexHome, "config.toml"), "# mine\n[[skills.config]]\nname = \"everyday\"\nenabled = false\n\n[[skills.config]]\npath = \""+
		filepath.Join(top, ".codex", "skills", "codexonly", "SKILL.md")+"\"\nenabled = false\n")

	got, err := Codex{}.List(context.Background(), deeper)
	if err != nil {
		t.Fatal(err)
	}
	want := "user mine on|system imagegen on|shared everyday off everywhere|project codexonly off|shared near on|shared linkedskill on linked|shared notes on"
	if g := listed(got.Skills); g != want {
		t.Errorf("skills:\n%s\nwant\n%s", g, want)
	}
	if !got.ReadsShared || got.NoSwitch != "" {
		t.Errorf("reads shared %v, no switch %q", got.ReadsShared, got.NoSwitch)
	}
	shared := Codex{}.Shared(context.Background(), deeper)
	if len(shared) != 4 {
		t.Errorf("shared: %s", listed(shared))
	}

	// Outside git, only the folder's own.
	loose, _ := filepath.EvalSymlinks(t.TempDir())
	skill(t, filepath.Join(loose, "a", ".agents", "skills"), "parent", "")
	skill(t, filepath.Join(loose, "a", "b", ".agents", "skills"), "own", "")
	got, _ = Codex{}.List(context.Background(), filepath.Join(loose, "a", "b"))
	if g := listed(got.Skills); !strings.HasSuffix(g, "shared own on") || strings.Contains(g, "parent") {
		t.Errorf("outside git: %s", g)
	}

	// A config.toml that doesn't read: no switches.
	write(t, filepath.Join(codexHome, "config.toml"), "[[skills.config]\n")
	if got, _ := (Codex{}).List(context.Background(), deeper); got.NoSwitch == "" {
		t.Error("a broken config.toml: switches offered")
	}
}

// Only your skills and the project's .codex/skills go to the Trash here.
func TestTrash(t *testing.T) {
	codexHome, _, top, deeper := setup(t)
	skill(t, filepath.Join(codexHome, "skills", ".system"), "imagegen", "")
	skill(t, filepath.Join(top, ".agents", "skills"), "shared", "")
	ctx := context.Background()
	for _, bad := range []string{
		filepath.Join(codexHome, "skills", ".system", "imagegen"),
		filepath.Join(top, ".agents", "skills", "shared"),
		filepath.Join(top, ".codex", "skills", "missing"),
	} {
		if err := (Codex{}).Trash(ctx, deeper, bad); err == nil {
			t.Errorf("trashed %s", bad)
		}
	}
}
