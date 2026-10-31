// Package knownagents is the one table of the agents Nushi runs: each
// agent's facts, as every feature takes them (finding and setting it up,
// its chats, its skills, its trust, its MCP servers). It is wiring, as
// cmd/nushid is: main builds the features from it, and the e2e tests run
// its chats' kinds on fake agents. What each agent does is in its own
// packages: internal/claude*, internal/codex*, internal/ante* (Ante's
// bridge too, ADR 0030), internal/omp* and internal/pig (PiG's bridge,
// ADR 0039).
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
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/ompskills"
	"github.com/afrase/nushi/internal/omptrust"
	"github.com/afrase/nushi/internal/pig"
	"github.com/afrase/nushi/internal/pigskills"
)

// Agent is one agent Nushi runs.
type Agent struct {
	// Agent is how it is found and set up (features/agents); its Name and
	// Title are its chats' too.
	Agent agents.Agent
	// Chats is what its chats do (features/chats), as far as that is the
	// agent's own: no Launch, Explain or Ready, which main makes from Start
	// and the agents feature, and nothing that reads the agent's files or
	// processes on this Mac, which Local adds.
	Chats chats.Kind
	// Local adds to a Kind what reads the agent's own files and processes
	// on this Mac: its history, its sessions open elsewhere, its forks;
	// nil: nothing. The e2e tests leave it out, so they never read the
	// owner's.
	Local func(*chats.Kind)
	// Start starts it for a chat, as Run says, from dir (the daemon's
	// folder).
	Start  func(dir string, r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error)
	Skills skills.Reader
	Trust  trust.Agent
	// MCP is its MCP servers' config, which Settings shows and changes
	// (Chats.MCP says so); nil: none. run is how a chat would start it,
	// for a check that runs the agent.
	MCP func(run func() (agents.Run, error)) mcp.Config
}

