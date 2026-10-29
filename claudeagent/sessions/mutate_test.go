// Partly ported from the Claude Agent SDK for Python's tests (commit
// 27858cbb, tests/test_session_mutations.py), MIT License, Copyright (c)
// 2025 Anthropic, PBC: see ../NOTICE.

package sessions

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// forkSource writes a session to fork: a prompt, a progress record, an
// answer through it, a subagent's record, a compaction, and a second turn.
func forkSource(t *testing.T, dir, id string) {
	t.Helper()
	lines := strings.Split(strings.TrimSpace(string(jsonl(t,
		rec("user", "u1", "", "message", record{"content": "first question"}, "timestamp", "2026-01-01T00:00:00.000Z",
			"teamName", "t", "agentName", "n", "slug", "s", "cwd", "/w", "isSidechain", false),
		rec("progress", "p1", "u1"),
		rec("assistant", "a1", "p1", "message", record{"id": "msg_1", "content": "answer"}, "timestamp", "2026-01-01T00:00:01.000Z"),
		rec("assistant", "side", "a1", "isSidechain", true, "agentId", "x"),
		rec("system", "boundary", "", "subtype", "compact_boundary", "logicalParentUuid", "a1", "timestamp", "2026-01-01T00:00:02.000Z"),
		rec("user", "u2", "boundary", "message", record{"content": "second"}, "sourceToolAssistantUUID", "a1", "timestamp", "2026-01-01T00:00:03.000Z"),
		rec("assistant", "a2", "u2", "message", record{"id": "msg_2", "content": "again"}, "logicalParentUuid", "gone", "timestamp", "2026-01-01T00:00:04.000Z"),
	))), "\n")
	lines = append(lines,
		`{"type":"content-replacement","sessionId":"`+id+`","replacements":[{"kind":"tool-result","id":"r1"}]}`,
		`{"type":"content-replacement","sessionId":"another","replacements":[{"id":"r2"}]}`)
	writeLines(t, dir, id, lines...)
}

