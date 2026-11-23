package homebrew

import (
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"gopkg.in/yaml.v3"

	"github.com/afrase/nushi/internal/testcheck"
)

// The steps of release.yml that decide a release's state and its casks
// (ADR 0055) run once a release is published, never before: these run them
// with bash, as a runner does, against a fake gh that answers from the
// repository's releases as GitHub would, applying each call's --jq with jq.

// releaseStep is the run block of a step of release.yml, found by its id.
func releaseStep(t *testing.T, job, id string) string {
	t.Helper()
	data, err := os.ReadFile("../../.github/workflows/release.yml")
	testcheck.NoErr(t, err)
	var wf struct {
		Jobs map[string]struct {
			Steps []struct {
				ID  string `yaml:"id"`
				Run string `yaml:"run"`
			} `yaml:"steps"`
		} `yaml:"jobs"`
	}
	testcheck.NoErr(t, yaml.Unmarshal(data, &wf))
	for _, s := range wf.Jobs[job].Steps {
		if s.ID == id {
			return s.Run
		}
	}
	t.Fatalf("release.yml has no step %s in job %s", id, job)
	return ""
}

// fakeGH is the gh a step sees: the release the event names (the REST
// API's fields), the latest release's tag ("" when there is none) and the
// list of releases, newest first, drafts among them.
type fakeGH struct {
	release string
	latest  string
	list    []listed
}

// listed is a release as gh release list's --json gives it.
type listed struct {
	Tag   string `json:"tagName"`
	Pre   bool   `json:"isPrerelease"`
	Draft bool   `json:"isDraft"`
}

// ghScript answers gh's calls from the files beside it: the release by its
// id, the latest release, the list (drafts left out on --exclude-drafts),
// and records each PATCH.
const ghScript = `#!/bin/sh
dir=$(dirname "$0")
expr= prev= drafts=yes
for a in "$@"; do
  [ "$prev" = --jq ] && expr=$a
  [ "$a" = --exclude-drafts ] && drafts=no
  prev=$a
done
case "$1 $2" in
"api -X") echo "$*" >> "$dir/calls" ;;
"api repos/"*) jq -r "$expr" "$dir/release.json" ;;
"release view")
  [ -s "$dir/latest" ] || { echo "release not found" >&2; exit 1; }
  printf '{"tagName":"%s"}' "$(cat "$dir/latest")" | jq -r "$expr" ;;
"release list")
  if [ $drafts = no ]; then jq '[.[] | select(.isDraft | not)]' "$dir/list.json"; else cat "$dir/list.json"; fi | jq -r "$expr" ;;
*) echo "fake gh: $*" >&2; exit 1 ;;
esac
`

// stepRun is what a step left: its outputs, the PATCHes it sent and what it
// printed.
type stepRun struct {
	outputs map[string]string
	calls   []string
	printed string
}

// runStep runs a step's script with bash -e (a runner's default shell), with
// env as its environment's own values beside TAG and GITHUB_REPOSITORY.
func runStep(t *testing.T, script string, gh fakeGH, env map[string]string) stepRun {
	t.Helper()
	if _, err := exec.LookPath("jq"); err != nil {
		testcheck.Lacks(t, "jq, to stand in for gh's --jq")
	}
	dir := t.TempDir()
	bin := filepath.Join(dir, "bin")
	testcheck.NoErr(t, os.Mkdir(bin, 0o700))
	testcheck.NoErr(t, os.WriteFile(filepath.Join(bin, "gh"), []byte(ghScript), 0o700))
	testcheck.Write(t, filepath.Join(bin, "release.json"), gh.release)
	testcheck.Write(t, filepath.Join(bin, "latest"), gh.latest)
	list := gh.list
	if list == nil {
		list = []listed{}
	}
	testcheck.Write(t, filepath.Join(bin, "list.json"), testcheck.JSON(t, list))
	out := filepath.Join(dir, "output")
	testcheck.Write(t, out, "")
	cmd := exec.Command("bash", "-e", "-c", script)
	cmd.Env = []string{"PATH=" + bin + ":" + os.Getenv("PATH"), "GITHUB_REPOSITORY=afrase/nushi", "GITHUB_OUTPUT=" + out}
	for k, v := range env {
		cmd.Env = append(cmd.Env, k+"="+v)
	}
	printed, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("the step failed: %v\n%s", err, printed)
	}
	run := stepRun{outputs: map[string]string{}, printed: string(printed)}
	data, err := os.ReadFile(out)
	testcheck.NoErr(t, err)
	for line := range strings.Lines(string(data)) {
		k, v, _ := strings.Cut(strings.TrimSuffix(line, "\n"), "=")
		run.outputs[k] = v
	}
	if calls, err := os.ReadFile(filepath.Join(bin, "calls")); err == nil {
		run.calls = strings.Split(strings.TrimSpace(string(calls)), "\n")
	}
	return run
}

// release is the REST API's release: its state and its files' names.
func release(t *testing.T, tag string, draft, pre bool, files ...string) string {
	t.Helper()
	type asset struct {
		Name string `json:"name"`
	}
	assets := []asset{}
	for _, f := range files {
		assets = append(assets, asset{f})
	}
	return testcheck.JSON(t, struct {
		Tag    string  `json:"tag_name"`
		Draft  bool    `json:"draft"`
		Pre    bool    `json:"prerelease"`
		Assets []asset `json:"assets"`
	}{tag, draft, pre, assets})
}

