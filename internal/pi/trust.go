package pi

import (
	"maps"
	"path/filepath"

	"github.com/afrase/nushi/internal/jsonsettings"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/realpath"
)

// Trust is Pi's side of the trust card (ADR 0023): it shows nothing.
// Pi keeps its own record of trusted folders (trust.json in its agent
// folder; defaultProjectTrust in its settings) and loads a folder's code
// and settings (.pi's settings, MCP servers, extensions, skills, prompts,
// system prompt; .agents/skills) only for one it trusts; RPC mode can't
// ask, and loads none of them for a folder nobody decided on. What it
// loads regardless is instructions (AGENTS.md, CLAUDE.md), which no card
// shows. So a folder never has Pi run its code unless the user said so
// in Pi. That holds only of a version with the gate, which Flavor.check
// enforces.
type Trust struct{}

func (Trust) Runs(string) ([]model.FolderRun, string, error) { return nil, "", nil }

func (Trust) Key(string) string { return "" }

func (Trust) Trusted(string, []string) (bool, error) { return true, nil }

// Trusts says f loads folder's own config (its .pi or .pig settings, MCP
// servers, extensions, skills): the nearest decision in its trust.json
// for the folder's real path or one above it (a key cleaned first, so a
// trailing slash matches; the exact key wins over one that only cleans to
// the same folder), else defaultProjectTrust
// "always" in your settings (docs/facts/pig.md's Trust). A file that
// doesn't read decides nothing.
func (f Flavor) Trusts(folder string) bool {
	var read map[string]bool
	_ = jsonsettings.Read(filepath.Join(f.AgentDir(), "trust.json"), &read)
	decisions := make(map[string]bool, len(read))
	for k, v := range read {
		if c := filepath.Clean(k); c != k {
			decisions[c] = v // "<folder>/" matches too, as in PiG
		}
	}
	maps.Copy(decisions, read) // and an exact key wins over one that only cleans to it
	for dir := realpath.Of(folder); ; dir = filepath.Dir(dir) {
		if v, ok := decisions[dir]; ok {
			return v
		}
		if dir == filepath.Dir(dir) {
			break
		}
	}
	var settings struct {
		DefaultProjectTrust string `json:"defaultProjectTrust"`
	}
	_ = jsonsettings.Read(filepath.Join(f.AgentDir(), "settings.json"), &settings)
	return settings.DefaultProjectTrust == "always"
}
