package acp

// A prompt response's usage is unstable in ACP v1, so it isn't in the
// pinned schema; these types are written by hand.

// TurnUsage is the tokens a turn used, as the agent counts them.
type TurnUsage struct {
	InputTokens       int64 `json:"inputTokens"`
	OutputTokens      int64 `json:"outputTokens"`
	CachedReadTokens  int64 `json:"cachedReadTokens,omitempty"`
	CachedWriteTokens int64 `json:"cachedWriteTokens,omitempty"`
	TotalTokens       int64 `json:"totalTokens"`
}

// PromptResult is a prompt response with the turn's usage, if the agent
// sends it.
type PromptResult struct {
	PromptResponse
	Usage *TurnUsage `json:"usage,omitempty"`
}
