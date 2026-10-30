package sessions

import (
	"encoding/json"
	"strings"
)

// The types here read a transcript's fields leniently: a value of the wrong
// type reads as absent instead of failing the record, so a record the CLI
// one day writes otherwise doesn't lose the rest. Their UnmarshalJSON never
// fails, and sets the field again when a key comes twice (the last wins).

// str is a field that holds a string; any other value reads as "".
type str string

// UnmarshalJSON reads data when it is a JSON string.
func (s *str) UnmarshalJSON(data []byte) error {
	v, _ := stringOf(data)
	*s = str(v)
	return nil
}

// optStr is a field that holds a string, and says whether it did: a
// record's uuid, say, which counts even when it is "".
type optStr struct {
	val string
	ok  bool
}

// UnmarshalJSON reads data when it is a JSON string.
func (o *optStr) UnmarshalJSON(data []byte) error {
	o.val, o.ok = stringOf(data)
	return nil
}

// stringOf returns data's value when it is a JSON string.
func stringOf(data []byte) (string, bool) {
	var s string
	if len(data) == 0 || data[0] != '"' || json.Unmarshal(data, &s) != nil {
		return "", false
	}
	return s, true
}

// flag is a field that is set to something, as the Python SDK's truth goes:
// not null, false, 0, "", [] or {}.
type flag bool

// UnmarshalJSON says whether data is set to something.
func (f *flag) UnmarshalJSON(data []byte) error {
	switch strings.Join(strings.Fields(string(data)), "") {
	case "", "null", "false", "0", `""`, "[]", "{}":
		*f = false
	default:
		*f = true
	}
	return nil
}

// link is a field that links to a record by its uuid, which may be absent,
// unset (null, "" or another value that isn't set) or set.
type link struct {
	present bool
	set     bool // see flag
	uuid    str  // "" when it isn't a string
}

// UnmarshalJSON reads data as a link that is present.
func (l *link) UnmarshalJSON(data []byte) error {
	var set flag
	_ = set.UnmarshalJSON(data)    // never fails
	_ = l.uuid.UnmarshalJSON(data) // the same
	l.present, l.set = true, bool(set)
	return nil
}

// recordFields are the fields of a transcript record that place it in the
// conversation and that Fork rewrites.
type recordFields struct {
	Type      str    `json:"type"`
	UUID      optStr `json:"uuid"`
	Parent    str    `json:"parentUuid"`
	Logical   link   `json:"logicalParentUuid"` // a compaction's link to what it replaced
	SessionID str    `json:"sessionId"`
	Sidechain flag   `json:"isSidechain"` // written by a subagent
	Meta      flag   `json:"isMeta"`      // the CLI's, not the user's
	Team      flag   `json:"teamName"`
	// AgentID is agentId's JSON, of whatever type: two records' are only
	// compared.
	AgentID   json.RawMessage `json:"agentId"`
	Timestamp str             `json:"timestamp"`
	Source    str             `json:"sourceToolAssistantUUID"` // the call a result answers
	Message   json.RawMessage `json:"message"`                 // the API message
	// Replacements are a content-replacement record's tool results that
	// the CLI stored apart.
	Replacements json.RawMessage `json:"replacements"`
}

// decodeRecord reads a line of a transcript; false when it isn't a JSON
// object (or null).
func decodeRecord(line []byte) (r recordFields, ok bool) {
	return r, json.Unmarshal(line, &r) == nil
}

// inChain says the record has a uuid and is of chainTypes.
func (r *recordFields) inChain() bool { return r.UUID.ok && chainTypes[string(r.Type)] }

// apiMessage is what the chain needs of a record's message: its id and its
// tool calls and results.
type apiMessage struct {
	ID      str        `json:"id"`
	Content toolBlocks `json:"content"`
}

// toolBlocks is a message's content blocks; none when it isn't a list.
type toolBlocks []toolBlock

// UnmarshalJSON reads data's blocks when it is a list.
func (bs *toolBlocks) UnmarshalJSON(data []byte) error {
	var list []toolBlock
	if json.Unmarshal(data, &list) != nil {
		list = nil
	}
	*bs = list
	return nil
}

// toolBlock is a content block as far as tool calls go; one that isn't a
// JSON object reads as zero.
type toolBlock struct {
	Type      str    `json:"type"`
	ID        optStr `json:"id"`          // a tool_use's
	ToolUseID optStr `json:"tool_use_id"` // a tool_result's
}

// UnmarshalJSON reads data when it is a JSON object.
func (b *toolBlock) UnmarshalJSON(data []byte) error {
	type plain toolBlock
	var v plain
	if json.Unmarshal(data, &v) != nil {
		v = plain{}
	}
	*b = toolBlock(v)
	return nil
}
