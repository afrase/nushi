// Ported from the Claude Agent SDK for Python (commit 27858cbb,
// src/claude_agent_sdk/_internal/session_mutations.py), MIT License,
// Copyright (c) 2025 Anthropic, PBC: see ../NOTICE. Modified: restructured
// as Go, the functions a Store's methods, records read into typed structs
// and new ones written from them; Fork can write into another folder's
// history, and Delete clears every folder the session may be in and
// succeeds when it isn't there.

package sessions

import (
	"bytes"
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
func (s Store) Fork(id, cwd string, o ForkOptions) (string, error) {
	if o.UpTo != "" {
		if err := checkID(o.UpTo); err != nil {
			return "", err
		}
	}
	path, err := s.find(id, cwd)
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
	lines = append(lines, string(marshal(titleRecord{
		Type: "custom-title", SessionID: newID, CustomTitle: title, UUID: newUUID(), Timestamp: stamp(),
	})))

	dir := filepath.Dir(path)
	if o.Cwd != "" {
		projects, err := s.projects()
		if err != nil {
			return "", err
		}
		var ok bool
		if dir, ok = findProjectDir(projects, canonical(o.Cwd)); !ok {
			dir = s.ProjectDir(o.Cwd)
		}
	}
	return newID, writeNew(filepath.Join(dir, newID+".jsonl"), []byte(strings.Join(lines, "\n")+"\n"))
}

// copied is a record a fork copies: its fields as read, and the record
// itself, which Fork rewrites keeping every key, in its place, as the CLI
// wrote it.
type copied struct {
	recordFields
	obj *object
}

// forkedFrom is where a fork's record was copied from.
type forkedFrom struct {
	SessionID   string `json:"sessionId"`
	MessageUUID string `json:"messageUuid"`
}

// replacementRecord carries the session's content replacements into the
// fork.
type replacementRecord struct {
	Type         string            `json:"type"` // "content-replacement"
	SessionID    string            `json:"sessionId"`
	Replacements []json.RawMessage `json:"replacements"`
	UUID         string            `json:"uuid"`
	Timestamp    string            `json:"timestamp"`
}

// titleRecord names a session.
type titleRecord struct {
	Type        string `json:"type"` // "custom-title"
	SessionID   string `json:"sessionId"`
	CustomTitle string `json:"customTitle"`
	UUID        string `json:"uuid"`
	Timestamp   string `json:"timestamp"`
}

// parseFork reads the records a fork copies, and the session's content
// replacements (tool results the CLI stored apart), which the fork keeps.
func parseFork(data []byte, id string) (records []copied, replacements []json.RawMessage) {
	for line := range bytes.SplitSeq(data, []byte("\n")) {
		line = bytes.TrimSpace(line)
		r, ok := decodeRecord(line)
		switch {
		case !ok:
		case r.inChain():
			if o, err := parseObject(line); err == nil {
				records = append(records, copied{r, o})
			}
		case r.Type == "content-replacement" && string(r.SessionID) == id:
			var list []json.RawMessage
			if json.Unmarshal(r.Replacements, &list) == nil {
				replacements = append(replacements, list...)
			}
		}
	}
	return records, replacements
}

// forkLines turns records into the fork's lines, up to the record upTo.
func forkLines(records []copied, replacements []json.RawMessage, id, upTo string) (string, []string, error) {
	kept, found := cut(records, upTo)
	if upTo != "" && !found {
		return "", nil, fmt.Errorf("message %s isn't in session %s", upTo, id)
	}
	// Progress records only link others: they get a uuid for the links
	// through them, but aren't written.
	fresh, byUUID := map[string]string{}, map[string]copied{}
	var writable []copied
	for _, r := range kept {
		fresh[r.UUID.val], byUUID[r.UUID.val] = newUUID(), r
		if r.Type != "progress" {
			writable = append(writable, r)
		}
	}
	if len(writable) == 0 {
		return "", nil, fmt.Errorf("session %s has no messages to fork", id)
	}
	newID, now := newUUID(), stamp()
	var lines []string
	for i, r := range writable {
		old, o := r.UUID.val, r.obj
		// The nearest record above that isn't progress.
		var parent *string
		pid := string(r.Parent)
		for range kept { // as many steps as records: a cycle ends
			p, ok := byUUID[pid]
			if !ok {
				break
			}
			if p.Type != "progress" {
				u := fresh[pid]
				parent = &u
				break
			}
			pid = string(p.Parent)
		}
		o.set("uuid", fresh[old])
		o.set("parentUuid", parent)
		// A compaction's link to what it replaced follows when that was
		// copied; otherwise it is null.
		if l := r.Logical; !l.present || l.set {
			var to *string
			if u, ok := fresh[string(l.uuid)]; ok && l.set {
				to = &u
			}
			o.set("logicalParentUuid", to)
		}
		o.set("sessionId", newID)
		// The last record's time is now, so a resume takes it as the leaf.
		if !o.has("timestamp") || i == len(writable)-1 {
			o.set("timestamp", now)
		}
		o.set("isSidechain", false)
		o.set("forkedFrom", forkedFrom{SessionID: id, MessageUUID: old})
		for _, k := range []string{"teamName", "agentName", "slug", "sourceToolAssistantUUID"} {
			o.remove(k)
		}
		lines = append(lines, string(o.encode()))
	}
	if len(replacements) > 0 {
		lines = append(lines, string(marshal(replacementRecord{
			Type: "content-replacement", SessionID: newID, Replacements: replacements, UUID: newUUID(), Timestamp: now,
		})))
	}
	return newID, lines, nil
}

// cut returns the main conversation's records (not subagents') up to the
// one with uuid upTo, itself included, and whether it was there.
func cut(records []copied, upTo string) (kept []copied, found bool) {
	for _, r := range records {
		if r.Sidechain {
			continue
		}
		kept = append(kept, r)
		if upTo != "" && r.UUID.val == upTo {
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
func (s Store) Delete(id, cwd string) error {
	if err := checkID(id); err != nil {
		return err
	}
	projects, err := s.projects()
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
