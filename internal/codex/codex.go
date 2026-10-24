// Package codex knows what Codex's ACP adapter (codex-acp 2.2.2, which
// runs Codex 0.160.1) does beyond ACP: how to start it, and its quirks.
// `main` hands these to the chats feature, which knows nothing of Codex.
package codex

import (
	"log"
	"os/exec"

	"github.com/afrase/nushi/acp"
)

// adapter is the pinned Codex ACP adapter; it brings its own Codex.
const adapter = "@agentclientprotocol/codex-acp@2.2.2"

// Start starts the adapter, as claude.Start does Claude's: in dir (the
// daemon's own folder), its stderr to the daemon log. Codex reads its own
// config and login ($CODEX_HOME, else ~/.codex); Nushi never does.
func Start(dir string, h acp.Handler) (*acp.Client, error) {
	cmd := exec.Command("npx", "--yes", adapter)
	cmd.Dir = dir
	cmd.Stderr = log.Writer()
	return acp.Start(cmd, h)
}

// Resume is the terminal command that opens a Codex session by its id.
const Resume = "codex resume"

// History makes a session ready to fork into another folder: nothing to
// do, since Codex finds a session by its id whatever the folder, and forks
// it with another cwd.
func History(sessionID, from, to string) (remove func() error, err error) {
	return func() error { return nil }, nil
}
