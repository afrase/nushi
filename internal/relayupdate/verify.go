package relayupdate

import (
	"context"
	"debug/elf"
	"fmt"
	"runtime"
)

// machines is each architecture a release builds a relay for, as ELF
// names it.
var machines = map[string]elf.Machine{
	"amd64": elf.EM_X86_64,
	"arm64": elf.EM_AARCH64,
}

// CheckBinary is the check of a new relay before it takes this one's
// place: its header must say a 64-bit Linux program for this machine. It
// reads the file and never runs it, since -update usually runs as root
// and running what it downloaded would hand the release's publisher root
// before anyone chose to run it (ADR 0149). An update whose context has
// ended (^C, a hangup) stops here, so the staged file is discarded.
func CheckBinary(ctx context.Context, path string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	return checkELF(path, runtime.GOARCH)
}

// checkELF refuses a file that isn't a 64-bit ELF executable (ET_EXEC or
// ET_DYN) for goarch.
func checkELF(path, goarch string) error {
	want, ok := machines[goarch]
	if !ok {
		return fmt.Errorf("a release has no relay for %s", goarch)
	}
	f, err := elf.Open(path)
	if err != nil {
		return fmt.Errorf("the new file isn't a Linux program: %w", err)
	}
	defer f.Close() //nolint:errcheck // read only
	switch {
	case f.Class != elf.ELFCLASS64:
		return fmt.Errorf("the new file is %s, not 64-bit", f.Class)
	case f.Type != elf.ET_EXEC && f.Type != elf.ET_DYN:
		return fmt.Errorf("the new file is %s, not an executable", f.Type)
	case f.Machine != want:
		return fmt.Errorf("the new file is for %s, not this machine's %s", f.Machine, want)
	}
	return nil
}
