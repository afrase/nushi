package realpath

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Within answers by either spelling, and refuses what is outside by both:
// a way out through "..", a sibling whose name starts with dir's, and a
// spelling in another case (compared as spelled, on any volume).
func TestWithin(t *testing.T) {
	root := t.TempDir() // on macOS, under /var, a link to /private/var
	app, sibling, elsewhere := filepath.Join(root, "app"), filepath.Join(root, "app-x"), filepath.Join(root, "elsewhere")
	for _, dir := range []string{filepath.Join(app, "sub"), sibling, elsewhere} {
		testcheck.NoErr(t, os.MkdirAll(dir, 0o700))
	}
	link := filepath.Join(root, "link") // to app, from outside it
	testcheck.NoErr(t, os.Symlink(app, link))
	out := filepath.Join(app, "out") // a link in app that leads out of it
	testcheck.NoErr(t, os.Symlink(elsewhere, out))
	resolved := Of(app)
	for _, tc := range []struct {
		name, path, dir string
		want            bool
	}{
		{"dir itself", app, app, true},
		{"a folder in it", filepath.Join(app, "sub"), app, true},
		{"a file not made yet", filepath.Join(app, "sub", "new.txt"), app, true},
		{"through a link to it", filepath.Join(link, "sub"), app, true},
		{"by its real path", filepath.Join(resolved, "sub"), app, true},
		{"its real path in its linked spelling", filepath.Join(resolved, "sub"), link, true},
		{"a link in it that leads out", out, app, true}, // removing app removes it
		{"what the link out leads to", elsewhere, app, false},
		{"out through ..", filepath.Join(app, "..", "elsewhere"), app, false},
		{"out through .. of a link", filepath.Join(link, "..", "elsewhere"), app, false},
		{"a sibling with dir's name as its start", sibling, app, false},
		{"its parent", root, app, false},
		{"another case", filepath.Join(root, "APP", "sub"), app, false},
		{"another case of dir", filepath.Join(app, "sub"), filepath.Join(root, "App"), false},
		{"no path", "", app, false},
		{"no dir", app, "", false},
	} {
		if got := Within(tc.path, tc.dir); got != tc.want {
			t.Errorf("%s: Within(%q, %q) = %v, want %v", tc.name, tc.path, tc.dir, got, tc.want)
		}
	}
}

// Of resolves links, and leaves a path that can't be resolved cleaned, so
// two spellings of a folder that's gone still compare equal.
func TestOf(t *testing.T) {
	root := t.TempDir()
	app := filepath.Join(root, "app")
	testcheck.NoErr(t, os.Mkdir(app, 0o700))
	link := filepath.Join(root, "link")
	testcheck.NoErr(t, os.Symlink(app, link))
	if Of(link) != Of(app) || Of(app) == "" {
		t.Errorf("Of(%q) = %q, Of(%q) = %q", link, Of(link), app, Of(app))
	}
	if gone := filepath.Join(root, "gone", "x"); Of(gone+"/./") != gone {
		t.Errorf("a gone folder: %q", Of(gone+"/./"))
	}
	if Of("") != "" {
		t.Error(`Of("")`)
	}
}
