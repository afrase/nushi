package github

import (
	"context"
	"net/url"
	"regexp"
	"slices"
	"strings"
	"time"
)

// Repo is a GitHub repository some folders Nushi knows are clones of.
type Repo struct {
	Host, Repo string
	Folders    []string
}

type repoCache struct {
	at    time.Time
	repos [][2]string // host and owner/name
}

// scpRE is git's scp-like address: [user@]host:owner/name.
var scpRE = regexp.MustCompile(`^(?:[^@/]+@)?([^:/]+):([^/].*)$`)

// ParseRemote is the host and owner/name of a git remote's URL that names
// a GitHub repository (https, ssh, or git@host:owner/name), whichever
// host it is on.
func ParseRemote(remote string) (host, repo string, ok bool) {
	var path string
	if m := scpRE.FindStringSubmatch(remote); m != nil && !strings.Contains(remote, "://") {
		host, path = m[1], m[2]
	} else if u, err := url.Parse(remote); err == nil && (u.Scheme == "https" || u.Scheme == "ssh" || u.Scheme == "http" || u.Scheme == "git") {
		host, path = u.Host, u.Path
		if u.Scheme == "ssh" || u.Scheme == "git" {
			host = u.Hostname() // ssh's port isn't the web's
		}
	} else {
		return "", "", false
	}
	host = strings.ToLower(host)
	if host == "ssh.github.com" {
		host = "github.com" // GitHub's ssh over port 443
	}
	parts := strings.Split(strings.Trim(strings.TrimSuffix(strings.Trim(path, "/"), ".git"), "/"), "/")
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" || !hostRE.MatchString(host) {
		return "", "", false
	}
	return host, parts[0] + "/" + parts[1], true
}

// Repos are the GitHub repositories folders are clones of (by their
// remotes), each with its folders. A
// folder's remotes are read again after a minute.
func (s *Service) Repos(ctx context.Context, folders []string) []Repo {
	var out []Repo
	for _, f := range folders {
		for _, r := range s.remotesOf(ctx, f) {
			i := slices.IndexFunc(out, func(x Repo) bool { return x.Host == r[0] && x.Repo == r[1] })
			if i < 0 {
				out = append(out, Repo{Host: r[0], Repo: r[1]})
				i = len(out) - 1
			}
			if !slices.Contains(out[i].Folders, f) {
				out[i].Folders = append(out[i].Folders, f)
			}
		}
	}
	return out
}

func (s *Service) remotesOf(ctx context.Context, folder string) [][2]string {
	s.mu.Lock()
	kept, ok := s.repos[folder]
	s.mu.Unlock()
	if ok && time.Since(kept.at) < time.Minute {
		return kept.repos
	}
	remotes, err := s.Remotes(ctx, folder)
	var repos [][2]string
	if err == nil {
		names := make([]string, 0, len(remotes))
		for name := range remotes {
			names = append(names, name)
		}
		slices.Sort(names)
		for _, name := range names {
			if h, r, ok := ParseRemote(remotes[name]); ok && !slices.Contains(repos, [2]string{h, r}) {
				repos = append(repos, [2]string{h, r})
			}
		}
	}
	s.mu.Lock()
	s.repos[folder] = repoCache{at: time.Now(), repos: repos}
	s.mu.Unlock()
	return repos
}
