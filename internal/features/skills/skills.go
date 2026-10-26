// Package skills shows the skills and plugins the agent uses in a folder
// and changes them the ways the agent documents (ADR 0051). The agent's
// own files are the source of truth; Nushi keeps no copy. Claude-only, as
// the MCP view: its sources (yours, the project's, plugins', built in),
// skillOverrides and `claude plugin` are Claude Code's.
package skills

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"

	"github.com/afrase/nushi/internal/model"
)

// Source is the agent's skills (Claude's: internal/claudeskills).
type Source interface {
	List(ctx context.Context, folder string) (model.Skills, error)
	// SetSkillOn turns a "user" or "project" skill on or off.
	SetSkillOn(ctx context.Context, folder, source, name string, on bool) error
	// SetBuiltInOn turns the agent's built-in skills on or off together.
	SetBuiltInOn(ctx context.Context, folder string, on bool) error
	SetPluginOn(ctx context.Context, folder, id string, on bool) error
	Uninstall(ctx context.Context, folder, id string) error
	// Trash moves a skill's folder to the Trash.
	Trash(ctx context.Context, folder, path string) error
	// PluginScope is where SetPluginOn changes a plugin for folder:
	// "user" (everywhere) or "local" (this project).
	PluginScope(folder string, p model.Plugin) string
}

type Service struct{ source Source }

func New(source Source) *Service { return &Service{source: source} }

func absolute(folder string) error {
	if !filepath.IsAbs(folder) || filepath.Clean(folder) != folder {
		return fmt.Errorf("%q is not an absolute folder", folder)
	}
	return nil
}

// List returns folder's skills and plugins.
func (s *Service) List(ctx context.Context, folder string) (model.Skills, error) {
	if err := absolute(folder); err != nil {
		return model.Skills{}, err
	}
	return s.source.List(ctx, folder)
}

// PluginScope is where a plugin's switch acts for folder.
func (s *Service) PluginScope(folder string, p model.Plugin) string {
	return s.source.PluginScope(folder, p)
}

// The changes run to the end once begun, even if the app goes: a CLI
// killed while it writes Claude's settings could leave them half written.

// SetSkillOn turns a skill on or off: source "user" or "project", or
// "builtin" (name empty) for the built-in skills together.
func (s *Service) SetSkillOn(ctx context.Context, folder, source, name string, on bool) error {
	ctx = context.WithoutCancel(ctx)
	if err := absolute(folder); err != nil {
		return err
	}
	switch source {
	case "builtin":
		return s.source.SetBuiltInOn(ctx, folder, on)
	case "user", "project":
		return s.source.SetSkillOn(ctx, folder, source, name, on)
	case "plugin":
		return errors.New("a plugin's skills go on and off with their plugin")
	}
	return fmt.Errorf("no skills come from %q", source)
}

func (s *Service) SetPluginOn(ctx context.Context, folder, id string, on bool) error {
	if err := absolute(folder); err != nil {
		return err
	}
	return s.source.SetPluginOn(context.WithoutCancel(ctx), folder, id, on)
}

func (s *Service) Uninstall(ctx context.Context, folder, id string) error {
	if err := absolute(folder); err != nil {
		return err
	}
	return s.source.Uninstall(context.WithoutCancel(ctx), folder, id)
}

func (s *Service) Trash(ctx context.Context, folder, path string) error {
	if err := absolute(folder); err != nil {
		return err
	}
	return s.source.Trash(context.WithoutCancel(ctx), folder, path)
}
