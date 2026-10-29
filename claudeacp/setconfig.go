package claudeacp

import (
	"context"
	"errors"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// SetSessionMode switches a session's permission mode.
func (a *agent) SetSessionMode(ctx context.Context, req *acp.SetSessionModeRequest) (*acp.SetSessionModeResponse, error) {
	s, err := a.session(req.SessionID)
	if err != nil {
		return nil, err
	}
	if err := s.setMode(ctx, string(req.ModeID)); err != nil {
		return nil, err
	}
	return &acp.SetSessionModeResponse{}, nil
}

// SetSessionConfigOption sets one of a session's options and answers
// with the whole set: a new model may bring other effort levels, or none.
func (a *agent) SetSessionConfigOption(ctx context.Context, req *acp.SetSessionConfigOptionRequest) (*acp.SetSessionConfigOptionResponse, error) {
	s, err := a.session(req.SessionID)
	if err != nil {
		return nil, err
	}
	var value string
	switch {
	case req.ValueID != nil:
		value = string(req.ValueID.Value)
	case req.Boolean != nil:
		value = map[bool]string{true: "on", false: "off"}[req.Boolean.Value]
	default:
		return nil, invalidParams("option %q: a value of a type the agent doesn't take", req.ConfigID)
	}
	switch id := string(req.ConfigID); id {
	case optMode:
		err = s.setMode(ctx, value)
	case optModel:
		err = s.setModel(ctx, value)
	case optEffort, optFast, optAgent:
		err = s.setFlag(ctx, id, value)
	default:
		err = invalidParams("no config option %q", id)
	}
	if err != nil {
		return nil, err
	}
	s.cfg.mu.Lock()
	defer s.cfg.mu.Unlock()
	return &acp.SetSessionConfigOptionResponse{ConfigOptions: s.cfg.optionsLocked()}, nil
}

// setMode switches claude's permission mode. A claude that refuses to
// bypass permissions (it started without leave to) no longer offers it.
func (s *session) setMode(ctx context.Context, mode string) error {
	s.setting.Lock()
	defer s.setting.Unlock()
	c := &s.cfg
	c.mu.Lock()
	offered := slices.ContainsFunc(c.modesLocked(), func(m acp.SessionMode) bool { return string(m.ID) == mode })
	same := mode == c.mode
	c.mu.Unlock()
	switch {
	case !offered:
		return invalidParams("no mode %q in this session", mode)
	case same:
		return nil
	}
	if err := s.cs.SetPermissionMode(ctx, claudeagent.PermissionMode(mode)); err != nil {
		if ce := (*claudeagent.ControlError)(nil); errors.As(err, &ce) && ce.Code == "bypass_disabled" {
			c.mu.Lock()
			c.bypass = false
			c.mu.Unlock()
			s.sendOptions()
			return invalidParams("Bypass permissions isn't available in this session")
		}
		return refused("the mode", err)
	}
	s.modeChanged(mode)
	return nil
}

// setModel switches claude's model. An effort the new model doesn't have
// goes back to the default.
func (s *session) setModel(ctx context.Context, value string) error {
	s.setting.Lock()
	defer s.setting.Unlock()
	c := &s.cfg
	c.mu.Lock()
	v, ok := c.lookup(value, c.model, true)
	same := v == c.model
	c.mu.Unlock()
	switch {
	case !ok:
		return invalidParams("no model %q in this session", value)
	case same:
		return nil
	}
	model := v
	if v == defaultValue {
		model = "" // claude's default model
	}
	if err := s.cs.SetModel(ctx, model); err != nil {
		return refused("the model", err)
	}
	c.mu.Lock()
	c.model = v
	m := c.modelInfo()
	unpin := c.effort != defaultValue && (m == nil || !m.SupportsEffort || !slices.Contains(m.SupportedEffortLevels, c.effort))
	if unpin {
		c.effort = defaultValue
	}
	c.mu.Unlock()
	// Last, as claude-agent-acp asks, so the change's own requests come first.
	defer s.seedWindow(ctx, 200_000)
	if unpin {
		if err := s.cs.ApplyFlagSettings(ctx, s.effortSettings(defaultValue)); err != nil {
			s.log.Info("putting the effort back to the default", "err", err)
		}
	}
	return nil
}

// setFlag sets the effort, fast mode or the agent, each a flag setting of
// claude's. The option must be offered, and the value one of its own.
func (s *session) setFlag(ctx context.Context, id, value string) error {
	s.setting.Lock()
	defer s.setting.Unlock()
	c := &s.cfg
	c.mu.Lock()
	i := slices.IndexFunc(c.optionsLocked(), func(o acp.SessionConfigOption) bool { return string(o.ID) == id })
	var valid, same bool
	if i >= 0 {
		switch id {
		case optEffort:
			m := c.modelInfo()
			valid, same = value == defaultValue || slices.Contains(m.SupportedEffortLevels, value), value == c.effort
		case optFast:
			valid, same = value == "on" || value == "off", (value == "on") == c.fast
		case optAgent:
			valid = value == defaultValue || slices.ContainsFunc(c.agents, func(a claudeagent.AgentInfo) bool { return a.Name == value })
			same = value == c.agent
		}
	}
	c.mu.Unlock()
	switch {
	case i < 0:
		return invalidParams("no config option %q in this session", id)
	case !valid:
		return invalidParams("no value %q for option %q", value, id)
	case same:
		return nil
	}
	var settings map[string]any
	switch id {
	case optEffort:
		settings = s.effortSettings(value)
	case optFast:
		settings = map[string]any{"fastMode": value == "on"}
	case optAgent:
		settings = map[string]any{"agent": orNull(value)}
	}
	if err := s.cs.ApplyFlagSettings(ctx, settings); err != nil {
		return refused("the "+id, err)
	}
	c.mu.Lock()
	switch id {
	case optEffort:
		c.effort = value
	case optFast:
		c.fast = value == "on"
	case optAgent:
		c.agent = value
	}
	c.mu.Unlock()
	return nil
}

// effortSettings are the flag settings for an effort level. They carry
// ultracode when the session's settings turned it on: since claude
// 2.1.284 an effort change without it turns ultracode off (docs/facts,
// Ultracode).
func (s *session) effortSettings(level string) map[string]any {
	settings := map[string]any{"effortLevel": orNull(level)}
	s.cfg.mu.Lock()
	if s.cfg.ultracode {
		settings["ultracode"] = true
	}
	s.cfg.mu.Unlock()
	return settings
}

// orNull is a value for claude's settings: null for the default, which
// leaves the choice to claude.
func orNull(v string) any {
	if v == defaultValue {
		return nil
	}
	return v
}

// refused is the error for a change claude didn't make.
func refused(what string, err error) error {
	if errors.Is(err, claudeagent.ErrClosed) {
		return errEnded
	}
	return &acp.Error{Code: acp.ErrorCodeInternalError, Message: "Claude didn't change " + what + ": " + err.Error()}
}
