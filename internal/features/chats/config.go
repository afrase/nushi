package chats

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"maps"
	"slices"
	"strconv"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// legacyMode is the option made from an agent's legacy ACP modes.
const legacyMode = "legacy:mode"

// Remembered keeps what the user last picked for each agent: the mode, and
// the other options (the model, the effort, ...) by option ID.
type Remembered interface {
	Mode(agent string) string
	SetMode(agent, mode string) error
	Picks(agent string) map[string]string
	SetPick(agent, id, value string) error
}

// configFrom turns the agent's config options and legacy modes into options.
// An agent that publishes its mode both ways (claude-agent-acp does) gets one
// mode option: the config option.
func (c *chat) configFrom(opts []acp.SessionConfigOption, modes *acp.SessionModeState) []model.ConfigOption {
	out := []model.ConfigOption{}
	for _, o := range opts {
		co := configOption(o)
		for i, v := range co.Values {
			co.Values[i].Default = c.dialect.Default != nil && c.dialect.Default(co, v)
		}
		out = append(out, co)
	}
	if c.dialect.UltracodeMeta != nil {
		out = append(out, c.ultracodeOption())
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
	switch {
	case o.Select != nil: // its values are a list, or groups of them
		co.Current = string(o.Select.CurrentValue)
		for _, v := range o.Select.Options.Ungrouped {
			co.Values = append(co.Values, configValue(v, ""))
		}
		for _, g := range o.Select.Options.Grouped {
			for _, v := range g.Options {
				co.Values = append(co.Values, configValue(v, g.Name))
			}
		}
	case o.Boolean != nil:
		co.Current = strconv.FormatBool(o.Boolean.CurrentValue)
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

// ultracodeID is the chat's Ultracode option, Nushi's own: the daemon
// keeps it, and the agent gets it in its sessions' _meta.
const ultracodeID = "nushi:ultracode"

func (c *chat) ultracodeOption() model.ConfigOption {
	return model.ConfigOption{ID: ultracodeID, Name: "Ultracode", Category: "ultracode", Type: "boolean",
		Current:     strconv.FormatBool(c.ultracode.Load()),
		Description: "Standing multi-agent workflows on every task (Claude Code's ultracode); changing it restarts the chat's agent"}
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
// agent accepts, new chats with this agent start in it; any other option
// is one of the chat's picks, and new chats with this agent start on it too.
func (s *Service) SetConfig(ctx context.Context, chatID, id, value string) error {
	c, err := s.chat(chatID)
	if err == nil && id == ultracodeID {
		return s.setUltracode(ctx, c, value == "true")
	}
	if err == nil {
		err = s.awake(ctx, c)
	}
	if err != nil {
		return err
	}
	c.mu.Lock()
	agent, sid, reopening := c.agent, c.sid, c.reopeningLocked()
	c.mu.Unlock()
	switch {
	case reopening:
		return errors.New("the chat is reopening or moving; try again in a moment")
	case agent == nil:
		return errors.New("the agent isn't running")
	}
	if err := c.setConfig(ctx, agent, sid, id, value); err != nil {
		return err
	}
	c.mu.Lock()
	isMode := modeIndex(c.config) >= 0 && c.config[modeIndex(c.config)].ID == id
	c.mu.Unlock()
	if isMode {
		return s.remembered.SetMode(c.kind.Name, value)
	}
	c.mu.Lock()
	c.saveLocked(func(s *model.Session) { s.Picks = withPick(s.Picks, id, value) })
	c.mu.Unlock()
	return s.remembered.SetPick(c.kind.Name, id, value)
}

// withPick is picks with id set to value: a new map, so the session's
// stays as it was until it is saved.
func withPick(picks map[string]string, id, value string) map[string]string {
	out := maps.Clone(picks)
	if out == nil {
		out = map[string]string{}
	}
	out[id] = value
	return out
}

// setConfig asks agent to change an option of session sid. The lock isn't
// held while the agent answers, since its updates need it; an answer for a
// session the chat no longer has is dropped.
func (c *chat) setConfig(ctx context.Context, agent Agent, sid, id, value string) error {
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
		if _, err := agent.SetSessionMode(ctx, &acp.SetSessionModeRequest{SessionID: acp.SessionID(sid), ModeID: acp.SessionModeID(value)}); err != nil {
			return err
		}
	case opt.Type == "boolean":
		resp, err := agent.SetSessionConfigOption(ctx, &acp.SetSessionConfigOptionRequest{SessionID: acp.SessionID(sid),
			ConfigID: acp.SessionConfigID(id), Boolean: &acp.SetSessionConfigOptionRequestBoolean{Value: value == "true"}})
		if err != nil {
			return err
		}
		updated = resp.ConfigOptions
	default:
		resp, err := agent.SetSessionConfigOption(ctx, &acp.SetSessionConfigOptionRequest{SessionID: acp.SessionID(sid),
			ConfigID: acp.SessionConfigID(id), ValueID: &acp.SetSessionConfigOptionRequestValueID{Value: acp.SessionConfigValueID(value)}})
		if err != nil {
			return err
		}
		updated = resp.ConfigOptions
	}

	c.mu.Lock()
	defer c.mu.Unlock()
	if c.agent != agent || c.sid != sid {
		return nil
	}
	if updated != nil {
		c.replaceConfigLocked(updated)
	} else if i := slices.IndexFunc(c.config, func(o model.ConfigOption) bool { return o.ID == id }); i >= 0 {
		c.config[i].Current = value
	}
	c.configChangedLocked()
	return nil
}

// configChangedLocked publishes the chat's options, and stores its mode once
// the chat is stored. Only a change the agent reports or the user makes is
// the chat's mode: a new session's default isn't. The picks follow what the
// agent says an option they have is on (its own /model, a fallback it made
// for the session), except while they're being put back on a session.
func (c *chat) configChangedLocked() {
	c.emitLocked(model.Event{ChatID: c.id, Config: slices.Clone(c.config)})
	if c.session.ID != "" {
		c.saveLocked(func(s *model.Session) {
			c.modeLocked(s)
			if c.agent != nil && !c.reapplying { // not a replay's, nor before reapply
				s.Picks = c.followedLocked(s.Picks)
			}
		})
	}
}

// followedLocked is picks with each option the agent still has at its
// current value: a new map, or picks itself when nothing changed.
func (c *chat) followedLocked(picks map[string]string) map[string]string {
	var out map[string]string
	for id, value := range picks {
		if i := slices.IndexFunc(c.config, func(o model.ConfigOption) bool { return o.ID == id }); i >= 0 && c.config[i].Current != value {
			if out == nil {
				out = maps.Clone(picks)
			}
			out[id] = c.config[i].Current
		}
	}
	if out == nil {
		return picks
	}
	return out
}

// modeLocked sets a session's mode to the chat's mode option's.
func (c *chat) modeLocked(s *model.Session) {
	if i := modeIndex(c.config); i >= 0 {
		s.Mode = c.config[i].Current
	}
}

// replaceConfigLocked takes a new set of config options from the agent,
// keeping the legacy mode unless a mode option came with them.
func (c *chat) replaceConfigLocked(opts []acp.SessionConfigOption) {
	out := c.configFrom(opts, nil)
	if i := modeIndex(c.config); i >= 0 && c.config[i].ID == legacyMode && modeIndex(out) < 0 {
		out = append(out, c.config[i])
	}
	c.config = out
}

// reapply puts session sid, just opened on agent, back on picks (the
// chat's, or for a new chat those last picked for its agent), then on mode
// (see startMode); the chat keeps the picks the agent still offers. Until
// then (from useLocked on) what the agent reports doesn't move the picks.
func (c *chat) reapply(ctx context.Context, agent Agent, sid, mode string, picks map[string]string) error {
	kept := c.applyPicks(ctx, agent, sid, picks)
	c.mu.Lock()
	c.saveLocked(func(s *model.Session) { s.Picks = kept })
	c.mu.Unlock()
	err := c.startMode(ctx, agent, sid, mode)
	c.mu.Lock()
	c.reapplying = false
	c.mu.Unlock()
	return err
}

// applyPicks sets each of picks the agent offers on session sid, the model
// first, since the effort's values depend on it, then the others in the
// agent's order. A value set already isn't set again (an agent that keeps
// them in its sessions is left alone). One the agent no longer offers (a
// retired model) is left out of what it returns, and logged; one it fails
// to set is kept for the next time.
func (c *chat) applyPicks(ctx context.Context, agent Agent, sid string, picks map[string]string) map[string]string {
	c.mu.Lock()
	rank := func(id string) int {
		i := slices.IndexFunc(c.config, func(o model.ConfigOption) bool { return o.ID == id })
		switch {
		case i < 0:
			return len(c.config)
		case c.config[i].Category == "model":
			return -1
		}
		return i
	}
	ids := slices.Sorted(maps.Keys(picks))
	slices.SortStableFunc(ids, func(a, b string) int { return cmp.Compare(rank(a), rank(b)) })
	c.mu.Unlock()
	var kept map[string]string
	for _, id := range ids {
		value := picks[id]
		c.mu.Lock()
		i := slices.IndexFunc(c.config, func(o model.ConfigOption) bool { return o.ID == id })
		offered := i >= 0 && (c.config[i].Type == "boolean" || slices.ContainsFunc(c.config[i].Values, func(v model.ConfigValue) bool { return v.Value == value }))
		set := offered && c.config[i].Current != value
		c.mu.Unlock()
		if !offered {
			c.log().Info("a picked option dropped: the agent doesn't offer it", "option", id, "value", value)
			continue
		}
		if set {
			if err := c.setConfig(ctx, agent, sid, id, value); err != nil {
				c.log().Warn("putting a picked option back", "option", id, "value", value, "err", err)
			}
		}
		kept = withPick(kept, id, value)
	}
	return kept
}

// startMode switches session sid, just opened on agent, to mode (the one
// last picked for its agent, or the chat's), if the agent offers it.
func (c *chat) startMode(ctx context.Context, agent Agent, sid, mode string) error {
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
	return c.setConfig(ctx, agent, sid, id, mode)
}

// setUltracode turns a chat's Ultracode on or off: kept with the chat,
// and given to the agent when its session next opens. An agent running
// is put to sleep and woken, so the session opens again now (model and
// effort kept, as after any sleep); only while the chat is idle, since
// that ends side chats and would stop a turn or a background task.
func (s *Service) setUltracode(ctx context.Context, c *chat, on bool) error {
	c.mu.Lock()
	switch {
	case c.dialect.UltracodeMeta == nil:
		c.mu.Unlock()
		return errors.New("the agent has no ultracode")
	case c.ultracode.Load() == on:
		c.mu.Unlock()
		return nil
	case c.parent != nil:
		c.mu.Unlock()
		return errors.New("a side chat has its chat's ultracode")
	}
	running := c.agent != nil
	if running && !c.idleLocked(0) {
		c.mu.Unlock()
		return errors.New("Ultracode changes once the agent is done: no turn, background task or side chat running")
	}
	c.ultracode.Store(on)
	c.saveLocked(func(s *model.Session) { s.Ultracode = on })
	if i := slices.IndexFunc(c.config, func(o model.ConfigOption) bool { return o.ID == ultracodeID }); i >= 0 {
		c.config[i] = c.ultracodeOption()
	}
	c.configChangedLocked()
	c.logLocked().Info("chat ultracode", "on", on, "reopen", running)
	c.mu.Unlock()
	if !running {
		return nil
	}
	if err := s.Sleep(c.id); err != nil {
		return err
	}
	return s.awake(ctx, c)
}
