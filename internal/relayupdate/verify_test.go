package relayupdate

import (
	"bytes"
	"debug/elf"
	"encoding/binary"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// fakeRelay is a tiny program built for goos/goarch into a temp folder.
// The checks only read it.
func fakeRelay(t *testing.T, goos, goarch string) string {
	t.Helper()
	gobin, err := exec.LookPath("go")
	if err != nil {
		testcheck.Lacks(t, "go, to build a program")
	}
	dir := t.TempDir()
	src := filepath.Join(dir, "main.go")
	testcheck.Write(t, src, "package main\n\nfunc main() {}\n")
	out := filepath.Join(dir, "nushi-relay")
	cmd := exec.Command(gobin, "build", "-o", out, src)
	cmd.Env = append(os.Environ(), "GOOS="+goos, "GOARCH="+goarch, "CGO_ENABLED=0", "GOFLAGS=")
	if b, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("go build: %v: %s", err, b)
	}
	return out
}

// elfHeader is a file of only an ELF header of class, type and machine,
// little-endian, with no program or section headers.
func elfHeader(t *testing.T, class elf.Class, typ elf.Type, machine elf.Machine) string {
	t.Helper()
	var b bytes.Buffer
	ident := [elf.EI_NIDENT]byte{0x7f, 'E', 'L', 'F', byte(class), byte(elf.ELFDATA2LSB), byte(elf.EV_CURRENT)}
	var hdr any = &elf.Header64{
		Ident: ident, Type: uint16(typ), Machine: uint16(machine), Version: uint32(elf.EV_CURRENT),
		Ehsize: 64, Phentsize: 56, Shentsize: 64,
	}
	if class == elf.ELFCLASS32 {
		hdr = &elf.Header32{
			Ident: ident, Type: uint16(typ), Machine: uint16(machine), Version: uint32(elf.EV_CURRENT),
			Ehsize: 52, Phentsize: 32, Shentsize: 40,
		}
	}
	testcheck.NoErr(t, binary.Write(&b, binary.LittleEndian, hdr))
	path := filepath.Join(t.TempDir(), "nushi-relay")
	testcheck.NoErr(t, os.WriteFile(path, b.Bytes(), 0o600))
	return path
}

// The ELF check takes a 64-bit Linux executable for this architecture
// only, and refuses anything else without running it.
func TestCheckELF(t *testing.T) {
	arm := fakeRelay(t, "linux", "arm64")
	amd := fakeRelay(t, "linux", "amd64")
	testcheck.NoErr(t, checkELF(arm, "arm64"))
	testcheck.NoErr(t, checkELF(amd, "amd64"))
	if err := checkELF(arm, "amd64"); err == nil || !strings.Contains(err.Error(), "not this machine's EM_X86_64") {
		t.Errorf("arm64 for amd64: %v", err)
	}
	if err := checkELF(amd, "arm64"); err == nil || !strings.Contains(err.Error(), "not this machine's EM_AARCH64") {
		t.Errorf("amd64 for arm64: %v", err)
	}

	whole, err := os.ReadFile(arm)
	testcheck.NoErr(t, err)
	file := func(body string) string {
		p := filepath.Join(t.TempDir(), "nushi-relay")
		testcheck.Write(t, p, body)
		return p
	}
	for _, c := range []struct{ name, path, says string }{
		{"a script", file("#!/bin/sh\necho nushi-relay 1.3.0\n"), "isn't a Linux program"},
		{"empty", file(""), "isn't a Linux program"},
		{"truncated", file(string(whole[:40])), "isn't a Linux program"},
		{"32-bit", elfHeader(t, elf.ELFCLASS32, elf.ET_EXEC, elf.EM_AARCH64), "ELFCLASS32, not 64-bit"},
		{"relocatable", elfHeader(t, elf.ELFCLASS64, elf.ET_REL, elf.EM_AARCH64), "ET_REL, not an executable"},
	} {
		if err := checkELF(c.path, "arm64"); err == nil || !strings.Contains(err.Error(), c.says) {
			t.Errorf("%s: %v, want %q", c.name, err, c.says)
		}
	}
	// The hand-made header itself passes when it says an executable, so
	// the two refusals above are for their class and type alone.
	testcheck.NoErr(t, checkELF(elfHeader(t, elf.ELFCLASS64, elf.ET_DYN, elf.EM_AARCH64), "arm64"))
}
