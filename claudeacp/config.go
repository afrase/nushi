package claudeacp

import (
	"cmp"
	"encoding/json"
	"slices"
	"strings"
	"sync"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// A session's modes and config options: the permission mode, as ACP's
// legacy modes and as the "mode" option; the model; its effort and fast
// mode, when the model has them; and the custom agent, when there are
// some. They come from claude's answer to initialize, change when the
// client sets them, and follow claude when it changes one itself (a
// /model typed as a prompt, a plan approved).

// The config options' ids, which clients key on.
const (
	optMode   = "mode"
	optModel  = "model"
	optEffort = "effort"
	optFast   = "fast"
	optAgent  = "agent"
)

// defaultValue is the value of the model, effort and agent options that
// leaves the choice to claude's settings.
const defaultValue = "default"

// config is a session's modes and options as the client was last told.
type config struct {
	mu        sync.Mutex
	mode      string
	bypass    bool // bypassPermissions may be picked
	models    []claudeagent.ModelInfo
	model     string // a value of models
	effort    string // "default" or a level of the model's
	fast      bool
	agents    []claudeagent.AgentInfo // the custom ones
	agent     string                  // "default" or a name of agents
	ultracode bool                    // the session's settings turned ultracode on
	booleans  bool                    // the client takes boolean options
}

// builtinAgents are claude's own agents, which aren't offered as the
// session's main agent.
var builtinAgents = []string{"claude", "general-purpose", "Explore", "Plan", "statusline-setup", defaultValue}

// init sets c as claude starts the session: as its answer to initialize
// (ir) says, else as the session asked (o), else claude's defaults.
func (c *config) init(o claudeagent.Options, ir *claudeagent.InitResponse, booleans bool) {
	var set struct {
		Ultracode   bool   `json:"ultracode"`
		EffortLevel string `json:"effortLevel"`
		FastMode    bool   `json:"fastMode"`
		Agent       string `json:"agent"`
	}
	if len(o.Settings) > 0 && o.Settings[0] == '{' { // else a settings file's path, which claude reads
		_ = json.Unmarshal(o.Settings, &set)
	}
	if ir == nil {
		ir = &claudeagent.InitResponse{}
	}
	c.mode = cmp.Or(ir.CurrentPermissionMode, string(o.PermissionMode), string(claudeagent.PermissionDefault))
	c.bypass, c.models, c.booleans = o.AllowBypass, ir.Models, booleans
	c.effort, c.agent = cmp.Or(set.EffortLevel, defaultValue), cmp.Or(set.Agent, defaultValue)
	c.fast = ir.FastModeState == "on" || ir.FastModeState == "" && set.FastMode
	c.ultracode = set.Ultracode
	c.model = c.resolve(cmp.Or(ir.CurrentModel, o.Model), "")
	for _, a := range ir.Agents {
		if !slices.Contains(builtinAgents, a.Name) {
			c.agents = append(c.agents, a)
		}
	}
	if m := c.modelInfo(); m != nil && c.effort != defaultValue && !slices.Contains(m.SupportedEffortLevels, c.effort) {
		c.effort = defaultValue
	}
}

// resolve is the model option's value for id, a value or a model's id
// (claude-opus-5-5): current when that is id's already, else the value
// or the model it names, else the value id contains ("opus"); failing
// all, current, else the default.
func (c *config) resolve(id, current string) string {
	if v, ok := c.lookup(id, current, true); ok {
		return v
	}
	if len(c.models) == 0 {
		return cmp.Or(current, id)
	}
	return cmp.Or(current, c.models[0].Value)
}

// lookup is the model option's value that id names, as resolve finds it
// (by a value id contains only when loose); ok is false when none does.
func (c *config) lookup(id, current string, loose bool) (string, bool) {
	if id == "" {
		return "", false
	}
	for _, m := range c.models {
		if m.Value == current && (m.Value == id || m.ResolvedModel == id) {
			return current, true
		}
	}
	for _, m := range c.models {
		if m.Value == id {
			return m.Value, true
		}
	}
	for _, m := range c.models {
		if m.ResolvedModel == id {
			return m.Value, true
		}
	}
	if !loose {
		return "", false
	}
	best := ""
	for _, m := range c.models {
		if m.Value != defaultValue && strings.Contains(strings.ToLower(id), strings.ToLower(m.Value)) && len(m.Value) > len(best) {
			best = m.Value
		}
	}
	return best, best != ""
}

// modelInfo is the current model's, or nil when claude listed none.
func (c *config) modelInfo() *claudeagent.ModelInfo {
	for i := range c.models {
		if c.models[i].Value == c.model {
			return &c.models[i]
		}
	}
	return nil
}

// The permission modes a session offers, in order.
var modes = []acp.SessionMode{
	{ID: "default", Name: "Manual", Description: "Asks before changing anything"},
	{ID: "acceptEdits", Name: "Accept edits", Description: "Edits files without asking"},
	{ID: "plan", Name: "Plan", Description: "Plans first, changing nothing"},
	{ID: "auto", Name: "Auto", Description: "Claude decides what to ask"},
	{ID: "bypassPermissions", Name: "Bypass permissions", Description: "Asks nothing"},
}

// modesLocked are the modes the session offers.
func (c *config) modesLocked() []acp.SessionMode {
	if c.bypass {
		return modes
	}
	return modes[:len(modes)-1]
}

func (c *config) modeStateLocked() *acp.SessionModeState {
	return &acp.SessionModeState{CurrentModeID: acp.SessionModeID(c.mode), AvailableModes: c.modesLocked()}
}

// optionsLocked are the session's config options, the whole set.
func (c *config) optionsLocked() []acp.SessionConfigOption {
	var mode []acp.SessionConfigSelectOption
	for _, m := range c.modesLocked() {
		mode = append(mode, acp.SessionConfigSelectOption{Value: acp.SessionConfigValueID(m.ID), Name: m.Name, Description: m.Description})
	}
	opts := []acp.SessionConfigOption{selectOption(optMode, "Mode", acp.SessionConfigOptionCategoryMode, c.mode, mode)}
	if len(c.models) > 0 {
		var vs []acp.SessionConfigSelectOption
		for _, m := range c.models {
			vs = append(vs, acp.SessionConfigSelectOption{Value: acp.SessionConfigValueID(m.Value), Name: cmp.Or(m.DisplayName, m.Value), Description: m.Description})
		}
		o := selectOption(optModel, "Model", acp.SessionConfigOptionCategoryModel, c.model, vs)
		o.Description = "The model Claude works with"
		opts = append(opts, o)
	}
	m := c.modelInfo()
	if m != nil && m.SupportsEffort && len(m.SupportedEffortLevels) > 0 {
		vs := []acp.SessionConfigSelectOption{{Value: defaultValue, Name: "Default"}}
		for _, l := range m.SupportedEffortLevels {
			vs = append(vs, acp.SessionConfigSelectOption{Value: acp.SessionConfigValueID(l), Name: strings.ToUpper(l[:1]) + l[1:]})
		}
		opts = append(opts, selectOption(optEffort, "Effort", acp.SessionConfigOptionCategoryThoughtLevel, c.effort, vs))
	}
	if m != nil && m.SupportsFastMode {
		o := acp.SessionConfigOption{ID: optFast, Name: "Fast mode", Category: acp.SessionConfigOptionCategoryModelConfig,
			Description: "Faster output from the same model, at a higher price", Boolean: &acp.SessionConfigBoolean{CurrentValue: c.fast}}
		if !c.booleans {
			cur := map[bool]string{true: "on", false: "off"}[c.fast]
			o = selectOption(optFast, o.Name, o.Category, cur, []acp.SessionConfigSelectOption{{Value: "on", Name: "On"}, {Value: "off", Name: "Off"}})
		}
		opts = append(opts, o)
	}
	if len(c.agents) > 0 {
		vs := []acp.SessionConfigSelectOption{{Value: defaultValue, Name: "Default"}}
		for _, a := range c.agents {
			vs = append(vs, acp.SessionConfigSelectOption{Value: acp.SessionConfigValueID(a.Name), Name: a.Name, Description: a.Description})
		}
		opts = append(opts, selectOption(optAgent, "Agent", "", c.agent, vs))
	}
	return opts
}

func selectOption(id, name string, cat acp.SessionConfigOptionCategory, current string, vs []acp.SessionConfigSelectOption) acp.SessionConfigOption {
	return acp.SessionConfigOption{ID: acp.SessionConfigID(id), Name: name, Category: cat,
		Select: &acp.SessionConfigSelect{CurrentValue: acp.SessionConfigValueID(current), Options: acp.SessionConfigSelectOptions{Ungrouped: vs}}}
}

// sendOptions tells the client the whole set of options.
func (s *session) sendOptions() {
	s.cfg.mu.Lock()
	opts := s.cfg.optionsLocked()
	s.cfg.mu.Unlock()
	s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "config_option_update", ConfigOptionUpdate: &acp.ConfigOptionUpdate{ConfigOptions: opts}})
}

