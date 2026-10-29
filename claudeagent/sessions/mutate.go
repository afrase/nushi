// Ported from the Claude Agent SDK for Python (commit 27858cbb,
// src/claude_agent_sdk/_internal/session_mutations.py), MIT License,
// Copyright (c) 2025 Anthropic, PBC: see ../NOTICE. Modified: Fork can
// write into another folder's history, and Delete clears every folder the
// session may be in and succeeds when it isn't there.

package sessions

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ForkOptions says what Fork keeps and where it writes.
type ForkOptions struct {
	// UpTo is the uuid of the last record to keep, itself included; ""
	// keeps the whole conversation.
	UpTo string
	// Title is the fork's title; "" is the session's own title (else its
	// first prompt) followed by " (fork)".
	Title string
	// Cwd is the working directory in whose project folder the fork is
	// written, since the CLI resumes a session only from its working
	// directory's folder; "" writes it beside the session's transcript.
	Cwd string
}

// Fork copies session id's conversation into a new session and returns
// its id. Every record gets a fresh uuid, its links follow, and each
// carries forkedFrom with the record it was copied from. Subagents'
// records and progress records stay behind, as do the session's file
// history snapshots, so the fork can't undo file changes made before it.
// The fork ends with a custom-title record.
func Fork(configDir, id, cwd string, o ForkOptions) (string, error) {
	if o.UpTo != "" {
		if err := checkID(o.UpTo); err != nil {
			return "", err
		}
	}
	path, err := find(configDir, id, cwd)
	if err != nil {
		return "", err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	records, replacements := parseFork(data, id)
	newID, lines, err := forkLines(records, replacements, id, o.UpTo)
	if err != nil {
		return "", err
	}
	title := strings.TrimSpace(o.Title)
	if title == "" {
		title = firstOf(titleOf(data), "Forked session") + " (fork)"
	}
	lines = append(lines, encode(
		"type", "custom-title", "sessionId", newID, "customTitle", title, "uuid", newUUID(), "timestamp", stamp()))

	dir := filepath.Dir(path)
	if o.Cwd != "" {
		projects, err := projectsDir(configDir)
		if err != nil {
			return "", err
		}
		var ok bool
		if dir, ok = findProjectDir(projects, canonical(o.Cwd)); !ok {
			dir = ProjectDir(configDir, o.Cwd)
		}
	}
	return newID, writeNew(filepath.Join(dir, newID+".jsonl"), []byte(strings.Join(lines, "\n")+"\n"))
}

// parseFork reads the records a fork copies, and the session's content
// replacements (tool results the CLI stored apart), which the fork keeps.
func parseFork(data []byte, id string) (records []*object, replacements []json.RawMessage) {
	for line := range strings.SplitSeq(string(data), "\n") {
		o, err := parseObject([]byte(strings.TrimSpace(line)))
		if err != nil {
			continue
		}
		typ := str(o.vals["type"])
		if _, ok := isString(o.vals["uuid"]); ok && chainTypes[typ] {
			records = append(records, o)
			continue
		}
		var list []json.RawMessage
		if typ == "content-replacement" && str(o.vals["sessionId"]) == id && unmarshalOK(o.vals["replacements"], &list) {
			replacements = append(replacements, list...)
		}
	}
	return records, replacements
}

// forkLines turns records into the fork's lines, up to the record upTo.
func forkLines(records []*object, replacements []json.RawMessage, id, upTo string) (string, []string, error) {
	kept, found := cut(records, upTo)
	if upTo != "" && !found {
		return "", nil, fmt.Errorf("message %s isn't in session %s", upTo, id)
	}
	// Progress records only link others: they get a uuid for the links
	// through them, but aren't written.
	fresh, byUUID := map[string]string{}, map[string]*object{}
	var writable []*object
	for _, r := range kept {
		u := str(r.vals["uuid"])
		fresh[u], byUUID[u] = newUUID(), r
		if str(r.vals["type"]) != "progress" {
			writable = append(writable, r)
		}
	}
	if len(writable) == 0 {
		return "", nil, fmt.Errorf("session %s has no messages to fork", id)
	}
	newID, now := newUUID(), stamp()
	var lines []string
	for i, r := range writable {
		old := str(r.vals["uuid"])
		// The nearest record above that isn't progress (progress records
		// are never rewritten, so their links are still the old ones).
		var parent any
		pid := str(r.vals["parentUuid"])
		for range kept { // as many steps as records: a cycle ends
			p := byUUID[pid]
			if p == nil {
				break
			}
			if str(p.vals["type"]) != "progress" {
				parent = fresh[pid]
				break
			}
			pid = str(p.vals["parentUuid"])
		}
		r.set("uuid", fresh[old])
		r.set("parentUuid", parent)
		// A compaction's link to what it replaced follows when that was
		// copied; otherwise it is null.
		if logical, ok := r.vals["logicalParentUuid"]; !ok || truthy(logical) {
			var to any
			if u, ok := fresh[str(logical)]; ok && truthy(logical) {
				to = u
			}
			r.set("logicalParentUuid", to)
		}
		r.set("sessionId", newID)
		// The last record's time is now, so a resume takes it as the leaf.
		if _, ok := r.vals["timestamp"]; !ok || i == len(writable)-1 {
			r.set("timestamp", now)
		}
		r.set("isSidechain", false)
		r.set("forkedFrom", ordered("sessionId", id, "messageUuid", old))
		for _, k := range []string{"teamName", "agentName", "slug", "sourceToolAssistantUUID"} {
			r.remove(k)
		}
		lines = append(lines, string(r.encode()))
	}
	if len(replacements) > 0 {
		lines = append(lines, encode(
			"type", "content-replacement", "sessionId", newID, "replacements", replacements, "uuid", newUUID(), "timestamp", now))
	}
	return newID, lines, nil
}

// cut returns the main conversation's records (not subagents') up to the
// one with uuid upTo, itself included, and whether it was there.
func cut(records []*object, upTo string) (kept []*object, found bool) {
	for _, r := range records {
		if truthy(r.vals["isSidechain"]) {
			continue
		}
		kept = append(kept, r)
		if upTo != "" && str(r.vals["uuid"]) == upTo {
			return kept, true
		}
	}
	return kept, false
}

// titleOf finds a transcript's title as List does, else its first prompt.
func titleOf(data []byte) string {
	head, tail := data[:min(len(data), liteRead)], data[max(0, len(data)-liteRead):]
	h, t := strings.ToValidUTF8(string(head), "�"), strings.ToValidUTF8(string(tail), "�")
	return firstOf(lastString(t, "customTitle"), lastString(h, "customTitle"),
		lastString(t, "aiTitle"), lastString(h, "aiTitle"), firstPrompt(h))
}

// stamp is the time now as the CLI writes it (JavaScript's toISOString).
func stamp() string { return time.Now().UTC().Format("2006-01-02T15:04:05.000Z") }

// writeNew writes a new file at path, never replacing one.
func writeNew(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return err
	}
	_, err = f.Write(data)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		_ = os.Remove(path) // a part of a fork is no fork
	}
	return err
}

// Delete removes session id's transcript and its folder (its subagents'
// transcripts and the like) for good, from every project folder Get would
// look in. A session that isn't there is no error. A running CLI writes to
// a transcript as it ends, so stop the session's process first.
func Delete(configDir, id, cwd string) error {
	if err := checkID(id); err != nil {
		return err
	}
	projects, err := projectsDir(configDir)
	if err != nil {
		return err
	}
	// Every folder, not just the first with the transcript: the CLI leaves
	// empty transcripts in some, and one ahead of the real one must not
	// keep it.
	for _, dir := range candidates(projects, cwd) {
		path := filepath.Join(dir, id)
		if err := os.Remove(path + ".jsonl"); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
		if err := os.RemoveAll(path); err != nil {
			return err
		}
	}
	return nil
}
