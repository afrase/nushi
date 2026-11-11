package updates

import (
	"context"
	"log/slog"

	"github.com/afrase/nushi/internal/model"
)

// logged is how much of Homebrew's output a failed install leaves in the
// log: its end, where it says why.
const logged = 4 << 10

// Install has Homebrew upgrade the cask that installed this Nushi to the
// newer version found (ADR 0109), and returns once that has started: how
// it goes is in Get and the update event (Installing, then InstallError
// or Installed). One at a time. It takes nothing from its caller, and of
// the check's answer only the version to look for afterwards: Homebrew's
// own cask says what is installed.
func (s *Service) Install() error {
	if s.Brew == nil {
		return ErrNotHomebrew
	}
	cask := s.Brew.Installed()
	if cask == "" {
		return ErrNotHomebrew
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	switch {
	case s.found.Installing:
		return ErrInstalling
	case s.found.Version == "":
		return ErrNoUpdate
	}
	s.found.Installing, s.found.InstallError = true, ""
	found := s.found
	s.publish(model.Event{Update: &found})
	go s.install(cask, found.Version)
	return nil
}

// install runs the upgrade and says how it ended. It runs as long as the
// daemon, whatever becomes of the app that asked: Homebrew quits it. An
// upgrade that leaves the cask without the version is a failure too: a
// release is on GitHub some minutes before its cask is in the tap.
func (s *Service) install(cask, version string) {
	slog.Info("installing an update with Homebrew", "cask", cask, "version", version)
	out, err := s.Brew.Upgrade(context.Background(), cask)
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
