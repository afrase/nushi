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

func TestSubagentCall(t *testing.T) {
	it := model.Item{}
	ToolCall(&it, map[string]any{"claudeCode": map[string]any{"toolName": "Agent"}}, nil)
	ToolCall(&it, nil, []byte(`{"subagent_type":"Explore","prompt":"List the files","model":"haiku"}`))
	ToolCall(&it, nil, []byte(`{"subagent_type":"Explore","prompt":"List the files","model":"haiku","effort":"low"}`))
	ToolCall(&it, map[string]any{"claudeCode": map[string]any{"toolResponse": map[string]any{"resolvedModel": "claude-haiku-5-5"}}},
		[]byte(`{}`)) // a later update without the input keeps it
	if it.Agent != "Explore" || it.Prompt != "List the files" || it.Model != "haiku" || it.Effort != "low" || it.RanModel != "Haiku 5.5" {
		t.Errorf("got %+v", it)
	}
	for id, want := range map[string]string{"claude-fable-5-1[1m]": "Fable 5.1", "claude-haiku-4-5-20251001": "Haiku 4.5", "gpt": "Gpt"} {
		if got := modelName(id); got != want {
			t.Errorf("modelName(%q) = %q", id, got)
		}
	}
	if !ReportElsewhere(`This agent's report was delivered to you as a message from "a5" (its SubagentHandback call).`) || ReportElsewhere("Found 2 files") {
		t.Error("ReportElsewhere misreads the call's output")
	}
}
