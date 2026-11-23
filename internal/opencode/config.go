package opencode

import (
	"bytes"
	"encoding/json"
	"slices"

	"github.com/tailscale/hujson"
)

// ParseConfig is the text of an opencode config file (opencode.json or
// .jsonc) as plain JSON reads it, by the one rule the skills page and the
// trust card share, so the two never disagree on what a file says: an
// empty file is an empty object, and a comment on the last line needs no
// line break after it (opencode takes one; hujson wants the break). It
// reads no file: the caller has the text.
func ParseConfig(text []byte) (map[string]any, error) {
	m := map[string]any{}
	if len(bytes.TrimSpace(text)) == 0 {
		return m, nil
	}
	std, err := hujson.Standardize(append(slices.Clip(text), '\n')) // a copy, with the line break
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(std, &m); err != nil {
		return nil, err
	}
	return m, nil
}
