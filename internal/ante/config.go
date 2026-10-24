package ante

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"

	"github.com/afrase/nushi/acp"
)

// provider is one of Ante's catalog's providers (`ante catalog`): only its
// models, which the protocol doesn't carry.
type provider struct {
	ID     string `json:"id"`
	Models []struct {
		ID          string   `json:"id"`
		Description string   `json:"description"`
		Effort      string   `json:"effort"`
		Supported   []string `json:"supported_efforts"`
	} `json:"preferred_models"`
}

// ladder is Ante's effort scale; a model that reasons takes any of it
// (Ante rounds down to what the model has) unless it names its own.
var ladder = []string{"min", "low", "medium", "high", "xhigh", "max"}

var modeNames = map[string][2]string{
	"strict": {"Strict", "Asks before a tool call unless it's provably safe"},
	"auto":   {"Auto", "Runs a tool call unless it's provably dangerous"},
	"yolo":   {"Yolo", "Never asks, deny rules included"},
}

func modes(current string) *acp.SessionModeState {
	m := &acp.SessionModeState{CurrentModeID: acp.SessionModeID(current)}
	for _, id := range []string{"strict", "auto", "yolo"} {
		m.AvailableModes = append(m.AvailableModes, acp.SessionMode{ID: acp.SessionModeID(id), Name: modeNames[id][0], Description: modeNames[id][1]})
	}
	return m
}

// options are the session's model (the provider's models, from Ante's
// catalog) and, when the model reasons, its effort.
func (b *bridge) options(in info) []acp.SessionConfigOption {
	type value struct {
		Value string `json:"value"`
		Name  string `json:"name"`
	}
	var models []value
	efforts := in.Model.Supported
	for _, p := range b.catalog() {
		if p.ID != in.Provider.ID {
			continue
		}
		for _, m := range p.Models {
			models = append(models, value{m.ID, cmp(m.Description, m.ID)})
			if m.ID == in.Model.ID && len(efforts) == 0 {
				efforts = m.Supported
			}
		}
	}
	if !slices.ContainsFunc(models, func(v value) bool { return v.Value == in.Model.ID }) {
		models = append([]value{{in.Model.ID, in.Model.ID}}, models...)
	}
	if len(efforts) == 0 && in.Model.Effort != "" {
		efforts = ladder
	}
	option := func(id, name, category, current string, values []value) acp.SessionConfigOption {
		cur, _ := json.Marshal(current)
		opts, _ := json.Marshal(values)
		return acp.SessionConfigOption{ID: acp.SessionConfigID(id), Name: name, Category: acp.SessionConfigOptionCategory(category),
			Type: "select", CurrentValue: cur, Options: opts}
	}
	out := []acp.SessionConfigOption{option("model", "Model", "model", in.Model.ID, models)}
	if len(efforts) > 0 {
		var values []value
		for _, e := range efforts {
			values = append(values, value{e, e})
		}
		out = append(out, option("effort", "Effort", "thought_level", in.Model.Effort, values))
	}
	return out
}

func cmp(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

// configUpdates tell the client the session's mode and options as Ante
// now has them.
func (b *bridge) configUpdates(in info) []acp.SessionUpdate {
	return []acp.SessionUpdate{
		{SessionUpdate: "current_mode_update", CurrentModeUpdate: &acp.CurrentModeUpdate{CurrentModeID: acp.SessionModeID(in.PermissionMode)}},
		{SessionUpdate: "config_option_update", ConfigOptionUpdate: &acp.ConfigOptionUpdate{ConfigOptions: b.options(in)}},
	}
}

// setOption changes the model (at its catalog effort) or the effort; Ante
// takes either from the next turn on, without writing its settings.
func (s *session) setOption(ctx context.Context, id, value string) ([]acp.SessionConfigOption, error) {
	s.mu.Lock()
	model := map[string]string{"id": s.info.Model.ID}
	s.mu.Unlock()
	switch id {
	case "model":
		model["id"] = value
	case "effort":
		model["effort"] = value
	default:
		return nil, fmt.Errorf("no option %q", id)
	}
	if _, err := s.await(ctx, map[string]any{"UpdateSession": map[string]any{"model": model}}, "SessionUpdated"); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.options(s.info), nil
}

// setMode changes the permission mode, at once.
func (s *session) setMode(ctx context.Context, mode string) error {
	if _, ok := modeNames[mode]; !ok {
		return fmt.Errorf("no mode %q", mode)
	}
	_, err := s.await(ctx, map[string]any{"UpdateSession": map[string]any{"permission_mode": mode}}, "SessionUpdated")
	return err
}
