package pig

import "github.com/afrase/nushi/internal/model"

// Trust is PiG's side of the trust card (ADR 0023): it shows nothing.
// PiG keeps its own record of trusted folders (trust.json in its agent
// folder; defaultProjectTrust in its settings) and loads a folder's code
// and settings (.pig's settings, MCP servers, extensions, skills, prompts,
// system prompt; .agents/skills) only for one it trusts; RPC mode can't
// ask, and loads none of them for a folder nobody decided on. What it
// loads regardless is instructions (AGENTS.md, CLAUDE.md), which no card
// shows. So a folder never has PiG run its code unless the user said so
// in PiG.
type Trust struct{}

func (Trust) Runs(string) ([]model.FolderRun, string, error) { return nil, "", nil }

func (Trust) Key(string) string { return "" }

func (Trust) Trusted(string, []string) (bool, error) { return true, nil }
