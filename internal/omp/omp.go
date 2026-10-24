// Package omp knows what oh-my-pi (omp 18.12.6, `omp --mode acp`) does
// beyond ACP: how to start it, and its quirks. `main` hands these to the
// chats feature, which knows nothing of omp.
package omp

import (
	"log"
	"os/exec"
	"strings"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// omp needs Bun (it can't run under Node): npx brings a pinned Bun beside
// it, whose bin its `#!/usr/bin/env bun` finds on the PATH npx sets.
const (
	pkg = "@oh-my-pi/pi-coding-agent@18.12.6"
	bun = "bun@1.4.3"
)

// Start starts omp's ACP mode, as claude.Start does Claude's adapter: in
// dir (the daemon's folder), its stderr to the daemon log. omp reads its
// own config and keys (~/.omp, the environment); Nushi never does.
func Start(dir string, h acp.Handler) (*acp.Client, error) {
	cmd := exec.Command("npx", "--yes", "-p", bun, "-p", pkg, "omp", "--mode", "acp")
	cmd.Dir = dir
	cmd.Stderr = log.Writer()
	return acp.Start(cmd, h)
}

// Resume is the terminal command that opens an omp session by its id.
const Resume = "omp --resume"

// Other says field is the free-text answer omp puts after a question with
// choices: `<id>__other`, "Other (type your own)".
func Other(field, before model.Field) bool {
	return len(field.Options) == 0 && strings.HasPrefix(field.ID, before.ID+"__other")
}
