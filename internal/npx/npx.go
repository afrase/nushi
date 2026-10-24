// Package npx runs a program from pinned npm packages, as `npx --yes -p …`
// would, without npx staying on as the program's parent: that npm process
// costs 45–60 MB per agent while the agent runs.
package npx

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Command returns a command that runs program from packages (each pinned,
// such as "@agentclientprotocol/claude-agent-acp@0.94.0") in dir. npx
// installs them into its cache if need be and says where program is, then
// exits; the program's folder goes first on PATH, as npx puts it, for the
// packages' other programs (omp's Bun).
func Command(dir string, packages []string, program string, args ...string) (*exec.Cmd, error) {
	find := []string{"--yes"}
	for _, p := range packages {
		find = append(find, "-p", p)
	}
	where := exec.Command("npx", append(find, "-c", "command -v "+program)...)
	where.Dir = dir
	where.Stderr = log.Writer()
	out, err := where.Output()
	path := strings.TrimSpace(string(out))
	if err == nil && !filepath.IsAbs(path) {
		err = fmt.Errorf("it named %q", path)
	}
	if err != nil {
		return nil, fmt.Errorf("npx didn't find %s: %w", program, err)
	}
	cmd := exec.Command(path, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "PATH="+filepath.Dir(path)+string(filepath.ListSeparator)+os.Getenv("PATH"))
	return cmd, nil
}
