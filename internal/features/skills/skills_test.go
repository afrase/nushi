package skills

import (
	"context"
	"fmt"
	"reflect"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

type fakeSource struct{ calls []string }

func (f *fakeSource) List(context.Context, string) (model.Skills, error) { return model.Skills{}, nil }
func (f *fakeSource) SetSkillOn(_ context.Context, _, source, name string, on bool) error {
	f.calls = append(f.calls, fmt.Sprintf("skill %s %s %v", source, name, on))
	return nil
}
func (f *fakeSource) SetBuiltInOn(_ context.Context, _ string, on bool) error {
	f.calls = append(f.calls, fmt.Sprintf("builtin %v", on))
	return nil
}
func (f *fakeSource) SetPluginOn(context.Context, string, string, bool) error { return nil }
func (f *fakeSource) Uninstall(context.Context, string, string) error         { return nil }
func (f *fakeSource) Trash(context.Context, string, string) error             { return nil }
func (f *fakeSource) PluginScope(string, model.Plugin) string                 { return "user" }

// A skill's switch goes by its source; a plugin's skills and a folder
// that isn't absolute are refused.
func TestSetSkillOnGoesBySource(t *testing.T) {
	src := &fakeSource{}
	svc := New(src)
	ctx := context.Background()
	for _, s := range []string{"user", "project", "builtin"} {
		if err := svc.SetSkillOn(ctx, "/f", s, "x", false); err != nil {
			t.Fatal(err)
		}
	}
	for _, s := range []string{"plugin", "other"} {
		if err := svc.SetSkillOn(ctx, "/f", s, "x", false); err == nil {
			t.Errorf("%s: not refused", s)
		}
	}
	if err := svc.SetSkillOn(ctx, "f/../g", "user", "x", false); err == nil {
		t.Error("a relative folder: not refused")
	}
	if _, err := svc.List(ctx, "rel"); err == nil {
		t.Error("listing a relative folder: not refused")
	}
	if want := []string{"skill user x false", "skill project x false", "builtin false"}; !reflect.DeepEqual(src.calls, want) {
		t.Errorf("calls = %q", src.calls)
	}
}
