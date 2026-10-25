// Package adf converts the Atlassian Document Format (ADF), the JSON tree
// Jira Cloud keeps rich text in, to Markdown and back. It covers what
// Jira's editor makes (headings, lists, code, quotes, panels, tables, task
// and decision lists, expands, mentions, emoji, status, dates, cards,
// media); a node it doesn't know becomes its text, or its type in
// brackets, never nothing.
//
// The tree walk to Markdown follows ankitpokhrel/jira-cli's pkg/adf (MIT),
// and Markdown to ADF ajbeck/goldmark-adf (MIT): their shapes, rewritten.
package adf

import (
	"encoding/json"
	"strconv"
)

// Node is an ADF node: a doc, a block, an inline node or a text.
type Node struct {
	Type    string         `json:"type"`
	Version int            `json:"version,omitempty"` // the doc's, 1
	Attrs   map[string]any `json:"attrs,omitempty"`
	Content []Node         `json:"content,omitempty"`
	Text    string         `json:"text,omitempty"`
	Marks   []Mark         `json:"marks,omitempty"`
}

// Mark is a text's formatting: strong, em, code, strike, link, underline and more.
type Mark struct {
	Type  string         `json:"type"`
	Attrs map[string]any `json:"attrs,omitempty"`
}

// Parse reads an ADF document. Jira sends null for an empty field.
func Parse(b []byte) (Node, error) {
	var n Node
	if len(b) == 0 || string(b) == "null" {
		return n, nil
	}
	err := json.Unmarshal(b, &n)
	return n, err
}

// Doc makes a document of blocks.
func Doc(blocks ...Node) Node {
	return Node{Type: "doc", Version: 1, Content: blocks}
}

// attr is a node's attribute as text.
func (n Node) attr(name string) string {
	switch v := n.Attrs[name].(type) {
	case string:
		return v
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64)
	case int:
		return strconv.Itoa(v)
	}
	return ""
}

func (m Mark) attr(name string) string {
	s, _ := m.Attrs[name].(string)
	return s
}
