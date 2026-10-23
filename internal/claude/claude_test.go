package claude

import (
	"testing"

	"github.com/afrase/nushi/internal/model"
)

func TestForkTitlesAreIgnored(t *testing.T) {
	for title, want := range map[string]bool{"A (fork)": true, "A (fork) (fork)": true, "A": false, "A b": false, "B (fork)": false} {
		if ForkTitle(title, "A") != want {
			t.Errorf("ForkTitle(%q) != %v", title, want)
		}
	}
}

func TestFormsAndModels(t *testing.T) {
	color := model.Field{ID: "color", Options: []model.Option{{ID: "red"}}}
	if !Other(model.Field{ID: "color_custom"}, color) || Other(model.Field{ID: "fruit"}, color) {
		t.Error("Other pairs the wrong fields")
	}
	models := model.ConfigOption{Category: "model"}
	if !Default(models, model.ConfigValue{Name: "Default (recommended)"}) || Default(models, model.ConfigValue{Name: "Opus"}) ||
		Default(model.ConfigOption{Category: "mode"}, model.ConfigValue{Name: "Default"}) {
		t.Error("Default picks the wrong values")
	}
}
