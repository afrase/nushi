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
	svc := agents.New(list, probe, filepath.Join(dir, "agents"), npm.Installer{Environ: shellEnv.Environ})
	svc.UseEnv(shellEnv)
	return svc
}

// chatKinds are the agents as chats run them, from dir (the daemon's
// folder): each started through the agents feature (ADR 0037), which says
// whether it could start (Ready) and adds to why it failed what may help
// (Explain), with what reads its own files on this Mac.
func chatKinds(dir string, known []knownagents.Agent, agentSvc *agents.Service) []chats.Kind {
	var kinds []chats.Kind
	for _, a := range known {
		k, name, start := a.Chats, a.Agent.Name, a.Start
		if a.Local != nil {
			a.Local(&k)
		}
		k.Explain = agentSvc.Explain(name)
		k.Ready = func() error { _, err := agentSvc.Run(name); return err }
		k.Launch = func(h acp.Client, log *slog.Logger) (chats.Agent, error) {
			run, err := agentSvc.Run(name)
			if err != nil {
				return nil, err
			}
			agent, err := start(dir, run, h, log)
			if err != nil {
				return nil, err // not a nil *agentproc.Agent in a chats.Agent
			}
			return agent, nil
		}
		kinds = append(kinds, k)
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
