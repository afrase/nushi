package githubapi

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"
)

// RerunFailed re-runs the failed jobs of the workflow runs that jobs (an
// Actions job's id is its check run's) belong to, each run once, and the
// jobs that depend on them (GitHub's "Re-run failed jobs"). It returns the
// runs asked to re-run.
func (c *Client) RerunFailed(ctx context.Context, repo string, jobs []int64) ([]int64, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return nil, err
	}
	var runs []int64
	seen := map[int64]bool{}
	for _, job := range jobs {
		if job <= 0 {
			continue
		}
		var j struct {
			RunID int64 `json:"run_id"`
		}
		if _, err := c.get(ctx, "/repos/{}/{}/actions/jobs/{}", []string{owner, name, strconv.FormatInt(job, 10)}, nil, &j); err != nil {
			return runs, err
		}
		if j.RunID <= 0 || seen[j.RunID] {
			continue
		}
		seen[j.RunID] = true
		path := "/repos/{}/{}/actions/runs/{}/rerun-failed-jobs"
		if _, err := c.send(ctx, http.MethodPost, path, c.rest+fill(path, []string{owner, name, strconv.FormatInt(j.RunID, 10)}),
			"core", []byte("{}"), true); err != nil {
			var api *APIError
			if errors.As(err, &api) && api.Status == http.StatusForbidden && strings.Contains(strings.ToLower(api.Message), "not") {
				return runs, errors.New("GitHub won't re-run it with this token (it needs the actions write permission): " + api.Message)
			}
			return runs, err
		}
		runs = append(runs, j.RunID)
	}
	if len(runs) == 0 && len(seen) == 0 {
		return nil, errors.New("none of these is an Actions job: re-run them on their own pages")
	}
	return runs, nil
}
