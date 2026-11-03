package knownagents

import (
	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/claudeskills"
	"github.com/afrase/nushi/internal/codex"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/skills"
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/pi"
)

// What each harness can do beyond ACP, written down and checked by the
// compiler: chats ask a harness once (ADR 0077), and an agent package
// doesn't import chats, so these are where a changed method fails. A
// Local's lines are what it adds to its Harness.
var (
	_ chats.Forker           = claude.Harness{}
	_ chats.ToolReader       = claude.Harness{}
	_ chats.OtherReader      = claude.Harness{}
	_ chats.DefaultReader    = claude.Harness{}
	_ chats.Transcript       = claude.Harness{}
	_ chats.Subagents        = claude.Harness{}
	_ chats.SubagentMessages = claude.Harness{}
	_ chats.BackgroundTasks  = claude.Harness{}
	_ chats.ContextCommander = claude.Harness{}
	_ chats.ReadOnly         = claude.Harness{}
	_ chats.GoneReader       = claude.Harness{}

	_ chats.HistoryCopier  = claudehistory.Local{}
	_ chats.OpenFinder     = claudehistory.Local{}
	_ chats.ForkFinder     = claudehistory.Local{}
	_ chats.HistoryChecker = claudehistory.Local{}
	_ chats.MessageDater   = claudehistory.Local{}
	_ chats.WorktreeFinder = claudehistory.Local{}

	_ chats.Forker        = codex.Harness{}
	_ chats.ReadOnly      = codex.Harness{}
	_ chats.ToolReader    = codex.Harness{}
	_ chats.OtherReader   = codex.Harness{}
	_ chats.GoneReader    = codex.Harness{}
	_ chats.HistoryCopier = codex.Harness{} // nothing to copy, nothing read

	_ chats.OpenFinder = codex.Local{}
	_ chats.ForkFinder = codex.Local{}

	_ chats.Forker       = ante.Harness{}
	_ chats.OtherReader  = ante.Harness{}
	_ chats.ContextAsker = ante.Harness{}

	_ chats.OpenFinder   = ante.Local{}
	_ chats.MessageDater = ante.Local{}

	_ chats.OtherReader = omp.Harness{}
	_ chats.ToolReader  = omp.Harness{}

	_ chats.OpenFinder = omp.Local{}
	_ chats.ForkFinder = omp.Local{}

	_ chats.Forker       = pi.Harness{}
	_ chats.ContextAsker = pi.Harness{}
	_ chats.GoneReader   = pi.Harness{}

	// The app shows these by what the daemon says, not by the agent's name.
	_ skills.BuiltIn = claudeskills.Claude{}
	_ skills.Plugins = claudeskills.Claude{}
	_ skills.Linker  = claudeskills.Claude{}
)
