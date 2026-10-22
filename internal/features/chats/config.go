package chats

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// legacyMode is the option made from an agent's legacy ACP modes.
const legacyMode = "legacy:mode"

// Modes remembers the mode the user last picked for each agent.
type Modes interface {
	Mode(agent string) string
	SetMode(agent, mode string) error
}

// configFrom turns the agent's config options and legacy modes into options.
// An agent that publishes its mode both ways (claude-agent-acp does) gets one
// mode option: the config option.
func configFrom(opts []acp.SessionConfigOption, modes *acp.SessionModeState) []model.ConfigOption {
	out := []model.ConfigOption{}
	for _, o := range opts {
		out = append(out, configOption(o))
	}
	if modes != nil && modeIndex(out) < 0 {
		m := model.ConfigOption{ID: legacyMode, Name: "Mode", Category: "mode", Type: "select", Current: string(modes.CurrentModeID)}
		for _, v := range modes.AvailableModes {
			m.Values = append(m.Values, model.ConfigValue{Value: string(v.ID), Name: v.Name, Description: v.Description})
		}
		out = append(out, m)
	}
	return out
}

func configOption(o acp.SessionConfigOption) model.ConfigOption {
	co := model.ConfigOption{ID: string(o.ID), Name: o.Name, Description: o.Description, Category: string(o.Category), Type: o.Type}
	var current any
	_ = json.Unmarshal(o.CurrentValue, &current)
	if current != nil {
		co.Current = fmt.Sprint(current)
	}
	// Options are a list of values, or of groups of values.
	var entries []struct {
		acp.SessionConfigSelectOption
		Options []acp.SessionConfigSelectOption `json:"options"`
	}
	_ = json.Unmarshal(o.Options, &entries)
	for _, e := range entries {
		if e.Options == nil {
			co.Values = append(co.Values, configValue(e.SessionConfigSelectOption, ""))
		}
		for _, v := range e.Options {
			co.Values = append(co.Values, configValue(v, e.Name))
		}
	}
	return co
}

func configValue(v acp.SessionConfigSelectOption, group string) model.ConfigValue {
	return model.ConfigValue{Value: string(v.Value), Name: v.Name, Description: v.Description, Group: group}
}

// modeIndex is the index of the mode option in opts, or -1.
func modeIndex(opts []model.ConfigOption) int {
	return slices.IndexFunc(opts, func(o model.ConfigOption) bool { return o.Category == "mode" })
}

// Config returns a chat's config options.
func (s *Service) Config(chatID string) []model.ConfigOption {
	c, err := s.chat(chatID)
	if err != nil {
		return nil
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return slices.Clone(c.config)
}

// SetConfig sets one of a chat's options. When the user picks a mode the
// agent accepts, new chats with this agent start in it.
func (s *Service) SetConfig(ctx context.Context, chatID, id, value string) error {
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	if err := c.setConfig(ctx, id, value); err != nil {
		return err
	}
	c.mu.Lock()
	isMode := modeIndex(c.config) >= 0 && c.config[modeIndex(c.config)].ID == id
	c.mu.Unlock()
	if isMode {
		return s.modes.SetMode(s.agent, value)
	}
	return nil
}

// setConfig asks the agent to change an option. The lock isn't held while
// the agent answers, since its updates need it.
func (c *chat) setConfig(ctx context.Context, id, value string) error {
	c.mu.Lock()
	i := slices.IndexFunc(c.config, func(o model.ConfigOption) bool { return o.ID == id })
	var opt model.ConfigOption
	if i >= 0 {
		opt = c.config[i]
	}
	c.mu.Unlock()
	if i < 0 {
		return fmt.Errorf("the agent has no option %q", id)
	}

	var updated []acp.SessionConfigOption
	switch {
	case id == legacyMode:
		if err := c.agent.SetMode(ctx, acp.SetSessionModeRequest{SessionID: acp.SessionID(c.id), ModeID: acp.SessionModeID(value)}); err != nil {
			return err
		}
	case opt.Type == "boolean":
		resp, err := c.agent.SetConfigOption(ctx, acp.SetSessionConfigOptionRequest{SessionID: acp.SessionID(c.id),
			ConfigID: acp.SessionConfigID(id), Type: "boolean", Value: json.RawMessage(fmt.Sprint(value == "true"))})
		if err != nil {
			return err
		}
		updated = resp.ConfigOptions
	default:
		v, _ := json.Marshal(value)
		resp, err := c.agent.SetConfigOption(ctx, acp.SetSessionConfigOptionRequest{SessionID: acp.SessionID(c.id),
			ConfigID: acp.SessionConfigID(id), Value: v})
		if err != nil {
			return err
		}
		updated = resp.ConfigOptions
	}

	c.mu.Lock()
	defer c.mu.Unlock()
	if updated != nil {
		c.replaceConfigLocked(updated)
	} else if i := slices.IndexFunc(c.config, func(o model.ConfigOption) bool { return o.ID == id }); i >= 0 {
		c.config[i].Current = value
	}
	c.configChangedLocked()
	return nil
}

// configChangedLocked publishes the chat's options, and stores its mode once
// the chat is stored.
func (c *chat) configChangedLocked() {
	c.publish(model.Event{ChatID: c.id, Config: slices.Clone(c.config)})
	if c.session.ID != "" {
		c.saveLocked(nil)
	}
}

// replaceConfigLocked takes a new set of config options from the agent,
// keeping the legacy mode unless a mode option came with them.
func (c *chat) replaceConfigLocked(opts []acp.SessionConfigOption) {
	out := configFrom(opts, nil)
	if i := modeIndex(c.config); i >= 0 && c.config[i].ID == legacyMode && modeIndex(out) < 0 {
		out = append(out, c.config[i])
	}
	c.config = out
}

// startMode switches a new session to the mode last picked for its agent,
// if the agent offers it.
func (c *chat) startMode(ctx context.Context, mode string) error {
	c.mu.Lock()
	i := modeIndex(c.config)
	ok := i >= 0 && c.config[i].Current != mode &&
		slices.ContainsFunc(c.config[i].Values, func(v model.ConfigValue) bool { return v.Value == mode })
	var id string
	if ok {
		id = c.config[i].ID
	}
	c.mu.Unlock()
	if !ok {
		return nil
	}
	return c.setConfig(ctx, id, mode)
}
