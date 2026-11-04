package main

import (
	"context"
	"log/slog"
	"os"
	"path/filepath"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/trust"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/npm"
	"github.com/afrase/nushi/internal/readonly"
	"github.com/afrase/nushi/internal/shellenv"
)

// newAgents is the agents feature: the agents Nushi knows, found on the
// PATH of the environment they start with (ADR 0048), their adapters set
// up in dir/agents.
func newAgents(dir string, known []knownagents.Agent) *agents.Service {
	// Agents start with the login shell's environment, read now and when
	// Settings › Agents asks, whatever started the daemon (ADR 0048).
	// NUSHI_SHELL_ENV=off keeps the daemon's own (tests set PATH to their
	// fake agents; the shell's would replace it).
	shellEnv := shellenv.New(knownShell(loginShell()), os.Environ())
	if os.Getenv("NUSHI_SHELL_ENV") == "off" {
		shellEnv = shellenv.Off(os.Environ())
	}
	shellEnv.Start()
	probe := func(ctx context.Context, path string, args ...string) ([]byte, error) {
		return readonly.Output(ctx, shellEnv.Environ(), path, args...)
	}
	var list []agents.Agent
	for _, a := range known {
		list = append(list, a.Agent)
	}
	removeClaudeAdapter(filepath.Join(dir, "agents", "claude"))
	svc := agents.New(list, probe, filepath.Join(dir, "agents"), npm.Installer{Environ: shellEnv.Environ})
	svc.UseEnv(shellEnv)
	return svc
}

// removeClaudeAdapter removes folder, where Settings › Agents set up
// Claude's Node adapter (claude-agent-acp) before Claude ran through the
// Go agent alone (ADR 0066): about 73 MB nothing runs any more.
func removeClaudeAdapter(folder string) {
	if _, err := os.Lstat(folder); err != nil {
		return
	}
	err := os.RemoveAll(folder)
	slog.Info("claude's old adapter removed", "folder", folder, "err", err)
}

// chatKinds are the agents as chats run them, from dir (the daemon's
// folder): each started through the agents feature (ADR 0037), which says
// whether it could start (Ready) and adds to why it failed what may help
// (Explain), its harness the one that reads its own files on this Mac.
func chatKinds(dir string, known []knownagents.Agent, agentSvc *agents.Service) []chats.Kind {
	var kinds []chats.Kind
	for _, a := range known {
		name, harness := a.Agent.Name, a.Local
		kinds = append(kinds, chats.Kind{
			Harness: harness,
			MCP:     a.MCP != nil,
			Explain: agentSvc.Explain(name),
			Ready:   func() error { _, err := agentSvc.Run(name); return err },
			Launch: func(h acp.Client, log *slog.Logger) (chats.Agent, error) {
				run, err := agentSvc.Run(name)
				if err != nil {
					return nil, err
				}
				agent, err := harness.Start(dir, run, h, log)
				if err != nil {
					return nil, err // not a nil *agentproc.Agent in a chats.Agent
				}
				return agent, nil
			},
		})
	}
	return kinds
}

// newTrust is the trust card's service: what a folder brings each agent.
func newTrust(known []knownagents.Agent, st trust.Store) *trust.Service {
	byName := map[string]trust.Agent{}
	for _, a := range known {
		byName[a.Agent.Name] = a.Trust
	}
	return trust.New(byName, st)
}
