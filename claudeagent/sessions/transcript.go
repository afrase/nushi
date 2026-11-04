// Ported from the Claude Agent SDK for Python (commit 27858cbb,
// src/claude_agent_sdk/_internal/sessions.py), MIT License,
// Copyright (c) 2025 Anthropic, PBC: see ../NOTICE. Modified: restructured
// as Go, records read into typed structs.

package sessions

import (
	"bytes"
	"encoding/json"
	"slices"
)

// entry is one record of a transcript, with the fields that place it in
// the conversation, read leniently (see recordFields).
type entry struct {
	raw       json.RawMessage
	typ       string
	uuid      string
	parent    string // parentUuid
	sessionID string
	sidechain bool   // written by a subagent
	meta      bool   // isMeta: the CLI's, not the user's
	team      bool   // has a teamName
	agentID   string // agentId's JSON, "" when absent
	timestamp string
	source    string          // sourceToolAssistantUUID: the call a result answers
	message   json.RawMessage // the API message
	msgID     string          // an assistant record's API message id
	calls     []string        // its tool_use blocks' ids
	answers   []string        // its tool_result blocks' tool_use_ids
	hasResult bool            // it has a tool_result block
}

// chainTypes are the records that have a uuid and a place in the chain.
var chainTypes = map[string]bool{"user": true, "assistant": true, "progress": true, "system": true, "attachment": true}

// parseEntries reads a transcript's records of chainTypes that have a
// uuid, skipping lines that aren't JSON objects.
func parseEntries(data []byte) []*entry {
	var out []*entry
	for line := range bytes.SplitSeq(data, []byte("\n")) {
		line = bytes.TrimSpace(line)
		if len(line) == 0 {
			continue
		}
		r, ok := decodeRecord(line)
		if !ok || !r.inChain() {
			continue
		}
		e := &entry{
			raw: line, typ: string(r.Type), uuid: r.UUID.val, parent: string(r.Parent), sessionID: string(r.SessionID),
			sidechain: bool(r.Sidechain), meta: bool(r.Meta), team: bool(r.Team),
			timestamp: string(r.Timestamp), source: string(r.Source), message: r.Message,
		}
		if id := bytes.TrimSpace(r.AgentID); string(id) != "null" {
			e.agentID = string(id)
		}
		e.readMessage()
		out = append(out, e)
	}
	return out
}

// readMessage reads the message's id and its tool calls and results.
func (e *entry) readMessage() {
	var msg apiMessage
	if json.Unmarshal(e.message, &msg) != nil {
		return
	}
	if e.typ == "assistant" {
		e.msgID = string(msg.ID)
	}
	for _, b := range msg.Content {
		switch b.Type {
		case "tool_use":
			if b.ID.ok {
				e.calls = append(e.calls, b.ID.val)
			}
		case "tool_result":
			e.hasResult = true
			if b.ToolUseID.ok {
				e.answers = append(e.answers, b.ToolUseID.val)
			}
		}
	}
}

// chain returns the conversation as it stands: from the latest message of
// the main conversation back to the first by parentUuid, oldest first, with
// the tool calls and results of parallel calls that the walk misses put
// back. logicalParentUuid (a compaction's link to what it replaced) isn't
// followed: the compaction's summary stands for what came before.
func chain(entries []*entry) []*entry {
	l := linksOf(entries)
	index, parents := map[string]int{}, map[string]bool{}
	for i, e := range entries {
		index[e.uuid] = i
		if e.parent != "" {
			parents[e.parent] = true
		}
	}
	// From each record nothing follows, back to its nearest message.
	var leaves, main []*entry
	for _, e := range entries {
		if parents[e.uuid] {
			continue
		}
		seen := map[string]bool{}
		for cur := e; cur != nil && !seen[cur.uuid]; cur = l.up(cur) {
			seen[cur.uuid] = true
			if cur.typ == "user" || cur.typ == "assistant" {
				leaves = append(leaves, cur)
				if !cur.sidechain && !cur.team && !cur.meta {
					main = append(main, cur)
				}
				break
			}
		}
	}
	if len(main) > 0 {
		leaves = main
	}
	if len(leaves) == 0 {
		return nil
	}
	leaf := leaves[0] // the one written last
	for _, e := range leaves[1:] {
		if index[e.uuid] > index[leaf.uuid] {
			leaf = e
		}
	}
	return l.walkBack(leaf)
}

// linear is a subagent's chain: nothing rewinds its transcript, so the walk
// starts at its last message. Its parallel calls branch it all the same.
func linear(entries []*entry) []*entry {
	var leaf *entry
	for _, e := range entries {
		if e.typ == "user" || e.typ == "assistant" {
			leaf = e
		}
	}
	return linksOf(entries).walkBack(leaf)
}

// links are a transcript's records by uuid (the last of each), and their
// uuids as first written.
type links struct {
	byUUID map[string]*entry
	order  []string
}

func linksOf(entries []*entry) links {
	l := links{byUUID: map[string]*entry{}}
	for _, e := range entries {
		if _, ok := l.byUUID[e.uuid]; !ok {
			l.order = append(l.order, e.uuid)
		}
		l.byUUID[e.uuid] = e
	}
	return l
}

// up is the record e follows by parentUuid; nil at the first.
func (l links) up(e *entry) *entry {
	if e.parent == "" {
		return nil
	}
	return l.byUUID[e.parent]
}

// walkBack is the chain from leaf back to the first record, oldest first,
// a loop cut where it comes round, with the parallel calls the walk misses
// put back.
func (l links) walkBack(leaf *entry) []*entry {
	var out []*entry
	seen := map[string]bool{}
	for cur := leaf; cur != nil && !seen[cur.uuid]; cur = l.up(cur) {
		seen[cur.uuid] = true
		out = append(out, cur)
	}
	slices.Reverse(out)
	return recoverParallel(l.byUUID, l.order, out, seen)
}
