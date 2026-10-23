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
)

// Mask stands in for env and header values, which never leave the daemon.
const Mask = "••••"

// masked is a server's config with its env and header values replaced by
// Mask.
func masked(config string) string {
	cfg, err := decode(config)
	if err != nil {
		return "{}"
	}
	for _, key := range []string{"env", "headers"} {
		if m, ok := cfg[key].(map[string]any); ok {
			for k := range m {
				m[k] = Mask
			}
		}
	}
	b, _ := json.Marshal(cfg)
	return string(b)
}

func decode(config string) (map[string]any, error) {
	var cfg map[string]any
	if err := json.Unmarshal([]byte(config), &cfg); err != nil || cfg == nil {
		return nil, errors.New("the config isn't a JSON object")
	}
	return cfg, nil
}

var validName = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

// check refuses what the agent would refuse anyway, with a clearer reason.
func check(folder, scope, name, config string) error {
	switch {
	case !slices.Contains([]string{"user", "project", "local"}, scope):
		return fmt.Errorf("servers can't be added to %q here", scope)
	case !filepath.IsAbs(folder):
		return errors.New("project and local servers need a folder")
	case !validName.MatchString(name):
		return errors.New("a name can only have letters, digits, - and _")
	}
	_, err := decode(config)
	return err
}

// Add adds a server to a scope; folder names the project for project and
// local scope.
func (s *Service) Add(ctx context.Context, folder, scope, name, config string) error {
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
			return fmt.Errorf("%w; putting the old config back failed too: %v", err, back)
		}
		return err
	}
	s.notify(folder, scope)
	return nil
}

// Remove removes a server from a scope.
func (s *Service) Remove(ctx context.Context, folder, scope, name string) error {
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

// unmasked is config with each env or header value that is Mask taken from
// old.
func unmasked(config, old string) (string, error) {
	cfg, err := decode(config)
	if err != nil {
		return "", err
	}
	was, _ := decode(old)
	for _, key := range []string{"env", "headers"} {
		m, _ := cfg[key].(map[string]any)
		prev, _ := was[key].(map[string]any)
		for k, v := range m {
			if v == Mask {
				if p, ok := prev[k]; ok {
					m[k] = p
				} else {
					return "", fmt.Errorf("%s %s has no value", strings.TrimSuffix(key, "s"), k)
				}
			}
		}
	}
	b, _ := json.Marshal(cfg)
	return string(b), nil
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
