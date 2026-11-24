package updates

import (
	"context"
	"log/slog"

	"github.com/afrase/nushi/internal/model"
)

// logged is how much of Homebrew's output a failed install leaves in the
// log: its end, where it says why.
const logged = 4 << 10

// Install has Homebrew upgrade the cask whose upgrade brings the newer
// version found (ADR 0109), and returns once that has started: how it
// goes is in Get and the update event (Installing, then InstallError or
// Installed). One at a time. It takes nothing from its caller, and of
// the check's answer only the version: Homebrew's own casks say, asked
// again now (a cask swapped since the check needs no restart), which one
// brings it, and none is refused.
func (s *Service) Install() error {
	if s.Brew == nil {
		return ErrNotHomebrew
	}
	cask, err := s.caskLocked()
	if err != nil {
		return err
	}
	defer s.mu.Unlock()
	s.found.Installing, s.found.InstallError, s.found.Cask = true, "", cask
	found := s.found
	s.publish(model.Event{Update: &found})
	go s.install(cask, found.Version)
	return nil
}

// caskLocked is the cask that brings the version found, asked of
// Homebrew outside mu (it looks at folders) and returned with mu held
// for a version still current; an error, with mu not held, when there is
// nothing to install or nothing to install it with.
func (s *Service) caskLocked() (string, error) {
	for {
		version := s.Get().Version
		cask := ""
		if version != "" {
			cask = s.Brew.For(version)
		}
		s.mu.Lock()
		switch {
		case s.found.Installing:
			s.mu.Unlock()
			return "", ErrInstalling
		case s.found.Version == "":
			s.mu.Unlock()
			return "", ErrNoUpdate
		case s.found.Version != version:
			s.mu.Unlock()
			continue // a check found another meanwhile: ask for that one
		case cask == "":
			s.mu.Unlock()
			return "", ErrNotHomebrew
		}
		return cask, nil
	}
}

// install runs the upgrade and says how it ended. It runs as long as the
// daemon, whatever becomes of the app that asked: Homebrew quits it. An
// upgrade that leaves the cask without the version is a failure too: a
// release is on GitHub some minutes before its cask is in the tap.
func (s *Service) install(cask, version string) {
	slog.Info("installing an update with Homebrew", "cask", cask, "version", version)
	out, err := s.Brew.Upgrade(context.Background(), cask, version)
	failed := ""
	switch {
	case err != nil:
		failed = err.Error()
		slog.Warn("Homebrew's upgrade failed", "cask", cask, "err", err, "output", out[max(0, len(out)-logged):])
	case !s.Brew.Has(cask, version):
		failed = "Homebrew doesn't have " + version + " yet. Try again in a few minutes."
		slog.Info("Homebrew's cask doesn't have the version yet", "cask", cask, "version", version)
	default:
		slog.Info("update installed", "cask", cask, "version", version)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.found.Installing, s.found.InstallError = false, failed
	if failed == "" {
		s.found.Installed = version
	}
	found := s.found
	s.publish(model.Event{Update: &found})
}

// Busy says whether an install runs: the daemon's restart into a newer
// build waits for it (internal/features/restart), so the new app, which
// Homebrew opens before it has finished, doesn't end the daemon under it.
func (s *Service) Busy() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.found.Installing
}

// Running is nothing: an install is in no chat, so the restart's bar has
// no link to show for the seconds it holds.
func (*Service) Running() []model.Hold { return nil }
