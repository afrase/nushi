package pig

import (
	"context"
	"fmt"
	"math"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// ContextMethod is the bridge's extension that says what a session holds:
// PiG's session stats, and how many compactions its branch has had.
const ContextMethod = "_pig/context"

// stats is what ContextMethod answers.
type stats struct {
	UserMessages      int `json:"userMessages"`
	AssistantMessages int `json:"assistantMessages"`
	ToolCalls         int `json:"toolCalls"`
	Tokens            struct {
		Input      int64 `json:"input"`
		Output     int64 `json:"output"`
		CacheRead  int64 `json:"cacheRead"`
		CacheWrite int64 `json:"cacheWrite"`
	} `json:"tokens"`
	Compactions int `json:"compactions"`
}

func (s *session) stats(ctx context.Context) (stats, error) {
	var st stats
	if err := s.p.call(ctx, map[string]any{"type": "get_session_stats"}, &st); err != nil {
		return st, err
	}
	entries, err := branch(ctx, s.p)
	for _, e := range entries {
		if e.Type == "compaction" {
			st.Compactions++
		}
	}
	return st, err
}

// Context asks the bridge what a session holds, for the Context card:
// PiG has no breakdown of its context, but counts the session's messages,
// tool calls and tokens.
func Context(ctx context.Context, call func(ctx context.Context, method string, params, result any) error, sessionID string) (model.ContextUsage, error) {
	var st stats
	if err := call(ctx, ContextMethod, map[string]string{"sessionId": sessionID}, &st); err != nil {
		return model.ContextUsage{}, err
	}
	t := st.Tokens
	lines := []string{
		fmt.Sprintf("Messages: %d from you, %d from PiG", st.UserMessages, st.AssistantMessages),
		fmt.Sprintf("Tool calls: %d", st.ToolCalls),
		fmt.Sprintf("Tokens: %s in · %s out", short(t.Input), short(t.Output)),
	}
	var cache []string
	if t.CacheRead > 0 {
		cache = append(cache, short(t.CacheRead)+" read")
	}
	if t.CacheWrite > 0 {
		cache = append(cache, short(t.CacheWrite)+" written")
	}
	if len(cache) > 0 {
		lines = append(lines, "Cache: "+strings.Join(cache, " · "))
	}
	lines = append(lines, fmt.Sprintf("Compactions: %d", st.Compactions))
	return model.ContextUsage{Markdown: "- " + strings.Join(lines, "\n- ") + "\n"}, nil
}

// short is a token count as the app shows one: 950, 21.8k, 1M.
func short(n int64) string {
	v, unit := float64(n), ""
	switch {
	case n >= 1_000_000:
		v, unit = v/1_000_000, "M"
	case n >= 1000:
		v, unit = v/1000, "k"
	}
	if v >= 100 || v == math.Round(v) {
		return strconv.FormatFloat(math.Round(v), 'f', 0, 64) + unit
	}
	return strconv.FormatFloat(v, 'f', 1, 64) + unit
}
