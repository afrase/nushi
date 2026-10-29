package claudeagent

import (
	"bytes"
	"encoding/json"
	"fmt"
	"maps"
)

// Init is what the initialize request tells claude beyond its command
// line. Only what is set is sent: a claude that doesn't know a field
// ignores it.
type Init struct {
	SystemPrompt       string // replaces claude's own system prompt
	AppendSystemPrompt string // goes after it
	Agents             map[string]AgentDefinition
	// PerTaskStopAffordance has an interrupt leave background tasks
	// running, each stopped on its own (StopTask); without it an
	// interrupt stops them all.
	PerTaskStopAffordance bool
	ForwardSubagentText   bool   // subagents' text comes as messages too
	Title                 string // the session's title
	// Extra holds fields the package doesn't name, sent as they are; a
	// key the package sets is refused.
	Extra map[string]any
}

// AgentDefinition is a subagent the session can run, besides the ones
// claude finds in its settings.
type AgentDefinition struct {
	Description string   `json:"description"`
	Prompt      string   `json:"prompt"`
	Tools       []string `json:"tools,omitempty"` // nil = every tool
	Model       string   `json:"model,omitempty"`
}

// initRequest is the initialize request's fields for i.
func initRequest(i Init) (map[string]any, error) {
	r := map[string]any{}
	if i.SystemPrompt != "" {
		r["systemPrompt"] = []string{i.SystemPrompt} // a list, as the TypeScript SDK sends it
	}
	if i.AppendSystemPrompt != "" {
		r["appendSystemPrompt"] = i.AppendSystemPrompt
	}
	if len(i.Agents) > 0 {
		r["agents"] = i.Agents
	}
	if i.PerTaskStopAffordance {
		r["perTaskStopAffordance"] = true
	}
	if i.ForwardSubagentText {
		r["forwardSubagentText"] = true
	}
	if i.Title != "" {
		r["title"] = i.Title
	}
	for _, k := range []string{"subtype", "systemPrompt", "appendSystemPrompt", "agents", "perTaskStopAffordance", "forwardSubagentText", "title", "hooks"} {
		if _, ok := i.Extra[k]; ok {
			return nil, fmt.Errorf("claudeagent: Init.Extra can't set %q", k)
		}
	}
	maps.Copy(r, i.Extra)
	return r, nil
}

// InitResponse is claude's answer to initialize: what the session offers
// and how it starts. Fields an older claude doesn't send are zero; Raw
// has them all.
type InitResponse struct {
	Commands              []Command   `json:"commands"`
	Agents                []AgentInfo `json:"agents"`
	Models                []ModelInfo `json:"models"`
	Account               Account     `json:"account"`
	OutputStyle           string      `json:"output_style"`
	AvailableOutputStyles []string    `json:"available_output_styles"`
	CurrentModel          string      `json:"current_model"`
	CurrentPermissionMode string      `json:"current_permission_mode"`
	FastModeState         string      `json:"fast_mode_state"`
	ClaudeCodeVersion     string      `json:"claude_code_version"`
	PID                   int         `json:"pid"`
	// Capabilities are the protocol features claude supports; Session.Has
	// reads them with system/init's.
	Capabilities []string        `json:"capabilities"`
	Raw          json.RawMessage `json:"-"`
}

// UnmarshalJSON decodes r, keeping it in Raw.
func (r *InitResponse) UnmarshalJSON(data []byte) error {
	type plain InitResponse
	if err := json.Unmarshal(data, (*plain)(r)); err != nil {
		return err
	}
	r.Raw = bytes.Clone(data)
	return nil
}

// AgentInfo is a subagent the session can run.
type AgentInfo struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Model       string `json:"model"`
}

// ModelInfo is a model the session can switch to: Value is what SetModel
// takes.
type ModelInfo struct {
	Value                    string   `json:"value"`
	ResolvedModel            string   `json:"resolvedModel"`
	DisplayName              string   `json:"displayName"`
	Description              string   `json:"description"`
	SupportsEffort           bool     `json:"supportsEffort"`
	SupportedEffortLevels    []string `json:"supportedEffortLevels"`
	SupportsAdaptiveThinking bool     `json:"supportsAdaptiveThinking"`
	SupportsFastMode         bool     `json:"supportsFastMode"`
	SupportsAutoMode         bool     `json:"supportsAutoMode"`
}

// Account is who claude runs as, as far as it says.
type Account struct {
	Email            string `json:"email"`
	Organization     string `json:"organization"`
	SubscriptionType string `json:"subscriptionType"`
	TokenSource      string `json:"tokenSource"`
	APIKeySource     string `json:"apiKeySource"`
	APIProvider      string `json:"apiProvider"`
}
