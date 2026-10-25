package pig

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/acp"
)

// state is what pig's get_state says of the session it holds.
type state struct {
	SessionID   string `json:"sessionId"`
	SessionFile string `json:"sessionFile"`
	Model       *struct {
		ID       string `json:"id"`
		Provider string `json:"provider"`
	} `json:"model"`
	ThinkingLevel string `json:"thinkingLevel"`
}

// options are the session's model (every model pig has a key for, as
// provider/id) and thinking level (the model's levels), as pig has them
// now; st is pig's state if the caller has it.
func (s *session) options(ctx context.Context, st *state) ([]acp.SessionConfigOption, error) {
	if st == nil {
		st = &state{}
		if err := s.p.call(ctx, map[string]any{"type": "get_state"}, st); err != nil {
			return nil, err
		}
	}
	var models struct {
		Models []struct {
			ID       string `json:"id"`
			Name     string `json:"name"`
			Provider string `json:"provider"`
		} `json:"models"`
	}
	var levels struct {
		Levels []string `json:"levels"`
	}
	if err := s.p.call(ctx, map[string]any{"type": "get_available_models"}, &models); err != nil {
		return nil, err
	}
	if err := s.p.call(ctx, map[string]any{"type": "get_available_thinking_levels"}, &levels); err != nil {
		return nil, err
	}
	type value struct {
		Value string `json:"value"`
		Name  string `json:"name"`
	}
	option := func(id, name, category, current string, values []value) acp.SessionConfigOption {
		cur, _ := json.Marshal(current)
		opts, _ := json.Marshal(values)
		return acp.SessionConfigOption{ID: acp.SessionConfigID(id), Name: name, Category: acp.SessionConfigOptionCategory(category),
			Type: "select", CurrentValue: cur, Options: opts}
	}
	var out []acp.SessionConfigOption
	if len(models.Models) > 0 && st.Model != nil {
		var values []value
		for _, m := range models.Models {
			values = append(values, value{m.Provider + "/" + m.ID, m.Name})
		}
		out = append(out, option("model", "Model", "model", st.Model.Provider+"/"+st.Model.ID, values))
	}
	if len(levels.Levels) > 1 {
		var values []value
		for _, l := range levels.Levels {
			values = append(values, value{l, l})
		}
		out = append(out, option("thinking", "Thinking", "thought_level", st.ThinkingLevel, values))
	}
	return out, nil
}

// setOption changes the model or the thinking level, which pig keeps in
// the session.
func (s *session) setOption(ctx context.Context, id, value string) ([]acp.SessionConfigOption, error) {
	switch id {
	case "model":
		provider, model, ok := strings.Cut(value, "/")
		if !ok {
			return nil, fmt.Errorf("no model %q", value)
		}
		if err := s.p.call(ctx, map[string]any{"type": "set_model", "provider": provider, "modelId": model}, nil); err != nil {
			return nil, err
		}
	case "thinking":
		if err := s.p.call(ctx, map[string]any{"type": "set_thinking_level", "level": value}, nil); err != nil {
			return nil, err
		}
	default:
		return nil, fmt.Errorf("no option %q", id)
	}
	return s.options(ctx, nil)
}

// optionsChanged tells the client the session's options, which pig
// changed on its own.
//
//nolint:contextcheck // asked on the bridge's connection, after the change pig reported
func (b *bridge) optionsChanged(s *session) {
	ctx, cancel := context.WithTimeout(b.ctx, 10*time.Second)
	defer cancel()
	if opts, err := s.options(ctx, nil); err == nil {
		b.update(s.id, acp.SessionUpdate{SessionUpdate: "config_option_update", ConfigOptionUpdate: &acp.ConfigOptionUpdate{ConfigOptions: opts}})
	}
}

// usage tells the client how full the session's context is, and what it
// cost so far (pig's session stats).
//
//nolint:contextcheck // asked on the bridge's connection, after the turn that ended
func (b *bridge) usage(s *session) {
	ctx, cancel := context.WithTimeout(b.ctx, 10*time.Second)
	defer cancel()
	var st struct {
		Cost    float64 `json:"cost"`
		Context struct {
			Tokens *int64 `json:"tokens"`
			Window int64  `json:"contextWindow"`
		} `json:"contextUsage"`
	}
	if s.p.call(ctx, map[string]any{"type": "get_session_stats"}, &st) != nil || st.Context.Window == 0 {
		return
	}
	s.mu.Lock()
	used := s.estimate // PiG has no count right after a compaction
	s.mu.Unlock()
	if st.Context.Tokens != nil {
		used = *st.Context.Tokens
	} else if used == 0 {
		return
	}
	b.update(s.id, acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{
		Used: used, Size: st.Context.Window, Cost: &acp.Cost{Amount: st.Cost, Currency: "USD"}}})
}

// commands tells the client the session's slash commands: the bridge's
// own (ownCommands), then extensions', prompt templates' and skills' (the
// rest of pig's own, the terminal's, aren't commands in RPC mode).
//
//nolint:contextcheck // asked on the bridge's connection, after the session's answer
func (b *bridge) commands(s *session) {
	ctx, cancel := context.WithTimeout(b.ctx, 10*time.Second)
	defer cancel()
	var r struct {
		Commands []struct {
			Name        string `json:"name"`
			Description string `json:"description"`
		} `json:"commands"`
	}
	if s.p.call(ctx, map[string]any{"type": "get_commands"}, &r) != nil {
		return
	}
	cmds := slices.Clone(ownCommands)
	for _, c := range r.Commands {
		if _, _, own := ownCommand("/" + c.Name); !own {
			cmds = append(cmds, acp.AvailableCommand{Name: c.Name, Description: c.Description})
		}
	}
	b.update(s.id, acp.SessionUpdate{SessionUpdate: "available_commands_update", AvailableCommandsUpdate: &acp.AvailableCommandsUpdate{AvailableCommands: cmds}})
}
