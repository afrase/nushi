package githubapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
)

// File is a file a pull request changes: its path (and a renamed one's
// earlier path), how ("added", "modified", "removed", "renamed",
// "copied", "changed"), and its lines added and removed.
type File struct {
	Path, OldPath, Status string
	Added, Removed        int
}

// Compare is what head changes since its merge base with base, as a pull
// request's Files tab shows it: the merge base and the files (300 at
// most, GitHub's cap). A comparison of two commits doesn't change, so its
// ETag makes the next ask free.
func (c *Client) Compare(ctx context.Context, repo, base, head string) (mergeBase string, files []File, err error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return "", nil, err
	}
	var r struct {
		MergeBase struct {
			SHA string `json:"sha"`
		} `json:"merge_base_commit"`
		Files []struct {
			Filename         string `json:"filename"`
			PreviousFilename string `json:"previous_filename"`
			Status           string `json:"status"`
			Additions        int    `json:"additions"`
			Deletions        int    `json:"deletions"`
		} `json:"files"`
	}
	// One commit a page: the files come whole with the first.
	if _, err := c.get(ctx, "/repos/{}/{}/compare/{}", []string{owner, name, base + "..." + head}, url.Values{"per_page": {"1"}}, &r); err != nil {
		return "", nil, err
	}
	for _, f := range r.Files {
		files = append(files, File{Path: f.Filename, OldPath: f.PreviousFilename, Status: f.Status, Added: f.Additions, Removed: f.Deletions})
	}
	return r.MergeBase.SHA, files, nil
}

// Blob is a file's text at a commit; Skipped says why there's none
// ("binary", "too large", or "" when the file isn't there).
type Blob struct {
	Text    string
	Skipped string
	Found   bool
}

// BlobAt names a file at a commit.
type BlobAt struct{ Commit, Path string }

// blobsAtOnce is how many files one query reads.
const blobsAtOnce = 25

// maxBlob is the largest text Nushi reads (the Changes view's limit).
const maxBlob = 1 << 20

// Blobs reads files' texts at commits, 25 to a query.
func (c *Client) Blobs(ctx context.Context, repo string, at []BlobAt) (map[BlobAt]Blob, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return nil, err
	}
	out := map[BlobAt]Blob{}
	for len(at) > 0 {
		batch := at[:min(len(at), blobsAtOnce)]
		at = at[len(batch):]
		var q strings.Builder
		q.WriteString("query Blobs($owner: String!, $name: String!) { repository(owner: $owner, name: $name) {")
		for i, b := range batch {
			expr, _ := json.Marshal(b.Commit + ":" + b.Path) // a JSON string is a GraphQL string
			fmt.Fprintf(&q, " b%d: object(expression: %s) { ... on Blob { text isBinary isTruncated byteSize } }", i, expr)
		}
		q.WriteString(" } }")
		var data struct {
			Repository map[string]*struct {
				Text        *string `json:"text"`
				IsBinary    bool    `json:"isBinary"`
				ByteSize    int     `json:"byteSize"`
				IsTruncated bool    `json:"isTruncated"`
			} `json:"repository"`
		}
		if _, err := c.graphql(ctx, q.String(), map[string]any{"owner": owner, "name": name}, &data); err != nil {
			return nil, err
		}
		for i, b := range batch {
			o := data.Repository[fmt.Sprintf("b%d", i)]
			switch {
			case o == nil:
				out[b] = Blob{}
			case o.IsBinary:
				out[b] = Blob{Found: true, Skipped: "binary"}
			case o.ByteSize > maxBlob || o.IsTruncated || o.Text == nil:
				out[b] = Blob{Found: true, Skipped: "too large"}
			default:
				out[b] = Blob{Found: true, Text: *o.Text}
			}
		}
	}
	return out, nil
}
