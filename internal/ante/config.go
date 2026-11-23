package ante

import (
	"cmp"
	"context"
	"fmt"
	"slices"

	acp "github.com/afrase/acp-go/unstable"
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

// permissionMode is one of Ante's permission modes: its id, its name and
// what it does.
type permissionMode struct{ id, name, about string }

// modeNames are Ante's permission modes, in order.
var modeNames = []permissionMode{
	{"strict", "Strict", "Asks before a tool call unless it's provably safe"},
	{"auto", "Auto", "Runs a tool call unless it's provably dangerous"},
	{"yolo", "Yolo", "Never asks, deny rules included"},
}

// options are the session's model (the provider's models, from Ante's
// catalog), when the model reasons its effort, and its permission mode:
// a config option of category mode, as other agents give theirs (ADR
// 0030), not ACP's legacy modes.
func (b *bridge) options(in info) []acp.SessionConfigOption {
	type value struct {
		Value string `json:"value"`
		Name  string `json:"name"`
		About string `json:"description"`
	}
	var models []value
	for _, p := range b.catalog() {
		if p.ID != in.Provider.ID {
			continue
		}
		for _, m := range p.Models {
			models = append(models, value{m.ID, cmp.Or(m.Description, m.ID), ""})
		}
	}
	if !slices.ContainsFunc(models, func(v value) bool { return v.Value == in.Model.ID }) {
		models = append([]value{{in.Model.ID, in.Model.ID, ""}}, models...)
	}
	efforts := b.efforts(in)
	option := func(id, name, category, current string, values []value) acp.SessionConfigOption {
		var opts []acp.SessionConfigSelectOption
		for _, v := range values {
			opts = append(opts, acp.SessionConfigSelectOption{Value: acp.SessionConfigValueID(v.Value), Name: v.Name, Description: v.About})
		}
		return acp.SessionConfigOption{ID: acp.SessionConfigID(id), Name: name, Category: acp.SessionConfigOptionCategory(category),
			Select: &acp.SessionConfigSelect{CurrentValue: acp.SessionConfigValueID(current), Options: acp.SessionConfigSelectOptions{Ungrouped: opts}}}
	}
	out := []acp.SessionConfigOption{option("model", "Model", "model", in.Model.ID, models)}
	if len(efforts) > 0 {
		var values []value
		for _, e := range efforts {
			values = append(values, value{e, e, ""})
		}
		out = append(out, option("effort", "Effort", "thought_level", in.Model.Effort, values))
	}
	var modes []value
	for _, m := range modeNames {
		modes = append(modes, value{m.id, m.name, m.about})
	}
	return append(out, option("mode", "Mode", "mode", in.PermissionMode, modes))
}

// efforts are the session's model's effort levels: its own, else its
// catalog entry's, else Ante's whole ladder when it reasons at all.
func (b *bridge) efforts(in info) []string {
	efforts := in.Model.Supported
	for _, p := range b.catalog() {
		for _, m := range p.Models {
			if p.ID == in.Provider.ID && m.ID == in.Model.ID && len(efforts) == 0 {
				efforts = m.Supported
			}
		}
	}
	if len(efforts) == 0 && in.Model.Effort != "" {
		efforts = ladder
	}
	return efforts
}

// configUpdates tell the client the session's options, its mode among
// them, as Ante now has them.
func (b *bridge) configUpdates(in info) []acp.SessionUpdate {
	return []acp.SessionUpdate{{SessionUpdate: "config_option_update", ConfigOptionUpdate: &acp.ConfigOptionUpdate{ConfigOptions: b.options(in)}}}
}

// setOption changes the model (at its catalog effort) or the effort, which
// Ante takes from the next turn on, or the mode, at once; none writes
// Ante's settings.
func (s *session) setOption(ctx context.Context, id, value string) ([]acp.SessionConfigOption, error) {
	s.mu.Lock()
	model := map[string]any{"id": s.info.Model.ID}
	s.mu.Unlock()
	var err error
	switch id {
	case "model":
		model["id"] = value
		_, err = s.updateModel(ctx, model)
	case "effort":
		model["effort"] = value
		_, err = s.updateModel(ctx, model)
	case "mode":
		err = s.setMode(ctx, value)
	default:
		return nil, fmt.Errorf("no option %q", id)
	}
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.b.options(s.info), nil
}

// updateModel changes the session's model or its effort (UpdateSession),
// then asks Ante how full the context is again (ContextReport, which
// handle keeps): another model has another limit, and an image's room
// goes by it (imageRoom).
func (s *session) updateModel(ctx context.Context, model map[string]any) (event, error) {
	ev, err := s.await(ctx, map[string]any{"UpdateSession": map[string]any{"model": model}}, "SessionUpdated")
	if err != nil {
		return ev, err
	}
	_, _ = s.await(ctx, "ContextReport", "ContextReport") // the change is made; without an answer the old limit stays
	return ev, nil
}

// setMode changes the permission mode, at once.
func (s *session) setMode(ctx context.Context, mode string) error {
	if !slices.ContainsFunc(modeNames, func(m permissionMode) bool { return m.id == mode }) {
		return fmt.Errorf("no mode %q", mode)
	}
	_, err := s.await(ctx, map[string]any{"UpdateSession": map[string]any{"permission_mode": mode}}, "SessionUpdated")
	return err
}
