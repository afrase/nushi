package knownagents

import (
	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/codex"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/omp"
	"github.com/afrase/nushi/internal/pig"
)

// What each harness can do beyond ACP, written down and checked by the
// compiler: chats ask a harness once (ADR 0077), and an agent package
// doesn't import chats, so these are where a changed method fails. A
// Local's lines are what it adds to its Harness.
var (
	_ Harness                = claude.Harness{}
	_ chats.Meta             = claude.Harness{}
	_ chats.Forker           = claude.Harness{}
	_ chats.ToolReader       = claude.Harness{}
	_ chats.OtherReader      = claude.Harness{}
	_ chats.DefaultReader    = claude.Harness{}
	_ chats.Transcript       = claude.Harness{}
	_ chats.Subagents        = claude.Harness{}
	_ chats.BackgroundTasks  = claude.Harness{}
	_ chats.ContextCommander = claude.Harness{}
	_ chats.GoneReader       = claude.Harness{}

	_ Harness              = claudehistory.Local{}
	_ chats.HistoryCopier  = claudehistory.Local{}
	_ chats.OpenFinder     = claudehistory.Local{}
	_ chats.ForkFinder     = claudehistory.Local{}
	_ chats.HistoryChecker = claudehistory.Local{}
	_ chats.MessageDater   = claudehistory.Local{}

	_ Harness             = codex.Harness{}
	_ chats.Forker        = codex.Harness{}
	_ chats.ToolReader    = codex.Harness{}
	_ chats.OtherReader   = codex.Harness{}
	_ chats.GoneReader    = codex.Harness{}
	_ chats.HistoryCopier = codex.Harness{} // nothing to copy, nothing read

	_ Harness          = codex.Local{}
	_ chats.OpenFinder = codex.Local{}
	_ chats.ForkFinder = codex.Local{}

	_ Harness            = ante.Harness{}
	_ chats.Forker       = ante.Harness{}
	_ chats.OtherReader  = ante.Harness{}
	_ chats.ContextAsker = ante.Harness{}

	_ Harness            = ante.Local{}
	_ chats.OpenFinder   = ante.Local{}
	_ chats.MessageDater = ante.Local{}

	_ Harness           = omp.Harness{}
	_ chats.OtherReader = omp.Harness{}
	_ chats.ToolReader  = omp.Harness{}

	_ Harness          = omp.Local{}
	_ chats.OpenFinder = omp.Local{}
	_ chats.ForkFinder = omp.Local{}

	_ Harness            = pig.Harness{}
	_ chats.Forker       = pig.Harness{}
	_ chats.ContextAsker = pig.Harness{}
	_ chats.GoneReader   = pig.Harness{}
)
