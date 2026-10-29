// Ported from the Claude Agent SDK for Python (commit 27858cbb,
// src/claude_agent_sdk/_internal/sessions.py), MIT License,
// Copyright (c) 2025 Anthropic, PBC: see ../NOTICE.

package sessions

import (
	"bytes"
	"encoding/json"
	"slices"
	"strings"
)

// entry is one record of a transcript, with the fields that place it in
// the conversation. Every field is read leniently: one of the wrong type
// counts as absent, so a record the CLI writes otherwise one day doesn't
// lose the rest.
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
		var m map[string]json.RawMessage
		if json.Unmarshal(line, &m) != nil {
			continue
		}
		e := &entry{raw: line, typ: str(m["type"])}
		var ok bool
		if e.uuid, ok = isString(m["uuid"]); !ok || !chainTypes[e.typ] {
			continue
		}
		e.parent, e.sessionID = str(m["parentUuid"]), str(m["sessionId"])
		e.sidechain, e.meta, e.team = truthy(m["isSidechain"]), truthy(m["isMeta"]), truthy(m["teamName"])
		if id := bytes.TrimSpace(m["agentId"]); string(id) != "null" {
			e.agentID = string(id)
		}
		e.timestamp, e.source = str(m["timestamp"]), str(m["sourceToolAssistantUUID"])
		e.message = m["message"]
		e.readMessage()
		out = append(out, e)
	}
	return out
}

// readMessage reads the message's id and its tool calls and results.
func (e *entry) readMessage() {
	var msg struct {
		ID      json.RawMessage
		Content json.RawMessage
	}
	if json.Unmarshal(e.message, &msg) != nil {
		return
	}
	if e.typ == "assistant" {
		e.msgID = str(msg.ID)
	}
	var blocks []json.RawMessage
	if json.Unmarshal(msg.Content, &blocks) != nil {
		return
	}
	for _, raw := range blocks {
		var b struct {
			Type, ID  json.RawMessage
			ToolUseID json.RawMessage `json:"tool_use_id"`
		}
		if json.Unmarshal(raw, &b) != nil {
			continue
		}
		switch str(b.Type) {
		case "tool_use":
			if id, ok := isString(b.ID); ok {
				e.calls = append(e.calls, id)
			}
		case "tool_result":
			e.hasResult = true
			if id, ok := isString(b.ToolUseID); ok {
				e.answers = append(e.answers, id)
			}
		}
	}
}

// isString returns raw's value when it is a JSON string.
func isString(raw json.RawMessage) (string, bool) {
	var s string
	err := json.Unmarshal(raw, &s)
	return s, err == nil && len(raw) > 0 && raw[0] == '"'
}

// str is raw's value when it is a JSON string, else "".
func str(raw json.RawMessage) string {
	s, _ := isString(raw)
	return s
}

// truthy says raw is set to something, as Python's truth goes: not
// absent, null, false, 0, "", [] or {}.
func truthy(raw json.RawMessage) bool {
	switch strings.Join(strings.Fields(string(raw)), "") {
	case "", "null", "false", "0", `""`, "[]", "{}":
		return false
	}
	return true
}

// chain returns the conversation as it stands: from the latest message of
// the main conversation back to the first by parentUuid, oldest first, with
// the tool calls and results of parallel calls that the walk misses put
// back. logicalParentUuid (a compaction's link to what it replaced) isn't
// followed: the compaction's summary stands for what came before.
func chain(entries []*entry) []*entry {
	byUUID, order, index := map[string]*entry{}, []string{}, map[string]int{}
	parents := map[string]bool{}
	for i, e := range entries {
		if _, ok := byUUID[e.uuid]; !ok {
			order = append(order, e.uuid)
		}
		byUUID[e.uuid], index[e.uuid] = e, i
		if e.parent != "" {
			parents[e.parent] = true
		}
	}
	up := func(e *entry) *entry {
		if e.parent == "" {
			return nil
		}
		return byUUID[e.parent]
	}
	// From each record nothing follows, back to its nearest message.
	var leaves, main []*entry
	for _, e := range entries {
		if parents[e.uuid] {
			continue
		}
		seen := map[string]bool{}
		for cur := e; cur != nil && !seen[cur.uuid]; cur = up(cur) {
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
	for _, l := range leaves[1:] {
		if index[l.uuid] > index[leaf.uuid] {
			leaf = l
		}
	}
	var out []*entry
	seen := map[string]bool{}
	for cur := leaf; cur != nil && !seen[cur.uuid]; cur = up(cur) {
		seen[cur.uuid] = true
		out = append(out, cur)
	}
	slices.Reverse(out)
	return recoverParallel(byUUID, order, out, seen)
}

// linear is a subagent's chain: its transcript has no branches, so the
// walk starts at its last message.
func linear(entries []*entry) []*entry {
	byUUID := map[string]*entry{}
	var leaf *entry
	for _, e := range entries {
		byUUID[e.uuid] = e
		if e.typ == "user" || e.typ == "assistant" {
			leaf = e
		}
	}
	var out []*entry
	seen := map[string]bool{}
	for cur := leaf; cur != nil && !seen[cur.uuid]; {
		seen[cur.uuid] = true
		out = append(out, cur)
		if cur.parent == "" {
			break
		}
		cur = byUUID[cur.parent]
	}
	slices.Reverse(out)
	return out
}