// All is every agent, in the order they're listed, the default (Claude)
// first. projects is Claude's projects folder (claudehistory.Projects),
// which its Local reads. claudeGo is the user's setting that runs Claude
// through Nushi's Go agent instead of the adapter (ADR 0066), asked each
// time a Claude chat's agent starts; the daemon's environment can force it
// (claude.GoForced, a dev override).
func All(projects string, claudeGo func() bool) []Agent {
	all := []Agent{
		{
			Agent: agents.Agent{Name: "claude", Title: "Claude", CLI: claude.CLI, Page: claude.Page, SignedIn: claude.SignedIn, Tested: claude.Tested,
				Adapter: &agents.Adapter{Lock: claude.Adapter, Package: claude.AdapterPackage, Bin: claude.AdapterBin, Download: claude.AdapterDownload, Disk: claude.AdapterDisk},
				// The Go agent needs no Node, nothing set up and no version pinned.
				Own: func() bool { return claude.GoForced() || claudeGo() }},
			Chats: chats.Kind{ClientMCP: true, Resume: "claude --resume", Gone: chats.NotFound, Expires: "Claude Code deletes sessions after 30 days by default",
				Dialect: chats.Dialect{InitMeta: claude.InitMeta, SessionMeta: claude.SessionMeta, UltracodeMeta: claude.UltracodeMeta, TurnDone: claude.TurnDone, ForkAt: claude.ForkAt, Parent: claude.Parent, ToolCall: claude.ToolCall, Notice: claude.Notice, Interrupted: claude.Interrupted,
					Background: claude.Background, ReportElsewhere: claude.ReportElsewhere,
					BackgroundCommand: claude.BackgroundCommand, ReadBackgroundCommand: claude.ReadBackgroundCommand,
					SubagentID: claude.SubagentID, ToSubagent: claude.ToSubagent, ReadToSubagent: claude.ReadToSubagent, PassesToSubagent: claude.PassesToSubagent,
					Subagents: claude.Subagents, StopTask: claude.StopTask, ReadStopTask: claude.ReadStopTask, Stopped: claude.Stopped, RunsBackgroundCommand: claude.RunsBackgroundCommand,
					Other: claude.Other, Default: claude.Default, ForkTitle: claude.ForkTitle, Compacted: claude.Compacted,
					ContextCommand: claude.ContextCommand, ReadContext: claude.ReadContext, Redelete: claude.Redelete, NamesSessions: true}},
			Local: func(k *chats.Kind) {
				k.History = func(id, from, to string) (func() error, error) { return claudehistory.Copy(projects, id, from, to) }
				k.OpenElsewhere = claudehistory.Open
				k.Forked = func(ids []string) map[string]bool { return claudehistory.Forked(projects, ids) }
				k.HistoryGone = func(sid, folder string) bool { return claudehistory.Gone(projects, sid, folder) }
			},
			Start: func(dir string, r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
				if r.Own {
					return claude.StartGo(dir, r.CLI, r.Env, h, log)
				}
				return claude.Start(dir, r.Node, r.Program, r.CLI, r.Env, h, log)
			},
			Skills: claudeskills.Claude{}, Trust: claudetrust.Trust{},
			MCP: func(func() (agents.Run, error)) mcp.Config { return claudemcp.Claude{} },
		},
		{
			Agent: agents.Agent{Name: "codex", Title: "Codex", CLI: codex.CLI, Page: codex.Page, Tested: codex.Tested,
				Adapter: &agents.Adapter{Lock: codex.Adapter, Package: codex.AdapterPackage, Bin: codex.AdapterBin, Download: codex.AdapterDownload, Disk: codex.AdapterDisk}},
			Chats: chats.Kind{ClientMCP: true, Resume: codex.Resume, History: codex.History, DeleteArchives: codex.DeleteArchives, Gone: codex.Gone, OneWriter: true,
				Dialect: chats.Dialect{ForkAt: codex.ForkAt, ToolCall: codex.ToolCall, Other: codex.Other}},
			Local: func(k *chats.Kind) { k.OpenElsewhere, k.Forked = codex.OpenElsewhere, codex.Forked },
			Start: func(dir string, r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
				return codex.Start(dir, r.Node, r.Program, r.CLI, r.Env, h, log)
			},
			Skills: codexskills.Codex{}, Trust: codextrust.Trust{},
		},
		{
			Agent: agents.Agent{Name: "ante", Title: "Ante", CLI: ante.CLI, Also: ante.Also(), Page: ante.Page, Min: ante.Min, Tested: ante.Tested},
			Chats: chats.Kind{Resume: ante.Resume, Dialect: chats.Dialect{ForkAt: ante.ForkAt, Other: ante.Other, Context: ante.Context}},
			Local: func(k *chats.Kind) { k.OpenElsewhere = ante.OpenElsewhere },
			Start: func(dir string, r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
				return ante.Start(dir, r.Env, h, log)
			},
			Skills: anteskills.Ante{}, Trust: antetrust.Trust{},
			// Its servers are checked by a throwaway `ante serve`, run as a
			// chat's would be.
			MCP: func(run func() (agents.Run, error)) mcp.Config {
				return antemcp.Ante{Spawn: func() (ante.Spawn, error) {
					r, err := run()
					if err != nil {
						return nil, err
					}
					return ante.Server(r.CLI, r.Env, nil), nil
				}}
			},
		},
		{
			Agent: agents.Agent{Name: "omp", Title: "oh-my-pi", CLI: omp.CLI, Page: omp.Page, Needs: omp.Needs, Tested: omp.Tested},
			Chats: chats.Kind{Resume: omp.Resume, OneWriter: true, Dialect: chats.Dialect{Other: omp.Other, ToolCall: omp.ToolCall}},
			Local: func(k *chats.Kind) { k.OpenElsewhere, k.Forked = omp.OpenElsewhere, omp.Forked },
			Start: func(dir string, r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
				return omp.Start(dir, r.CLI, r.Env, h, log)
			},
			Skills: ompskills.OMP{}, Trust: omptrust.Trust{},
		},
		{
			Agent: agents.Agent{Name: "pig", Title: "PiG", CLI: pig.CLI, Page: pig.Page, Tested: pig.Tested},
			Chats: chats.Kind{Resume: pig.Resume, Gone: chats.NotFound, Dialect: chats.Dialect{ForkAt: pig.ForkAt, Context: pig.Context}},
			Start: func(dir string, r agents.Run, h acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
				return pig.Start(dir, r.Env, h, log)
			},
			Skills: pigskills.PiG{}, Trust: pig.Trust{},
		},
	}
	for i := range all {
		a := &all[i]
		a.Chats.Name, a.Chats.Title, a.Chats.MCP = a.Agent.Name, a.Agent.Title, a.MCP != nil
	}
	return all
}
