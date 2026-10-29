package githubapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
)

// A branch's ref on GitHub: read, deleted, made again. A branch's name is
// checked as git would take it, and each part of it escaped in the path
// (GitHub reads "a/b" as the branch a/b, not as a%2Fb).

// refPath is /repos/owner/name/git/<kind>/heads/<branch>, its parts
// escaped.
func refPath(repo, kind, branch string) (string, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return "", err
	}
	if !branchRE(branch) {
		return "", fmt.Errorf("%q isn't a branch's name", branch)
	}
	parts := strings.Split(branch, "/")
	for i, p := range parts {
		parts[i] = url.PathEscape(p)
	}
	return "/repos/" + url.PathEscape(owner) + "/" + url.PathEscape(name) + "/git/" + kind + "/heads/" + strings.Join(parts, "/"), nil
}

// branchRE refuses what git wouldn't take for a branch (git
// check-ref-format's rules) or what reads as an option.
func branchRE(b string) bool {
	if b == "" || len(b) > 255 || strings.HasPrefix(b, "-") || strings.HasPrefix(b, "/") || strings.HasSuffix(b, "/") ||
		strings.HasSuffix(b, ".") || strings.Contains(b, "..") || strings.Contains(b, "//") || strings.Contains(b, "@{") ||
		strings.ContainsAny(b, " ~^:?*[\\\x7f") {
		return false
	}
	for _, r := range b {
		if r < ' ' {
			return false
		}
	}
	for p := range strings.SplitSeq(b, "/") {
		if strings.HasPrefix(p, ".") || strings.HasSuffix(p, ".lock") {
			return false
		}
	}
	return true
}

// BranchHead is the commit a branch of repo points at; ErrNotFound when
// it has none (deleted).
func (c *Client) BranchHead(ctx context.Context, repo, branch string) (string, error) {
	path, err := refPath(repo, "ref", branch)
	if err != nil {
		return "", err
	}
	a, err := c.send(ctx, http.MethodGet, "/repos/{}/{}/git/ref/heads/{}", c.rest+path, "core", nil, false)
	if err != nil {
		return "", err
	}
	var ref struct {
		Ref    string `json:"ref"`
		Object struct {
			SHA string `json:"sha"`
		} `json:"object"`
	}
	if err := json.Unmarshal(a.body, &ref); err != nil {
		return "", err
	}
	// GitHub answers a prefix of several refs with a list: not this one.
	if ref.Ref != "refs/heads/"+branch || ref.Object.SHA == "" {
		return "", ErrNotFound
	}
	return ref.Object.SHA, nil
}

// DeleteBranch deletes a branch of repo; one already gone is ErrNotFound.
func (c *Client) DeleteBranch(ctx context.Context, repo, branch string) error {
	path, err := refPath(repo, "refs", branch)
	if err != nil {
		return err
	}
	_, err = c.send(ctx, http.MethodDelete, "/repos/{}/{}/git/refs/heads/{}", c.rest+path, "core", nil, true)
	var api *APIError
	if errors.As(err, &api) && api.Status == http.StatusUnprocessableEntity && strings.Contains(api.Message, "does not exist") {
		return ErrNotFound
	}
	return err
}

// CreateBranch makes a branch of repo at the commit sha.
func (c *Client) CreateBranch(ctx context.Context, repo, branch, sha string) error {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return err
	}
	if !branchRE(branch) {
		return fmt.Errorf("%q isn't a branch's name", branch)
	}
	payload, _ := json.Marshal(map[string]string{"ref": "refs/heads/" + branch, "sha": sha})
	path := "/repos/{}/{}/git/refs"
	_, err = c.send(ctx, http.MethodPost, path, c.rest+fill(path, []string{owner, name}), "core", payload, true)
	return err
}

// DefaultBranch is repo's default branch.
func (c *Client) DefaultBranch(ctx context.Context, repo string) (string, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return "", err
	}
	var r struct {
		DefaultBranch string `json:"default_branch"`
	}
	if _, err := c.get(ctx, "/repos/{}/{}", []string{owner, name}, nil, &r); err != nil {
		return "", err
	}
	return r.DefaultBranch, nil
}
