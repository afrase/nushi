package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"unicode"
)

func decode(config string) (map[string]any, error) {
	var cfg map[string]any
	if err := json.Unmarshal([]byte(config), &cfg); err != nil || cfg == nil {
		return nil, errors.New("the config isn't a JSON object")
	}
	return cfg, nil
}

var validName = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

// target refuses a server the agent's CLI shouldn't be asked about: an
// unknown scope, a folder that isn't absolute and clean (it names the
// project, and the CLI runs in it), or a name that isn't letters, digits,
// - and _ (one starting with "-" would read as a flag).
func target(folder, scope, name string) error {
	switch {
	case !slices.Contains([]string{"user", "project", "local"}, scope):
		return fmt.Errorf("servers can't be changed in %q here", scope)
	case !filepath.IsAbs(folder) || filepath.Clean(folder) != folder:
		return fmt.Errorf("%q is not an absolute folder", folder)
	case !validName.MatchString(name) || strings.HasPrefix(name, "-"):
		return errors.New("a name can only have letters, digits, - and _, and can't start with -")
	}
	return nil
}

// check refuses what the agent would refuse anyway, with a clearer reason.
func check(folder, scope, name, config string) error {
	if err := target(folder, scope, name); err != nil {
		return err
	}
	_, err := decode(config)
	return err
}

// The changes below run to the end once begun, even if the app goes: a
// CLI killed while it writes Claude's config could leave it half written,
// and an edit stopped between its remove and its add would lose the server
// (its secrets the app never had).

// Add adds a server to a scope; folder names the project for project and
// local scope.
func (s *Service) Add(ctx context.Context, folder, scope, name, config string) error {
	ctx = context.WithoutCancel(ctx)
	if err := check(folder, scope, name, config); err != nil {
		return err
	}
	if err := s.config.Add(ctx, folder, scope, name, config); err != nil {
		return err
	}
	s.notify(folder, scope)
	return nil
}

// Edit replaces a server's config, keeping its name and scope. An env or
// header value left as Mask keeps the value it had. It is a remove and an
// add; when the add fails, the old config is put back.
func (s *Service) Edit(ctx context.Context, folder, scope, name, config string) error {
	ctx = context.WithoutCancel(ctx)
	if err := check(folder, scope, name, config); err != nil {
		return err
	}
	old, err := s.stored(folder, scope, name)
	if err != nil {
		return err
	}
	if config, err = unmasked(config, old); err != nil {
		return err
	}
	if err := s.config.Remove(ctx, folder, scope, name); err != nil {
		return err
	}
	if err := s.config.Add(ctx, folder, scope, name, config); err != nil {
		if back := s.config.Add(ctx, folder, scope, name, old); back != nil {
			return fmt.Errorf("%w; putting the old config back failed too: %w", err, back)
		}
		return err
	}
	s.notify(folder, scope)
	return nil
}

// Remove removes a server from a scope.
func (s *Service) Remove(ctx context.Context, folder, scope, name string) error {
	ctx = context.WithoutCancel(ctx)
	if err := target(folder, scope, name); err != nil {
		return err
	}
	if err := s.config.Remove(ctx, folder, scope, name); err != nil {
		return err
	}
	s.notify(folder, scope)
	return nil
}

// stored is a server's config as the agent has it.
func (s *Service) stored(folder, scope, name string) (string, error) {
	servers, err := s.config.Servers(folder)
	if err != nil {
		return "", err
	}
	for _, sv := range servers {
		if sv.Scope == scope && sv.Name == name {
			return sv.Config, nil
		}
	}
	return "", fmt.Errorf("no %s server %q", scope, name)
}

// notify tells the chats the change reaches: every chat for user scope;
// for project and local scope the chats in folder's project or below
// folder (a .mcp.json counts for the folders under it).
func (s *Service) notify(folder, scope string) {
	if s.changed == nil {
		return
	}
	if scope == "user" {
		s.changed(func(string) bool { return true })
		return
	}
	project := s.config.Project(folder)
	s.changed(func(f string) bool {
		return f == folder || strings.HasPrefix(f, folder+"/") || s.config.Project(f) == project
	})
}

// SetOn turns a project's server (its .mcp.json) on, which approves it,
// or off for the project.
func (s *Service) SetOn(ctx context.Context, folder, name string, on bool) error {
	ctx = context.WithoutCancel(ctx)
	if err := target(folder, "project", name); err != nil {
		return err
	}
	if err := s.config.SetOn(ctx, folder, name, on); err != nil {
		return err
	}
	s.notify(folder, "project")
	return nil
}

// Login signs in to a server that needs it (any scope: a plugin's or a
// connector's name too), waiting until the browser is done; Logout forgets
// the sign-in. A sign-in counts wherever the server is used.
func (s *Service) Login(ctx context.Context, folder, name string) error {
	return s.account(ctx, folder, name, s.config.Login)
}

func (s *Service) Logout(ctx context.Context, folder, name string) error {
	return s.account(ctx, folder, name, s.config.Logout)
}

func (s *Service) account(ctx context.Context, folder, name string, do func(context.Context, string, string) error) error {
	if !filepath.IsAbs(folder) || filepath.Clean(folder) != folder {
		return fmt.Errorf("%q is not an absolute folder", folder)
	}
	if name == "" || strings.HasPrefix(name, "-") || strings.ContainsFunc(name, unicode.IsControl) {
		return fmt.Errorf("%q is not a server's name", name)
	}
	if err := do(ctx, folder, name); err != nil {
		return err
	}
	s.notify(folder, "user")
	return nil
}
