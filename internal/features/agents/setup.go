package agents

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"path/filepath"
	"time"
)

// Adapter is the npm package an agent's ACP side comes in (Claude's and
// Codex's), pinned by a lockfile Nushi keeps: every package's version and
// hash. It's installed into Nushi's data folder only when asked (SetUp).
type Adapter struct {
	Lock     fs.FS  // package.json and package-lock.json
	Package  string // the package with the adapter's program
	Bin      string // its program
	Download int64  // about how many bytes it downloads,
	Disk     int64  // and takes on disk (tools/adapters.sh says)
}

// pinned reads the version Lock's package.json pins for Package, and how
// many packages its lockfile installs (optional ones left out).
func (a *Adapter) pinned() (version string, packages int) {
	var pkg struct{ Dependencies map[string]string }
	var lock struct {
		Packages map[string]struct{ Optional, Dev bool }
	}
	b, _ := fs.ReadFile(a.Lock, "package.json")
	json.Unmarshal(b, &pkg)
	b, _ = fs.ReadFile(a.Lock, "package-lock.json")
	json.Unmarshal(b, &lock)
	for path, p := range lock.Packages {
		if path != "" && !p.Optional && !p.Dev {
			packages++
		}
	}
	return pkg.Dependencies[a.Package], packages
}

// Installer installs and removes adapters (internal/npm).
type Installer interface {
	// Install installs lock into folder; ready runs just before the new
	// install replaces what folder had.
	Install(ctx context.Context, lock fs.FS, folder string, ready func()) error
	// Installed says which version of pkg folder has, and its program.
	Installed(folder, pkg, bin string) (version, program string)
	Remove(folder string) error
}

// Chats are the chats feature: an agent's awake chats, which sleep before
// its adapter changes under them.
type Chats interface {
	Awake(agent string) int
	SleepAgent(agent string)
}

// installTimeout bounds an install.
const installTimeout = 5 * time.Minute

// SetUp installs the agent's adapter from its lockfile, or updates it to
// the pinned version. Its awake chats sleep just before the new one
// replaces the old; a message wakes them on the new one.
func (s *Service) SetUp(ctx context.Context, name string) error {
	a, err := s.adapter(name)
	if err != nil {
		return err
	}
	if lookPath("npm", nil) == "" {
		return errors.New("setting up needs npm (Node), and there's none on PATH")
	}
	s.installing.Lock()
	defer s.installing.Unlock()
	ctx, cancel := context.WithTimeout(ctx, installTimeout)
	defer cancel()
	return s.installer.Install(ctx, a.Adapter.Lock, s.folder(name), func() { s.chats.SleepAgent(name) })
}

// Remove removes the agent's adapter; its awake chats sleep first.
func (s *Service) Remove(name string) error {
	if _, err := s.adapter(name); err != nil {
		return err
	}
	s.installing.Lock()
	defer s.installing.Unlock()
	s.chats.SleepAgent(name)
	return s.installer.Remove(s.folder(name))
}

func (s *Service) folder(name string) string { return filepath.Join(s.dir, name) }

func (s *Service) adapter(name string) (Agent, error) {
	for _, a := range s.agents {
		if a.Name == name && a.Adapter != nil {
			return a, nil
		}
		if a.Name == name {
			return a, fmt.Errorf("%s needs nothing set up", a.Title)
		}
	}
	return Agent{}, fmt.Errorf("Nushi doesn't know the agent %q", name)
}
