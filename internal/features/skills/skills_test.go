package skills

import (
	"context"
	"fmt"
	"reflect"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

type fakeReader struct {
	list   model.Skills
	shared []model.Skill
	calls  *[]string
	name   string
}

func (f *fakeReader) List(context.Context, string) (model.Skills, error) { return f.list, nil }
func (f *fakeReader) Shared(context.Context, string) []model.Skill       { return f.shared }
func (f *fakeReader) SetSkillOn(_ context.Context, _, source, name string, on bool) error {
	*f.calls = append(*f.calls, fmt.Sprintf("%s skill %s %s %v", f.name, source, name, on))
	return nil
}
func (f *fakeReader) Trash(_ context.Context, _, path string) error {
	*f.calls = append(*f.calls, f.name+" trash "+path)
	return nil
}

type fakeClaude struct{ fakeReader }

func (f *fakeClaude) SetBuiltInOn(_ context.Context, _ string, on bool) error {
	*f.calls = append(*f.calls, fmt.Sprintf("builtin %v", on))
	return nil
}
func (f *fakeClaude) Link(_ context.Context, _, path string) error {
	*f.calls = append(*f.calls, "link "+path)
	return nil
}

// Two agents: Codex reads /r/.agents/skills/a and /r/.agents/skills/b;
// Claude has b through its link /r/.claude/skills/b.
func fakes() (*Service, *[]string) {
	calls := &[]string{}
	codex := &fakeReader{name: "codex", calls: calls,
		list: model.Skills{Skills: []model.Skill{{Name: "mine", Source: "user"}, {Name: "a", Source: "shared", Path: "/r/.agents/skills/a"}}},
		shared: []model.Skill{{Name: "a", Source: "shared", Path: "/r/.agents/skills/a", State: "off"},
			{Name: "b", Source: "shared", Path: "/r/.agents/skills/b", State: "on"}}}
	claude := &fakeClaude{fakeReader{name: "claude", calls: calls,
		list: model.Skills{Skills: []model.Skill{{Name: "b", Source: "project", Path: "/r/.claude/skills/b", Linked: "../../.agents/skills/b"},
			{Name: "own", Source: "project", Path: "/r/.claude/skills/own"}}},
		shared: []model.Skill{{Name: "b", Source: "shared", Path: "/r/.agents/skills/b", State: "on", Agents: []model.SkillAgent{{Via: "/r/.claude/skills/b"}}}}}}
	trash := func(_ context.Context, roots []string, path string) error {
		*calls = append(*calls, fmt.Sprintf("trash %s in %v", path, roots))
		return nil
	}
	return New([]string{"claude", "codex"}, map[string]Reader{"claude": claude, "codex": codex}, trash), calls
}

func show(skills []model.Skill) []string {
	var out []string
	for _, s := range skills {
		var line strings.Builder
		line.WriteString(s.Source + " " + s.Name)
		for _, a := range s.Agents {
			line.WriteString(" " + a.Agent + ":" + a.State)
			if a.Via != "" {
				line.WriteString("@" + a.Via)
			}
		}
		out = append(out, line.String())
	}
	return out
}

// An agent's list has its own skills, then every shared skill with the
// agents that load it; its own link to a shared one shows as that one.
func TestListMergesShared(t *testing.T) {
	svc, _ := fakes()
	ctx := context.Background()
	got, err := svc.List(ctx, "claude", "/r")
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"project own", "shared a codex:off", "shared b claude:on@/r/.claude/skills/b codex:on"}
	if !reflect.DeepEqual(show(got.Skills), want) {
		t.Errorf("claude's:\n%q\nwant\n%q", show(got.Skills), want)
	}
	got, _ = svc.List(ctx, "codex", "/r")
	if want := []string{"user mine", "shared a codex:off", "shared b claude:on@/r/.claude/skills/b codex:on"}; !reflect.DeepEqual(show(got.Skills), want) {
		t.Errorf("codex's: %q", show(got.Skills))
	}
	if got, err := svc.List(ctx, "gemini", "/r"); err != nil || got.NoSkills == "" {
		t.Errorf("an agent without a reader: %+v %v", got, err)
	}
	if _, err := svc.List(ctx, "claude", "rel"); err == nil {
		t.Error("a relative folder: not refused")
	}
}

// A switch goes to the agent's reader by source; a plugin's and an
// unknown source are refused; built in only for an agent that has them.
func TestSetSkillOnGoesBySource(t *testing.T) {
	svc, calls := fakes()
	ctx := context.Background()
	for _, c := range [][2]string{{"claude", "user"}, {"", "project"}, {"codex", "shared"}, {"claude", "builtin"}} {
		if err := svc.SetSkillOn(ctx, c[0], "/f", c[1], "x", false); err != nil {
			t.Fatal(err)
		}
	}
	for _, c := range [][2]string{{"claude", "plugin"}, {"claude", "other"}, {"codex", "builtin"}} {
		if err := svc.SetSkillOn(ctx, c[0], "/f", c[1], "x", false); err == nil {
			t.Errorf("%v: not refused", c)
		}
	}
	if err := svc.SetSkillOn(ctx, "claude", "f/../g", "user", "x", false); err == nil {
		t.Error("a relative folder: not refused")
	}
	if want := []string{"claude skill user x false", "claude skill project x false", "codex skill shared x false", "builtin false"}; !reflect.DeepEqual(*calls, want) {
		t.Errorf("calls = %q", *calls)
	}
}

// Deleting a shared skill takes the links to it too, then its folder;
// an agent's own goes through its reader. Link only for a listed shared
// skill and an agent that links.
func TestTrashAndLink(t *testing.T) {
	svc, calls := fakes()
	ctx := context.Background()
	if err := svc.Trash(ctx, "codex", "/r", "/r/.agents/skills/b"); err != nil {
		t.Fatal(err)
	}
	if err := svc.Trash(ctx, "claude", "/r", "/r/.claude/skills/own"); err != nil {
		t.Fatal(err)
	}
	if err := svc.Link(ctx, "claude", "/r", "/r/.agents/skills/a"); err != nil {
		t.Fatal(err)
	}
	for _, c := range [][2]string{{"claude", "/r/.agents/skills/zz"}, {"codex", "/r/.agents/skills/a"}} {
		if err := svc.Link(ctx, c[0], "/r", c[1]); err == nil {
			t.Errorf("linked %v", c)
		}
	}
	want := []string{"claude trash /r/.claude/skills/b", "trash /r/.agents/skills/b in [/r/.agents/skills]",
		"claude trash /r/.claude/skills/own", "link /r/.agents/skills/a"}
	if !reflect.DeepEqual(*calls, want) {
		t.Errorf("calls:\n%q\nwant\n%q", *calls, want)
	}
}
