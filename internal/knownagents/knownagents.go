// Package knownagents is the one table of the agents Nushi runs: each
// agent's harness (capabilities.go lists what each has) and its facts, as
// every feature takes them (finding and setting it up, its skills, its
// trust, its MCP servers). It is wiring, as cmd/nushid is: main builds the
// features from it, and the e2e tests run its harnesses on fake agents. What
// each agent does is in its own packages: internal/claude*, internal/codex*,
// internal/ante* (Ante's bridge too, ADR 0030), internal/omp*,
// internal/opencode* and internal/pi (Pi's and PiG's bridge, ADR 0039,
// 0078).
package knownagents

import (
	"log/slog"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/antemcp"
	"github.com/afrase/nushi/internal/anteskills"
	"github.com/afrase/nushi/internal/antetrust"
	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/claudeskills"
	"github.com/afrase/nushi/internal/claudetrust"
	"github.com/afrase/nushi/internal/codex"
	"github.com/afrase/nushi/internal/codexskills"
	"github.com/afrase/nushi/internal/codextrust"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/skills"
	"github.com/afrase/nushi/internal/features/trust"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/ompskills"
	"github.com/afrase/nushi/internal/omptrust"
	"github.com/afrase/nushi/internal/opencode"
	"github.com/afrase/nushi/internal/opencodeskills"
	"github.com/afrase/nushi/internal/opencodetrust"
	"github.com/afrase/nushi/internal/pi"
	"github.com/afrase/nushi/internal/piskills"
)

// Harness is what chats run of an agent, and how it starts.
type Harness interface {
	chats.Harness
	// Start starts it for a chat, as r says, from dir (the daemon's folder).
	Start(dir string, r model.AgentRun, h acp.Client, log *slog.Logger) (*agentproc.Agent, error)
}

// Agent is one agent Nushi runs.
type Agent struct {
	// Agent is how it is found and set up (features/agents); its Name and
	// Title are its harness's.
	Agent agents.Agent
	// Harness is what its chats do, as far as that is the agent's own:
	// nothing that reads the agent's files or processes on this Mac. It's
	// what the e2e tests run, so they never read the owner's.
	Harness Harness
	// Local is Harness with what reads the agent's own files and processes
	// on this Mac (its history, its sessions open elsewhere, its forks),
	// which main runs: Harness itself when there's nothing to read.
	Local  Harness
	Skills skills.Reader
	Trust  trust.Agent
	// MCP is its MCP servers' config, which Settings shows and changes;
	// nil: none. run is how a chat would start it, for a check that runs
	// the agent.
	MCP func(run func() (model.AgentRun, error)) mcp.Config
}

// All is every agent, in the order they're listed, the default (Claude)
// first. projects is Claude's projects folder (claudehistory.Projects),
// which its Local reads. Claude runs through Nushi's Go agent (ADR 0066):
// no adapter, Node, set-up or pinned versions.
func All(projects string) []Agent {
	all := []Agent{
		{
			Harness: claude.Harness{}, Local: claudehistory.Local{Projects: projects},
			Agent:  agents.Agent{CLI: claude.CLI, Page: claude.Page, SignedIn: claude.SignedIn},
			Skills: claudeskills.Claude{}, Trust: claudetrust.Trust{},
			MCP: func(func() (model.AgentRun, error)) mcp.Config { return claudemcp.Claude{} },
		},
		{
			Harness: codex.Harness{}, Local: codex.Local{},
			Agent: agents.Agent{CLI: codex.CLI, Page: codex.Page, Tested: codex.Tested,
				Adapter: &agents.Adapter{Lock: codex.Adapter, Package: codex.AdapterPackage, Bin: codex.AdapterBin, Download: codex.AdapterDownload, Disk: codex.AdapterDisk}},
			Skills: codexskills.Codex{}, Trust: codextrust.Trust{},
		},
		{
			Harness: ante.Harness{}, Local: ante.Local{},
			Agent:  agents.Agent{CLI: ante.CLI, Also: ante.Also(), Page: ante.Page, Min: ante.Min, Tested: ante.Tested},
			Skills: anteskills.Ante{}, Trust: antetrust.Trust{},
			// Its servers are checked by a throwaway `ante serve` and signed
			// in to by `ante` itself, each run as a chat's would be.
			MCP: func(run func() (model.AgentRun, error)) mcp.Config {
				return antemcp.Ante{Run: run, Spawn: func() (ante.Spawn, error) {
					r, err := run()
					if err != nil {
						return nil, err
					}
					return ante.Server(r.CLI, r.Env, nil), nil
				}}
			},
		},
		{
			Harness: omp.Harness{}, Local: omp.Local{},
			Agent:  agents.Agent{CLI: omp.CLI, Page: omp.Page, Tested: omp.Tested},
			Skills: ompskills.OMP{}, Trust: omptrust.Trust{},
		},
		{
			Harness: opencode.Harness{}, Local: opencode.Local{},
			Agent:  agents.Agent{CLI: opencode.CLI, Page: opencode.Page, Min: opencode.Min, Tested: opencode.Tested},
			Skills: opencodeskills.OpenCode{}, Trust: opencodetrust.Trust{},
		},
		piFlavor(pi.Pi),
		piFlavor(pi.PiG),
	}
	for i := range all {
		info := all[i].Harness.Info()
		all[i].Agent.Name, all[i].Agent.Title = info.Name, info.Title
	}
	return all
}

// piFlavor is an agent of Pi's RPC mode.
func piFlavor(f pi.Flavor) Agent {
	h := pi.Harness{Flavor: f}
	return Agent{
		Harness: h, Local: h,
		Agent:  agents.Agent{CLI: f.CLI, Page: f.Page, Min: f.Min, Tested: []string{f.Version}},
		Skills: piskills.Skills{Flavor: f}, Trust: pi.Trust{},
	}
}