const patchDraft = "api -X PATCH repos/afrase/nushi/releases/7 -F draft=true --silent"

// A release just published, without its files, is made a draft; one that is
// public with its files already (Re-run all jobs on a green run, or a second
// run queued behind the first after publishing by hand) is live: rebuilding
// it leaves it public, as a run by hand does, since the tap already names it.
func TestReleaseDraftLeavesALiveReleasePublic(t *testing.T) {
	script := releaseStep(t, "draft", "draft")
	env := map[string]string{"TAG": "v0.54.0", "ID": "7"}
	list := []listed{{Tag: "v0.54.0"}, {Tag: "v0.54.0-beta.2", Pre: true}}

	fresh := runStep(t, script, fakeGH{release: release(t, "v0.54.0", false, false), latest: "v0.54.0", list: list}, env)
	if !slices.Equal(fresh.calls, []string{patchDraft}) || fresh.outputs["live"] == "true" {
		t.Errorf("just published: %q, live %q; want it made a draft", fresh.calls, fresh.outputs["live"])
	}

	live := runStep(t, script, fakeGH{release: release(t, "v0.54.0", false, false, "Nushi-0.54.0.zip", "Nushi-0.54.0.zip.sha256"), latest: "v0.54.0", list: list}, env)
	if len(live.calls) != 0 || live.outputs["live"] != "true" {
		t.Errorf("public with its files: %q, live %q; want it left public", live.calls, live.outputs["live"])
	}
	if live.outputs["latest"] != "v0.54.0" || live.outputs["beta"] != "v0.54.0-beta.2" {
		t.Errorf("public with its files: %v", live.outputs)
	}
}

// withdraw keeps a failed run's release a draft, unless draft found it live:
// a failed rebuild of a public release with its files leaves it public.
func TestReleaseWithdrawLeavesALiveReleasePublic(t *testing.T) {
	script := releaseStep(t, "withdraw", "withdraw")
	gh := fakeGH{release: release(t, "v0.54.0", false, false, "Nushi-0.54.0.zip")}
	if run := runStep(t, script, gh, map[string]string{"TAG": "v0.54.0", "ID": "7", "LIVE": ""}); !slices.Equal(run.calls, []string{patchDraft}) {
		t.Errorf("a failed run: %q, want it made a draft", run.calls)
	}
	if run := runStep(t, script, gh, map[string]string{"TAG": "v0.54.0", "ID": "7", "LIVE": "true"}); len(run.calls) != 0 {
		t.Errorf("a failed rebuild of a live release: %q, want it left public", run.calls)
	}
}

// A release that is a draft already when draft runs (Re-run all jobs, or
// re-running a draft job that failed) is in neither GitHub's latest nor
// its list without drafts, so draft places it as publishing it will: the
// latest if it is a release newer than the latest, the newest beta if it
// is a pre-release newer than the newest beta.
func TestReleaseDraftPlacesADraftAsPublishingWill(t *testing.T) {
	script := releaseStep(t, "draft", "draft")
	for _, tc := range []struct {
		name, tag  string
		pre        bool
		latest     string
		list       []listed
		wantLatest string
		wantBeta   string
	}{
		{"a newer release", "v0.54.0", false, "v0.53.2",
			[]listed{{Tag: "v0.54.0", Draft: true}, {Tag: "v0.54.0-beta.2", Pre: true}, {Tag: "v0.53.2"}},
			"v0.54.0", "v0.54.0-beta.2"},
		{"an older release", "v0.53.3", false, "v0.54.0",
			[]listed{{Tag: "v0.53.3", Draft: true}, {Tag: "v0.54.0"}, {Tag: "v0.54.0-beta.2", Pre: true}},
			"v0.54.0", "v0.54.0-beta.2"},
		{"a newer beta", "v0.55.0-beta.10", true, "v0.54.0",
			[]listed{{Tag: "v0.55.0-beta.10", Pre: true, Draft: true}, {Tag: "v0.55.0-beta.9", Pre: true}, {Tag: "v0.54.0"}},
			"v0.54.0", "v0.55.0-beta.10"},
		{"the first beta", "v0.55.0-beta.1", true, "v0.54.0",
			[]listed{{Tag: "v0.55.0-beta.1", Pre: true, Draft: true}, {Tag: "v0.54.0"}},
			"v0.54.0", "v0.55.0-beta.1"},
		{"an older beta", "v0.54.0-beta.3", true, "v0.54.0",
			[]listed{{Tag: "v0.54.0-beta.3", Pre: true, Draft: true}, {Tag: "v0.55.0-beta.1", Pre: true}, {Tag: "v0.54.0"}},
			"v0.54.0", "v0.55.0-beta.1"},
	} {
		gh := fakeGH{release: release(t, tc.tag, true, tc.pre, "Nushi-"+tc.tag[1:]+".zip"), latest: tc.latest, list: tc.list}
		run := runStep(t, script, gh, map[string]string{"TAG": tc.tag, "ID": "7"})
		if run.outputs["latest"] != tc.wantLatest || run.outputs["beta"] != tc.wantBeta {
			t.Errorf("%s: latest %q, beta %q; want %q, %q", tc.name, run.outputs["latest"], run.outputs["beta"], tc.wantLatest, tc.wantBeta)
		}
		if run.outputs["live"] == "true" {
			t.Errorf("%s: a draft found live", tc.name)
		}
	}
}
