// Ported from the Claude Agent SDK for Python (commit 27858cbb,
// src/claude_agent_sdk/_internal/sessions.py), MIT License,
// Copyright (c) 2025 Anthropic, PBC: see ../NOTICE.

package sessions

import (
	"maps"
	"slices"
	"strings"
)

// recoverParallel puts back the tool calls and results of parallel tool
// calls that the parentUuid walk left out.
//
// The CLI writes a response as one assistant record per content block, all
// with the response's message id, each the parent of the next. Each tool
// result's parent is its own call's record, so the results branch off
// different records and the walk follows only the branch the next turn went
// on from: one result, and none of the calls written after the one it
// answers. For each response on the chain, this collects its records and
// their results the walk didn't reach and puts them right after the
// response's last record on the chain, so the response stays whole and
// every result follows its call.
//
// order is byUUID's uuids as first written; seen holds the chain's uuids
// and gains the recovered ones.
func recoverParallel(byUUID map[string]*entry, order []string, chain []*entry, seen map[string]bool) []*entry {
	// Each response's last record on the chain: where its lost ones go.
	anchor := map[string]*entry{}
	var responses []string
	for _, e := range chain {
		if e.msgID != "" {
			if _, ok := anchor[e.msgID]; !ok {
				responses = append(responses, e.msgID)
			}
			anchor[e.msgID] = e
		}
	}
	if len(responses) == 0 {
		return chain
	}
	r := &recovery{byUUID: byUUID, order: order, chain: chain, seen: seen}
	r.index()
	inserts := map[string][]*entry{}
	for _, id := range responses {
		if lost := r.lost(id); len(lost) > 0 {
			for _, e := range lost {
				seen[e.uuid] = true
			}
			inserts[anchor[id].uuid] = lost
		}
	}
	if len(inserts) == 0 {
		return chain
	}
	var out []*entry
	for _, e := range chain {
		out = append(out, e)
		out = append(out, inserts[e.uuid]...)
	}
	return out
}

// recovery is what recoverParallel works from.
type recovery struct {
	byUUID map[string]*entry
	order  []string
	chain  []*entry
	seen   map[string]bool

	siblings map[string][]*entry // each response's records
	owner    map[string]*entry   // the record that made each call; nil when two responses claim it
	byRecord map[string][]*entry // results under each record they may belong to

	answered map[string]bool // calls answered on the chain, once a stray needs it
	position map[string]int  // each uuid's place in order, the same
}

// index groups the records by response, finds each call's maker, and files
// each result under its parent, the call record it names and each call's
// maker; the last two only when the same agent wrote both.
func (r *recovery) index() {
	r.siblings, r.owner, r.byRecord = map[string][]*entry{}, map[string]*entry{}, map[string][]*entry{}
	var results []*entry
	for _, u := range r.order {
		e := r.byUUID[u]
		switch {
		case e.msgID != "":
			r.siblings[e.msgID] = append(r.siblings[e.msgID], e)
			for _, call := range e.calls {
				if prev, ok := r.owner[call]; ok && (prev == nil || prev.msgID != e.msgID) {
					r.owner[call] = nil
				} else {
					r.owner[call] = e
				}
			}
		case e.typ == "user" && e.parent != "" && e.hasResult:
			results = append(results, e)
		}
	}
	for _, res := range results {
		r.byRecord[res.parent] = append(r.byRecord[res.parent], res)
		if s := r.byUUID[res.source]; res.source != "" && s != nil && sameWriter(res, s) {
			r.byRecord[res.source] = append(r.byRecord[res.source], res)
		}
		for _, call := range res.answers {
			if o := r.owner[call]; o != nil && sameWriter(res, o) {
				r.byRecord[o.uuid] = append(r.byRecord[o.uuid], res)
			}
		}
	}
}

// lost returns response id's records and results that aren't on the
// chain: the records, then the results, each in time order (on a tie,
// records keep file order and results their calls').
func (r *recovery) lost(id string) []*entry {
	group := r.siblings[id]
	members := map[string]bool{}
	var calls, results, strays []*entry
	for _, m := range group {
		members[m.uuid] = true
		if !r.seen[m.uuid] {
			calls = append(calls, m)
		}
	}
	collected := map[string]bool{}
	for _, m := range group {
		for _, res := range r.byRecord[m.uuid] {
			if r.seen[res.uuid] || collected[res.uuid] {
				continue
			}
			collected[res.uuid] = true
			if members[res.parent] {
				results = append(results, res)
			} else {
				strays = append(strays, res)
			}
		}
	}
	if len(strays) > 0 {
		results = r.placeStrays(members, results, strays)
	}
	byTime := func(a, b *entry) int { return strings.Compare(a.timestamp, b.timestamp) }
	slices.SortStableFunc(calls, byTime)
	slices.SortStableFunc(results, byTime)
	return append(calls, results...)
}

// placeStrays adds to results the strays (results filed under the response
// whose parent is outside it) that answer one of the response's calls that
// nothing answers yet, in file order.
func (r *recovery) placeStrays(members map[string]bool, results, strays []*entry) []*entry {
	if r.answered == nil {
		r.answered, r.position = map[string]bool{}, map[string]int{}
		for _, e := range r.chain {
			for _, call := range e.answers {
				r.answered[call] = true
			}
		}
		for i, u := range r.order {
			r.position[u] = i
		}
	}
	answered := maps.Clone(r.answered)
	for _, res := range results {
		for _, call := range res.answers {
			answered[call] = true
		}
	}
	slices.SortStableFunc(strays, func(a, b *entry) int { return r.position[a.uuid] - r.position[b.uuid] })
	for _, res := range strays {
		open := slices.ContainsFunc(res.answers, func(call string) bool {
			o := r.owner[call]
			return !answered[call] && o != nil && members[o.uuid]
		})
		if !open {
			continue
		}
		for _, call := range res.answers {
			answered[call] = true
		}
		results = append(results, res)
	}
	return results
}

// sameWriter says the same agent (or subagent) wrote both records.
func sameWriter(a, b *entry) bool {
	return a.sidechain == b.sidechain && a.agentID == b.agentID
}
