package git

import "testing"

func TestRemotes(t *testing.T) {
	repo := t.TempDir()
	git(t, repo, "init", "-q", "-b", "main")
	if rs, err := Remotes(t.Context(), repo); err != nil || len(rs) != 0 {
		t.Fatalf("%+v %v", rs, err)
	}
	git(t, repo, "remote", "add", "origin", "git@github.com:afrase/nushi.git")
	git(t, repo, "remote", "add", "up", "https://github.com/someone/nushi")
	git(t, repo, "remote", "set-url", "--push", "up", "no_push")
	rs, err := Remotes(t.Context(), repo)
	if err != nil || len(rs) != 2 || rs[0] != (Remote{"origin", "git@github.com:afrase/nushi.git"}) || rs[1].URL != "https://github.com/someone/nushi" {
		t.Fatalf("%+v %v", rs, err)
	}
	if _, err := Remotes(t.Context(), t.TempDir()); err == nil {
		t.Fatal("a folder outside git")
	}
}
