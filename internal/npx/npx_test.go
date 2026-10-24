package npx

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// A fake npx names the program it was asked for, in its .bin folder.
func TestCommand(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, "cache", ".bin")
	script := "#!/bin/sh\n[ \"$*\" = '--yes -p a@1 -p b@2 -c command -v prog' ] && echo " + bin + "/prog\n"
	if err := os.WriteFile(filepath.Join(dir, "npx"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir+":/bin:/usr/bin")
	cmd, err := Command(dir, []string{"a@1", "b@2"}, "prog", "--mode", "acp")
	if err != nil {
		t.Fatal(err)
	}
	if cmd.Path != bin+"/prog" || !slices.Equal(cmd.Args[1:], []string{"--mode", "acp"}) || cmd.Dir != dir ||
		!strings.HasPrefix(cmd.Env[len(cmd.Env)-1], "PATH="+bin+":"+dir) {
		t.Errorf("%s %q in %s, %s", cmd.Path, cmd.Args, cmd.Dir, cmd.Env[len(cmd.Env)-1])
	}
	if _, err := Command(dir, []string{"a@1"}, "prog"); err == nil {
		t.Error("no error when npx names nothing")
	}
}
