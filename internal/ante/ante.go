// Package ante runs Ante as one of Nushi's agents. Ante speaks its own
// protocol (`ante serve`), not ACP, so Nushi brings an ACP agent for it,
// the bridge: `nushid ante-acp` runs it, an `ante serve --stdio` per
// session underneath (ADR 0030). Nothing outside this package knows Ante's
// protocol; the chats feature takes its Harness through its interfaces.
// It follows Ante 0.2.14's protocol (crates/protocol-shape/src/msg.rs).
package ante

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/procgroup"
)

// Command is the nushid subcommand that runs the bridge.
const Command = "ante-acp"

// CLI is Ante's program, Min the Ante whose protocol the bridge follows
// (older ones are refused, newer ones tried), and Page where to get it.
const (
	CLI  = "ante"
	Min  = "0.2.14"
	Page = "https://github.com/AntigmaLabs/ante"
)

// Tested are the Ante versions the bridge was run with (0.3.2 on a fake
// model, docs/facts/ante.md).
var Tested = []string{Min, "0.3.2"}

// Also is where Ante's installer puts it, for when it isn't on PATH.
func Also() []string {
	home, _ := os.UserHomeDir()
	return []string{filepath.Join(Home(), "bin", "ante"), filepath.Join(home, ".ante", "bin", "ante")}
}

// Harness is Ante as Nushi runs it, for the chats feature's interfaces.
// Nothing here reads Ante's files: Local adds that.
type Harness struct{}

// Local is Harness with what reads Ante's files and processes on this Mac
// (open.go, times.go). Tests use Harness alone.
type Local struct{ Harness }

// Info is what Harness is.
func (Harness) Info() model.HarnessInfo {
	return model.HarnessInfo{Name: "ante", Title: "Ante", Resume: "ante --resume"}
}

// Start starts the bridge, as claude.Harness does Claude's Go agent: this
// executable's Command, in dir (the daemon's folder) and r's environment
// (the login shell's, ADR 0048), its stderr to log.
func (Harness) Start(dir string, r model.AgentRun, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	self, err := os.Executable()
	if err != nil {
		return nil, err
	}
	cmd := exec.Command(self, Command) //nolint:gosec,noctx // lives until Stop or Close, not a context; this nushid as the bridge
	cmd.Dir, cmd.Env = dir, r.Env      // the bridge finds the CLI on that PATH
	return agentproc.Start(cmd, client, log)
}

// warnf writes a line to the bridge's stderr, which the daemon logs with
// the chat's attributes, as any agent's stderr.
func warnf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "ante-acp: "+format+"\n", args...)
}

// Main runs the bridge on stdin and stdout: the Command.
func Main() {
	cfg := Config{Home: Home()}
	bin, err := binary()
	if err == nil {
		cfg.Version, err = version(bin)
	}
	cfg.Problem = err
	cfg.Spawn = Server(bin, nil, os.Stderr)
	cfg.Catalog = func() ([]provider, error) { return catalog(bin) }
	Serve(os.Stdin, os.Stdout, cfg)
}

// Home is Ante's own folder: $ANTE_HOME, else ~/.ante.
func Home() string {
	if h := os.Getenv("ANTE_HOME"); h != "" {
		return h
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".ante")
}

// binary finds ante: on PATH, else where its installer puts it.
func binary() (string, error) {
	if p, err := exec.LookPath(CLI); err == nil {
		return p, nil
	}
	for _, p := range Also() {
		if st, err := os.Stat(p); err == nil && st.Mode().IsRegular() && st.Mode()&0o111 != 0 {
			return p, nil
		}
	}
	return "", errors.New("Ante isn't installed: there's no ante on PATH or in ~/.ante/bin")
}

