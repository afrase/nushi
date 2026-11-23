package pi

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/testcheck"
)

// find goes to the file Pi named for the session
// (`<folder>/<time>_<id>.jsonl`, docs/facts/pig.md) and reads only its
// header, not every session's: here a file of another name, which a walk
// would read first, says the same id in another folder. A file Pi didn't
// name so is still found by the walk.
func TestFindGoesToTheNamedFile(t *testing.T) {
	d := Dirs{Sessions: t.TempDir()}
	work, elsewhere := t.TempDir(), t.TempDir()
	const id, other = "01a171d2-0000-7000-8000-000000000001", "01a171d2-0000-7000-8000-000000000002"
	head := func(id, cwd string) string {
		return testcheck.JSON(t, map[string]any{"type": "session", "version": 3, "id": id, "cwd": cwd}) + "\n"
	}
	named := filepath.Join(d.Sessions, "--work--", "2026-11-23T10-00-00-000Z_"+id+".jsonl")
	testcheck.Write(t, named, head(id, work))
	testcheck.Write(t, filepath.Join(d.Sessions, "--a--", "copy.jsonl"), head(id, elsewhere))
	renamed := filepath.Join(d.Sessions, "--b--", "renamed.jsonl")
	testcheck.Write(t, renamed, head(other, work))

	if got, err := d.find(id, work); err != nil || got != named {
		t.Errorf("find = %q, %v; want %q", got, err, named)
	}
	if got, err := d.find(other, work); err != nil || got != renamed {
		t.Errorf("find of a renamed file = %q, %v; want %q", got, err, renamed)
	}
	if _, err := d.find(id, elsewhere); err == nil {
		t.Error("found a session in another folder")
	}
	var e *acp.Error
	if _, err := d.find("*", ""); !errors.As(err, &e) || e.Code != acp.ErrorCodeResourceNotFound {
		t.Errorf("find of a pattern = %v; want not found", err)
	}
	if err := d.remove(t.Context(), id); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(named); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("remove left %s: %v", named, err)
	}
}