// sendMode tells the client the current mode.
func (s *session) sendMode(mode string) {
	s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "current_mode_update", CurrentModeUpdate: &acp.CurrentModeUpdate{CurrentModeID: acp.SessionModeID(mode)}})
}

// modeChanged is claude in another mode, by its own doing or a plan's
// approval: the client is told when it is news.
func (s *session) modeChanged(mode string) {
	s.cfg.mu.Lock()
	news := mode != "" && mode != s.cfg.mode
	if news {
		s.cfg.mode = mode
	}
	s.cfg.mu.Unlock()
	if news {
		s.sendMode(mode)
		s.sendOptions()
	}
}

// followInit follows what a turn's system/init says of the model, mode
// and fast mode; the client is told of what changed.
func (s *session) followInit(m *claudeagent.SystemInit) {
	s.modeChanged(m.PermissionMode)
	c := &s.cfg
	c.mu.Lock()
	news := false
	// Only a model the list names exactly: "opus" in a model's id may not
	// be the default's model, whose resolved model an older claude doesn't
	// say.
	if v, ok := c.lookup(m.Model, c.model, false); ok && v != c.model {
		c.model, news = v, true
	}
	c.mu.Unlock()
	if s.fastState(m.FastModeState, "") || news {
		s.sendOptions()
	}
}

// fastState follows claude's word on fast mode: "on" or "off" ("cooldown"
// is a pause, not a change). Turned off for a reason, the user is told
// why. It says whether fast mode changed.
func (s *session) fastState(state, why string) bool {
	if state != "on" && state != "off" {
		return false
	}
	c := &s.cfg
	c.mu.Lock()
	on := state == "on"
	news := on != c.fast
	c.fast = on
	c.mu.Unlock()
	switch {
	case !news || on || why == "":
	case s.a.clientCaps().notices:
		s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "notice", Notice: &acp.Notice{Severity: acp.NoticeSeverityWarning, Title: "Fast mode turned off: " + why}})
	default: // the shape claude-agent-acp gives it, as the model fallback's
		s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "agent_message_chunk", AgentMessageChunk: &acp.ContentChunk{
			Content: acp.ContentBlock{Text: &acp.TextContent{Text: "**Fast mode turned off:** " + why}},
		}})
	}
	return news
}