// version checks ante's version, refusing one older than Min.
func version(bin string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, "--version")
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("couldn't run %s --version: %w", bin, err)
	}
	v := strings.TrimPrefix(strings.TrimSpace(string(out)), "ante ")
	got, want := numbers(v), numbers(Min)
	switch {
	case got == nil:
		return "", fmt.Errorf("couldn't read ante's version from %q", out)
	case got[0] != want[0] || got[1] < want[1] || got[1] == want[1] && got[2] < want[2]:
		return "", fmt.Errorf("Ante %s is older than the %s Nushi needs: run `ante update`", v, Min)
	case !slices.Contains(Tested, v):
		warnf("ante %s isn't one the bridge was run with: %s", v, strings.Join(Tested, ", "))
	}
	return v, nil
}

// numbers reads a version's three numbers; nil if it hasn't three.
func numbers(v string) []int {
	parts := strings.Split(v, ".")
	if len(parts) != 3 {
		return nil
	}
	out := make([]int, 3)
	for i, p := range parts {
		out[i], _ = strconv.Atoi(p)
	}
	return out
}

// catalog reads Ante's providers and their models (`ante catalog`).
func catalog(bin string) ([]provider, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, "catalog")
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	var c struct {
		Providers []provider `json:"providers"`
	}
	return c.Providers, json.Unmarshal(out, &c)
}

// ForkAt says how to fork a session at a message, if the agent is the
// bridge: its own meta, which cuts after the turn that has the message
// (Ante forks at an input).
func (Harness) ForkAt(init *acp.InitializeResponse) func(messageID string) map[string]any {
	if init.AgentInfo == nil || init.AgentInfo.Name != AgentName {
		return nil
	}
	return func(messageID string) map[string]any {
		return map[string]any{"ante": map[string]any{"afterMessage": messageID}}
	}
}

// Other says field is the free-text "Other" the bridge puts after a
// question with choices.
func (Harness) Other(field, before model.Field) bool { return field.ID == before.ID+"_other" }

// Context asks the bridge what fills a session's context (Ante's
// ContextReport): no model call, nothing kept in the conversation.
func (Harness) Context(ctx context.Context, call func(ctx context.Context, method string, params, result any) error, sessionID string) (model.ContextUsage, error) {
	var r struct {
		SystemPrompt int64  `json:"system_prompt_tokens"`
		SystemTools  int64  `json:"system_tools_tokens"`
		MCPTools     int64  `json:"mcp_tools_tokens"`
		Memory       int64  `json:"memory_tokens"`
		Skills       int64  `json:"skills_tokens"`
		Messages     int64  `json:"messages_tokens"`
		Used         int64  `json:"used_tokens"`
		Limit        *int64 `json:"limit_tokens"`
		Buffer       int64  `json:"compact_buffer_tokens"`
	}
	if err := call(ctx, ContextMethod, map[string]string{"sessionId": sessionID}, &r); err != nil {
		return model.ContextUsage{}, err
	}
	cats := []model.ContextCategory{{Name: "System prompt", Tokens: r.SystemPrompt}, {Name: "System tools", Tokens: r.SystemTools},
		{Name: "MCP tools", Tokens: r.MCPTools}, {Name: "Memory files", Tokens: r.Memory}, {Name: "Skills", Tokens: r.Skills},
		{Name: "Messages", Tokens: r.Messages}}
	if r.Limit != nil && *r.Limit > 0 {
		limit := *r.Limit
		cats = append(cats, model.ContextCategory{Name: "Free space", Tokens: max(0, limit-r.Used-r.Buffer), Kind: "free"},
			model.ContextCategory{Name: "Autocompact buffer", Tokens: r.Buffer})
		for i := range cats {
			cats[i].Percent = float64(cats[i].Tokens) * 100 / float64(limit)
		}
	}
	var md strings.Builder
	md.WriteString("| Category | Tokens | Percent |\n|---|---|---|\n")
	for _, c := range cats {
		fmt.Fprintf(&md, "| %s | %d | %.1f%% |\n", c.Name, c.Tokens, c.Percent)
	}
	return model.ContextUsage{Markdown: md.String(), Categories: cats}, nil
}
