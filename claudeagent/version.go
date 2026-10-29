package claudeagent

import (
	"context"
	"log/slog"
	"os"
	"os/exec"
	"strings"
	"time"
)

// logVersion logs the version of the claude s runs. It is for the log
// only: features are detected from what claude says it supports, never
// from its version, so nothing waits for it. CLAUDEAGENT_SKIP_VERSION=1
// skips it.
func logVersion(ctx context.Context, s Spec, log *slog.Logger) {
	if log == nil || os.Getenv("CLAUDEAGENT_SKIP_VERSION") == "1" {
		return
	}
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, s.Path, "--version") //nolint:gosec // the claude the session runs
	cmd.Env, cmd.Dir = s.Env, s.Dir
	out, err := cmd.Output()
	if err != nil {
		log.Warn("claude --version", "err", err)
		return
	}
	log.Info("claude", "version", strings.TrimSpace(string(out)))
}