func testNoErr(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

// readRecords reads a transcript's records as maps, in order.
func readRecords(t *testing.T, path string) []map[string]any {
	t.Helper()
	data, err := os.ReadFile(path)
	testNoErr(t, err)
	var out []map[string]any
	for line := range strings.SplitSeq(strings.TrimSpace(string(data)), "\n") {
		var r map[string]any
		testNoErr(t, json.Unmarshal([]byte(line), &r))
		out = append(out, r)
	}
	return out
}

func TestFork(t *testing.T) {
	config, cwd, dir := project(t)
	id := newUUID()
	forkSource(t, dir, id)
	before := time.Now().UTC().Add(-time.Second)

	newID, err := Fork(config, id, cwd, ForkOptions{})
	if err != nil {
		t.Fatal(err)
	}
	if checkID(newID) != nil || newID == id {
		t.Fatalf("Fork = %q", newID)
	}
	path := filepath.Join(dir, newID+".jsonl")
	if fi, err := os.Stat(path); err != nil || fi.Mode().Perm() != 0o600 {
		t.Fatalf("the fork's file: %v, %v", fi, err)
	}
	data, err := os.ReadFile(path)
	testNoErr(t, err)
	// The source's keys in their order (json.Marshal's, alphabetical), its
	// agentName gone, the new ones last.
	first, _, _ := strings.Cut(string(data), "\n")
	if !strings.HasPrefix(first, `{"cwd":"/w","isSidechain":false,"message":{"content":"first question"},"parentUuid":null,"sessionId":"`) ||
		!strings.HasSuffix(first, `,"logicalParentUuid":null,"forkedFrom":{"sessionId":"`+id+`","messageUuid":"u1"}}`) {
		t.Errorf("the fork's first record isn't in the source's order: %s", first)
	}
	recs := readRecords(t, path)
	// u1, a1, boundary, u2, a2, then the replacements and the title.
	if len(recs) != 7 {
		t.Fatalf("the fork has %d records: %v", len(recs), recs)
	}
	from := []string{"u1", "a1", "boundary", "u2", "a2"}
	fresh := map[string]string{}
	for i, r := range recs[:5] {
		ff, _ := r["forkedFrom"].(map[string]any)
		if ff["sessionId"] != id || ff["messageUuid"] != from[i] || r["sessionId"] != newID || r["isSidechain"] == nil || r["isSidechain"].(bool) {
			t.Errorf("record %d = %v", i, r)
		}
		u, _ := r["uuid"].(string)
		if checkID(u) != nil {
			t.Errorf("record %d's uuid is %q", i, u)
		}
		fresh[from[i]] = u
		for _, k := range []string{"teamName", "agentName", "slug", "sourceToolAssistantUUID"} {
			if _, ok := r[k]; ok {
				t.Errorf("record %d kept %s", i, k)
			}
		}
	}
	links := []struct {
		at      int
		key     string
		want    any
		comment string
	}{
		{0, "parentUuid", nil, "the root"},
		{1, "parentUuid", fresh["u1"], "through the progress record"},
		{2, "parentUuid", nil, "a compaction starts again"},
		{2, "logicalParentUuid", fresh["a1"], "a compaction's link follows"},
		{3, "parentUuid", fresh["boundary"], ""},
		{4, "logicalParentUuid", nil, "a link to nothing copied"},
		{0, "logicalParentUuid", nil, "set where absent"},
		{0, "cwd", "/w", "other fields kept"},
		{0, "timestamp", "2026-01-01T00:00:00.000Z", "times kept"},
	}
	for _, l := range links {
		if got := recs[l.at][l.key]; got != l.want {
			t.Errorf("record %d's %s = %v, want %v (%s)", l.at, l.key, got, l.want, l.comment)
		}
	}
	if last, err := time.Parse(time.RFC3339, recs[4]["timestamp"].(string)); err != nil || last.Before(before) {
		t.Errorf("the last record's time is %v, %v; want now", recs[4]["timestamp"], err)
	}
	if r := recs[5]; r["type"] != "content-replacement" || r["sessionId"] != newID || len(r["replacements"].([]any)) != 1 {
		t.Errorf("replacements = %v", r)
	}
	if r := recs[6]; r["type"] != "custom-title" || r["customTitle"] != "first question (fork)" || r["sessionId"] != newID {
		t.Errorf("title = %v", r)
	}

	msgs, err := Messages(config, newID, cwd)
	if err != nil || len(msgs) != 2 || msgs[1].UUID != fresh["a2"] {
		t.Errorf("the fork's messages = %s, %v", messageUUIDs(msgs), err)
	}
	if info, err := Get(config, newID, ""); err != nil || info.CustomTitle != "first question (fork)" {
		t.Errorf("Get(fork) = %+v, %v", info, err)
	}
}

func TestForkUpTo(t *testing.T) {
	config, cwd, dir := project(t)
	// UpTo takes a UUID, so the records are named by them.
	ids := map[string]string{}
	for _, name := range []string{"u1", "p1", "a1", "side"} {
		ids[name] = newUUID()
	}
	other := newUUID()
	transcript(t, dir, other,
		text("user", ids["u1"], "", "q"),
		rec("progress", ids["p1"], ids["u1"]),
		text("assistant", ids["a1"], ids["p1"], "a"),
		rec("assistant", ids["side"], ids["a1"], "isSidechain", true),
		text("user", newUUID(), ids["a1"], "more"),
	)
	for _, c := range []struct {
		upTo string
		want int // records before the title
		err  bool
	}{
		{ids["u1"], 1, false},
		{ids["p1"], 1, false}, // the progress record isn't written, what it follows is
		{ids["a1"], 2, false},
		{ids["side"], 0, true},
		{newUUID(), 0, true},
		{"not-a-uuid", 0, true},
	} {
		newID, err := Fork(config, other, cwd, ForkOptions{UpTo: c.upTo})
		if (err != nil) != c.err {
			t.Errorf("Fork up to %s: %v", c.upTo, err)
			continue
		}
		if err == nil {
			if recs := readRecords(t, filepath.Join(dir, newID+".jsonl")); len(recs) != c.want+1 {
				t.Errorf("Fork up to %s has %d records", c.upTo, len(recs))
			}
		}
	}
}

func TestForkTitleAndPlace(t *testing.T) {
	config, _, dir := project(t)
	titled, untitled, bare := newUUID(), newUUID(), newUUID()
	transcript(t, dir, titled, text("user", "u", "", "q"), record{"type": "custom-title", "customTitle": "Mine"}, record{"type": "ai-title", "aiTitle": "Generated"})
	transcript(t, dir, untitled, text("user", "u", "", "what now?"))
	transcript(t, dir, bare, rec("assistant", "a", ""))
	elsewhere := t.TempDir()
	for _, c := range []struct {
		id    string
		o     ForkOptions
		title string
		dir   string
	}{
		{titled, ForkOptions{}, "Mine (fork)", dir},
		{titled, ForkOptions{Title: "  Picked  "}, "Picked", dir},
		{untitled, ForkOptions{}, "what now? (fork)", dir},
		{bare, ForkOptions{}, "Forked session (fork)", dir},
		{untitled, ForkOptions{Cwd: elsewhere}, "what now? (fork)", ProjectDir(config, elsewhere)},
	} {
		newID, err := Fork(config, c.id, "", c.o)
		if err != nil {
			t.Errorf("Fork(%+v): %v", c.o, err)
			continue
		}
		recs := readRecords(t, filepath.Join(c.dir, newID+".jsonl"))
		if got := recs[len(recs)-1]["customTitle"]; got != c.title {
			t.Errorf("Fork(%+v)'s title = %v, want %q", c.o, got, c.title)
		}
	}
}

func TestForkMissing(t *testing.T) {
	config, cwd, dir := project(t)
	empty, sideOnly := newUUID(), newUUID()
	writeLines(t, dir, empty)
	transcript(t, dir, sideOnly, rec("user", "u", "", "isSidechain", true))
	for _, id := range []string{newUUID(), empty} {
		if _, err := Fork(config, id, cwd, ForkOptions{}); !errors.Is(err, fs.ErrNotExist) {
			t.Errorf("Fork(%s) = %v", id, err)
		}
	}
	if _, err := Fork(config, sideOnly, cwd, ForkOptions{}); err == nil {
		t.Error("Fork of only a subagent's records made a fork")
	}
}

func TestDelete(t *testing.T) {
	config, cwd, dir := project(t)
	id, keep, empty := newUUID(), newUUID(), newUUID()
	transcript(t, dir, id, text("user", "u", "", "q"))
	transcript(t, dir, keep, text("user", "u", "", "q"))
	writeLines(t, dir, empty)
	transcript(t, filepath.Join(dir, id, "subagents"), "agent-a", text("user", "u", "", "q"))

	for range 2 { // the second time there is nothing to delete
		if err := Delete(config, id, cwd); err != nil {
			t.Fatal(err)
		}
	}
	for _, gone := range []string{id + ".jsonl", id} {
		if _, err := os.Lstat(filepath.Join(dir, gone)); !errors.Is(err, fs.ErrNotExist) {
			t.Errorf("%s is still there: %v", gone, err)
		}
	}
	if _, err := os.Stat(filepath.Join(dir, keep+".jsonl")); err != nil {
		t.Errorf("another session went: %v", err)
	}
	if err := Delete(config, empty, ""); err != nil {
		t.Error(err)
	}
	if _, err := os.Stat(filepath.Join(dir, empty+".jsonl")); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("an empty transcript stayed: %v", err)
	}
	if err := Delete(config, "../"+keep, cwd); err == nil {
		t.Error("Delete took a path")
	}
	if err := Delete(filepath.Join(config, "none"), newUUID(), ""); err != nil {
		t.Errorf("Delete with no projects folder = %v", err)
	}
}
