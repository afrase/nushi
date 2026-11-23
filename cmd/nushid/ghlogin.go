package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"time"

	"gopkg.in/yaml.v3"

	"github.com/afrase/nushi/internal/procgroup"
	"github.com/afrase/nushi/internal/regularfile"
	"github.com/afrase/nushi/internal/shellenv"
)

// ghWait bounds a `gh auth token`: it reads a file or the keychain, so
// longer means a stuck gh, not a slow one.
const ghWait = 10 * time.Second

// ghLogin is gh's login as the daemon reads it (ADR 0045), without a
// library of gh's: the hosts are the keys of gh's hosts.yml, and a host's
// token is what `gh auth token --hostname <host>` prints, gh resolving it
// as it does for itself (the environment's token, its config's, or the
// keychain's). env is the daemon's environment, which gh runs in and whose
// GH_CONFIG_DIR, XDG_CONFIG_HOME, GH_HOST and GH_PATH count, as they did
// for go-gh; lookPath finds gh on the login shell's PATH, as other
// programs are found (ADR 0048).
type ghLogin struct {
	env      func() []string
	lookPath func(name string) string
}

// Token is host's token from gh and where it came from ("gh"), "" when gh
// has none or isn't installed. A `gh auth token` the request or ghWait cut
// short is an error, not gh having no token; so is a token in the
// environment or gh's config that only gh would have read, gh being gone
// or failing, so Settings › GitHub says why the host isn't signed in. gh's output is
// never logged: its stdout is the token, its stderr dropped.
func (g ghLogin) Token(ctx context.Context, host string) (string, string, error) {
	env := shellenv.Merge(g.env(), nil) // without Nushi's own variables
	gh := shellenv.Get(env, "GH_PATH")
	if gh == "" {
		gh = g.lookPath("gh")
	}
	if gh == "" {
		if why := unread(env, host); why != "" {
			return "", "gh", fmt.Errorf("%s, but Nushi reads it through gh, which isn't installed (not on your login shell's PATH): install gh, or add a token in Settings › GitHub", why)
		}
		return "", "gh", nil
	}
	ctx, cancel := context.WithTimeout(ctx, ghWait)
	defer cancel()
	cmd := exec.CommandContext(ctx, gh, "auth", "token", "--hostname", host) //nolint:gosec // gh for a known host; the token comes on stdout
	cmd.Env = env
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if ctx.Err() != nil {
		return "", "gh", fmt.Errorf("asking gh for %s's token: %w", host, ctx.Err())
	}
	if err != nil {
		// gh has no token for host, or gh can't give one (older than `gh
		// auth token`, or unable to run here); a token only gh would read
		// says which. What gh said may name the token, so it isn't kept.
		if why := unread(env, host); why != "" {
			return "", "gh", fmt.Errorf("%s, but `gh auth token` failed for %s: update gh (or check it runs outside your shell), or add a token in Settings › GitHub", why, host)
		}
		return "", "gh", nil
	}
	return strings.TrimSpace(string(out)), "gh", nil
}

// Hosts are the hosts gh knows, as go-gh's KnownHosts had them: GH_HOST,
// github.com when GH_TOKEN or GITHUB_TOKEN is set, and the keys of gh's
// hosts.yml, read afresh each time so a `gh auth login` since shows.
func (g ghLogin) Hosts() []string {
	env := g.env()
	var hosts []string
	add := func(h string) {
		if h != "" && !slices.Contains(hosts, h) {
			hosts = append(hosts, h)
		}
	}
	add(shellenv.Get(env, "GH_HOST"))
	if shellenv.Get(env, "GH_TOKEN") != "" || shellenv.Get(env, "GITHUB_TOKEN") != "" {
		add("github.com")
	}
	for _, h := range ghHostsFile(env) {
		add(h.name)
	}
	return hosts
}

// ghHost is a host in gh's hosts.yml, and whether gh keeps its token
// there (insecure storage) rather than in the keychain. The token itself
// is never read into it.
type ghHost struct {
	name  string
	token bool
}

// ghHostsFile is the hosts in gh's hosts.yml (nil when there's none, or
// it isn't gh's YAML): a mapping of host names, each to its settings.
func ghHostsFile(env []string) []ghHost {
	data, err := regularfile.Read(filepath.Join(ghConfigDir(env), "hosts.yml"), 1<<20)
	if err != nil {
		return nil
	}
	var doc yaml.Node
	if yaml.Unmarshal(data, &doc) != nil || len(doc.Content) != 1 || doc.Content[0].Kind != yaml.MappingNode {
		return nil
	}
	m := doc.Content[0].Content
	var out []ghHost
	for i := 0; i+1 < len(m); i += 2 {
		h := ghHost{name: m[i].Value}
		if v := m[i+1]; v.Kind == yaml.MappingNode {
			for j := 0; j+1 < len(v.Content); j += 2 {
				if v.Content[j].Value == "oauth_token" && v.Content[j+1].Value != "" {
					h.token = true
				}
			}
		}
		out = append(out, h)
	}
	return out
}

// ghConfigDir is gh's config folder, found as gh finds it: GH_CONFIG_DIR,
// else XDG_CONFIG_HOME/gh, else on Windows %AppData%\GitHub CLI, else
// ~/.config/gh.
func ghConfigDir(env []string) string {
	if d := shellenv.Get(env, "GH_CONFIG_DIR"); d != "" {
		return d
	}
	if d := shellenv.Get(env, "XDG_CONFIG_HOME"); d != "" {
		return filepath.Join(d, "gh")
	}
	if d := shellenv.Get(env, "AppData"); runtime.GOOS == "windows" && d != "" {
		return filepath.Join(d, "GitHub CLI")
	}
	home := shellenv.Get(env, "HOME")
	if home == "" {
		home, _ = os.UserHomeDir()
	}
	return filepath.Join(home, ".config", "gh")
}

// unread names a token for host that gh would have given but no one reads
// with gh gone or failing: the environment's (GH_TOKEN or GITHUB_TOKEN for
// github.com, a *.ghe.com host or github.localhost; GH_ENTERPRISE_TOKEN or
// GITHUB_ENTERPRISE_TOKEN for any other, as gh's rules go), else one in
// gh's hosts.yml; "" when there's neither.
func unread(env []string, host string) string {
	names := []string{"GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN"}
	if h := strings.ToLower(host); h == "github.com" || strings.HasSuffix(h, ".github.com") || strings.HasSuffix(h, ".ghe.com") ||
		h == "github.localhost" || strings.HasSuffix(h, ".github.localhost") {
		names = []string{"GH_TOKEN", "GITHUB_TOKEN"}
	}
	for _, n := range names {
		if shellenv.Get(env, n) != "" {
			return n + " is set"
		}
	}
	for _, h := range ghHostsFile(env) {
		if h.name == host && h.token {
			return "gh's config has a token for " + host
		}
	}
	return ""
}
