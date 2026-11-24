package relayupdate

import (
	"bytes"
	"context"
	"debug/elf"
	"fmt"
	"os/exec"
	"runtime"
	"strings"
	"time"
)

// machines is each architecture a release builds a relay for, as ELF
// names it.
var machines = map[string]elf.Machine{
	"amd64": elf.EM_X86_64,
	"arm64": elf.EM_AARCH64,
}

// CheckBinary is the check of a new relay before it takes this one's
// place, as far as is cheap: a Linux program for this machine, which says
// it is that version when asked.
func CheckBinary(ctx context.Context, path, version string) error {
	if err := checkMachine(path, runtime.GOARCH); err != nil {
		return err
	}
	return checkVersion(ctx, path, version)
}

// checkMachine refuses a file that isn't an ELF program for goarch.
func checkMachine(path, goarch string) error {
	want, ok := machines[goarch]
	if !ok {
		return fmt.Errorf("a release has no relay for %s", goarch)
	}
	f, err := elf.Open(path)
	if err != nil {
		return fmt.Errorf("the new file isn't a Linux program: %w", err)
	}
	defer f.Close() //nolint:errcheck // read only
	if f.Machine != want {
		return fmt.Errorf("the new file is for %s, not this machine's %s", f.Machine, want)
	}
	return nil
}

// checkVersion runs `<path> -version` with an empty environment for a few
// seconds at most, and wants it to print "nushi-relay <version>".
func checkVersion(ctx context.Context, path, version string) error {
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, path, "-version")
	cmd.Env = []string{}
	cmd.Dir = "/"
	out := &capped{max: 4096}
	cmd.Stdout, cmd.Stderr = out, out
	cmd.WaitDelay = time.Second
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("the new file's -version failed: %w: %s", err, bytes.TrimSpace(out.buf.Bytes()))
	}
	want := "nushi-relay " + version
	if got := strings.TrimSpace(out.buf.String()); got != want {
		return fmt.Errorf("the new file's -version says %q, not %q", got, want)
	}
	return nil
}

// capped keeps the first max bytes written to it and drops the rest.
type capped struct {
	buf bytes.Buffer
	max int
}

func (c *capped) Write(p []byte) (int, error) {
	if room := c.max - c.buf.Len(); room > 0 {
		c.buf.Write(p[:min(len(p), room)])
	}
	return len(p), nil
}
