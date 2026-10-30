package claudeacp

import (
	"context"
	"os"
	"regexp"
	"slices"
	"strings"
	"sync"

	"github.com/afrase/nushi/claudeagent"
)

// The context window's size, as claude-agent-acp finds it: a result's
// modelUsage says it for sure, and is kept across the agent's sessions
// by backend and model; until one has, a model whose names say 1m has a
// million, and claude is asked (get_context_usage, "summary", which it
// answers without an API call) without waiting, so a model whose names
// don't say (Opus 5.5, Sonnet) isn't shown at 200k through its first
// turn.

// window is a session's context window, as far as it is known. The
// reader, a model change and claude's answer each set it.
type window struct {
	mu       sync.Mutex
	size     int        // 0 until known or guessed from the model's names
	sure     bool       // from a result or the cache: claude's answer doesn't replace it
	gen      int        // one more at each model change, so an answer for the last model goes
	provider string     // the backend's key (providerKey), for the cache
	shown    shownUsage // the last usage_update sent
}

// shownUsage is what a usage_update said.
type shownUsage struct {
	used  int
	model string
	size  int
	ok    bool // one was sent
}

// windows are the windows results have said, by providerKey and the
// model's id, for the agent's sessions.
type windows struct {
	mu sync.Mutex
	m  map[string]int
}

func (w *windows) find(provider, model string) (int, bool) {
	w.mu.Lock()
	defer w.mu.Unlock()
	n, ok := w.m[provider+"\x00"+model]
	return n, ok
}

func (w *windows) keep(provider, model string, size int) {
	if size <= 0 || model == "" {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.m == nil {
		w.m = map[string]int{}
	}
	w.m[provider+"\x00"+model] = size
}

// routingEnv are the variables that choose the backend a claude talks
// to, and the context window its models get there: the endpoint, the
// headers (a context-1m beta), the account.
var routingEnv = []string{
	"ANTHROPIC_BASE_URL", "ANTHROPIC_BEDROCK_BASE_URL", "ANTHROPIC_VERTEX_BASE_URL",
	"CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "ANTHROPIC_VERTEX_PROJECT_ID",
	"CLOUD_ML_REGION", "AWS_REGION", "ANTHROPIC_CUSTOM_HEADERS",
	"ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN",
}

// providerKey is the backend claude runs against with env (nil: the
// agent's own): routingEnv's values, joined. It holds secrets, so it is
// only ever a key in memory, never logged.
func providerKey(env []string) string {
	if env == nil {
		env = os.Environ()
	}
	vals := map[string]string{}
	for _, kv := range env {
		k, v, _ := strings.Cut(kv, "=")
		vals[k] = v
	}
	parts := make([]string, len(routingEnv))
	for i, k := range routingEnv {
		parts[i] = vals[k]
	}
	return strings.Join(parts, "\x00")
}

// oneM is a model id or name that says it has a million-token context.
var oneM = regexp.MustCompile(`(?i)\b1m\b`)

// guessWindow is a million when one of a model's names says 1m, else 0.
func guessWindow(m *claudeagent.ModelInfo, value string) int {
	names := []string{value}
	if m != nil {
		names = append(names, m.ResolvedModel, m.DisplayName, m.Description)
	}
	if slices.ContainsFunc(names, oneM.MatchString) {
		return 1_000_000
	}
	return 0
}

// modelID is the model a value names, as results' modelUsage spells it.
func modelID(m *claudeagent.ModelInfo, value string) string {
	if m != nil && m.ResolvedModel != "" {
		return m.ResolvedModel
	}
	return value
}

// seedWindow sets the window for the session's model as it starts or
// changes: the cache's, else a guess from the model's names (fallback
// when they say nothing), and asks claude when it isn't sure.
func (s *session) seedWindow(ctx context.Context, fallback int) {
	s.cfg.mu.Lock()
	m, value := s.cfg.modelInfo(), s.cfg.model
	s.cfg.mu.Unlock()
	w := &s.win
	w.mu.Lock()
	w.gen++
	gen := w.gen
	size, sure := s.a.windows.find(w.provider, modelID(m, value))
	if !sure {
		size = guessWindow(m, value)
		if size == 0 {
			size = fallback
		}
	}
	w.size, w.sure = size, sure
	w.mu.Unlock()
	if !sure {
		s.askWindow(ctx, gen)
	}
}

// askWindow asks claude for the window and waits for its answer on a
// goroutine of its own: the request is written now, so it reaches claude
// before what the session writes next, as claude-agent-acp's does. The
// answer counts unless a result, or another model, came first. claude
// answers beside its stream, so a usage_update may have gone out with
// the guess meanwhile: it is sent again with the answer's size, so the
// meter doesn't wait for the next one.
func (s *session) askWindow(ctx context.Context, gen int) {
	// The answer outlives the request that asked: the session's end ends
	// the wait.
	call, err := s.cs.Begin(context.WithoutCancel(ctx), "get_context_usage", struct {
		Detail string `json:"detail"`
	}{"summary"})
	if err != nil {
		s.log.Debug("asking claude for the context window", "err", err)
		return
	}
	s.bg.Go(func() {
		var u claudeagent.ContextUsage
		if err := call.Wait(&u); err != nil {
			s.log.Debug("reading the context window", "err", err)
			return
		}
		w := &s.win
		w.mu.Lock()
		defer w.mu.Unlock()
		if u.RawMaxTokens <= 0 || w.sure || w.gen != gen {
			return
		}
		w.size = u.RawMaxTokens
		if w.shown.ok && w.shown.size != w.size {
			w.shown.size = w.size
			s.sendUsage(w.shown, nil, nil)
		}
	})
}

// resultWindow takes the window a result says: its model's (model, the
// last top-level message's), else the largest it names. It is sure, and
// kept for the agent's next sessions on the same backend.
func (s *session) resultWindow(r *claudeagent.Result, model string) {
	size, id := 0, model
	if mu, ok := r.ModelUsage[model]; ok && mu.ContextWindow > 0 {
		size = mu.ContextWindow
	} else {
		for k, mu := range r.ModelUsage {
			if mu.ContextWindow > size {
				size, id = mu.ContextWindow, k
			}
		}
	}
	if size <= 0 {
		return
	}
	s.win.mu.Lock()
	s.win.size, s.win.sure = size, true
	provider := s.win.provider
	s.win.mu.Unlock()
	s.a.windows.keep(provider, id, size)
	if id != model {
		s.a.windows.keep(provider, model, size)
	}
}

// sizeLocked is the context window's: as known, else a million for a
// model whose id says 1m, else 200k. The reader calls it, with the
// window locked.
func (s *session) sizeLocked() int {
	switch {
	case s.win.size > 0:
		return s.win.size
	case oneM.MatchString(s.st.model):
		return 1_000_000
	}
	return 200_000
}
