package claudeskills

import (
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/model"
)

// plugin is an installed plugin and its skills.
type plugin struct {
	model.Plugin
	skills []model.Skill
}

// listPlugins asks Claude for the plugins installed for folder (`claude
// plugin list --json`, run there: whether one is on is per project), and
// reads what each brings from its folder.
func listPlugins(ctx context.Context, folder string) ([]plugin, error) {
	out, err := claudePlugin(ctx, folder, "list", "--json")
	if err != nil {
		return nil, err
	}
	return parsePlugins(out)
}

// parsePlugins reads `claude plugin list --json`: an array of plugins
// (id, version, scope, enabled, installPath, mcpServers, and more that's
// skipped). One without an id or a folder is left out.
func parsePlugins(out []byte) ([]plugin, error) {
	var list []struct {
		ID          string                     `json:"id"`
		Version     string                     `json:"version"`
		Scope       string                     `json:"scope"`
		Enabled     bool                       `json:"enabled"`
		InstallPath string                     `json:"installPath"`
		MCPServers  map[string]json.RawMessage `json:"mcpServers"`
	}
	if err := json.Unmarshal(out, &list); err != nil {
		return nil, fmt.Errorf("reading claude plugin list: %w", err)
	}
	var plugins []plugin
	for _, l := range list {
		if l.ID == "" || !filepath.IsAbs(l.InstallPath) {
			continue
		}
		name, _, _ := strings.Cut(l.ID, "@")
		p := plugin{ID: l.ID, Name: name, Version: l.Version, Scope: l.Scope,
			Path: l.InstallPath, Enabled: l.Enabled, MCPServers: len(l.MCPServers)}
		p.read()
		plugins = append(plugins, p)
	}
	slices.SortFunc(plugins, func(a, b plugin) int { return cmp.Compare(a.ID, b.ID) })
	return plugins, nil
}

// read reads what a plugin brings from its folder: its manifest's
// description, its skills, and its commands and agents counted, from the
// default folders and those its manifest names inside it.
func (p *plugin) read() {
	var manifest struct {
		Description string          `json:"description"`
		Skills      json.RawMessage `json:"skills"`
		Commands    json.RawMessage `json:"commands"`
		Agents      json.RawMessage `json:"agents"`
	}
	if b, err := claudemcp.ReadFile(filepath.Join(p.Path, ".claude-plugin", "plugin.json")); err == nil {
		_ = json.Unmarshal(b, &manifest) // what's missing stays empty
	}
	p.Description = manifest.Description
	for _, dir := range p.folders("skills", manifest.Skills) {
		p.skills = append(p.skills, read(dir, "plugin")...)
	}
	p.Skills = len(p.skills)
	for _, dir := range p.folders("commands", manifest.Commands) {
		p.Commands += count(dir)
	}
	for _, dir := range p.folders("agents", manifest.Agents) {
		p.Agents += count(dir)
	}
}

// folders are the default folder of a kind and those the manifest names
// (a path or a list of them), each inside the plugin's folder.
func (p *plugin) folders(kind string, named json.RawMessage) []string {
	dirs := []string{filepath.Join(p.Path, kind)}
	var paths []string
	if json.Unmarshal(named, &paths) != nil {
		var one string
		if json.Unmarshal(named, &one) == nil {
			paths = []string{one}
		}
	}
	for _, rel := range paths {
		dir := filepath.Join(p.Path, rel)
		if inside(p.Path, dir) && !slices.Contains(dirs, dir) {
			dirs = append(dirs, dir)
		}
	}
	return dirs
}

// count counts the Markdown files in dir (commands, agents).
func count(dir string) int {
	entries, _ := os.ReadDir(dir)
	n := 0
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".md") && !e.IsDir() {
			n++
		}
	}
	return n
}

// inside says path is root or under it, by name.
func inside(root, path string) bool {
	rel, err := filepath.Rel(root, path)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, "../") && !filepath.IsAbs(rel)
}

// claudePlugin runs `claude plugin <args>` in folder and returns its
// output; on a failure, Claude's message (the JSON one's, if it gave one).
func claudePlugin(ctx context.Context, folder string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "claude", append([]string{"plugin"}, args...)...) //nolint:gosec // the user's claude; ids checked and after --
	cmd.Dir = folder
	var stderr strings.Builder
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err == nil {
		return out, nil
	}
	var result struct {
		Message string `json:"message"`
	}
	if json.Unmarshal(out, &result) == nil && result.Message != "" {
		return out, errors.New(result.Message)
	}
	if msg := strings.TrimSpace(stderr.String()); msg != "" {
		return out, errors.New(msg)
	}
	return out, fmt.Errorf("claude plugin %s: %w", args[0], err)
}
