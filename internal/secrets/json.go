package secrets

import (
	"encoding/json"
	"strings"
)

// maxJSONScan is the longest text MaskJSONIn looks for JSON in: each
// brace is a try at a document, so a long text full of them would cost
// its square. A longer one has only the name rules (which catch
// "token": "x" on their own).
const maxJSONScan = 256 << 10

// MaskJSONIn masks, where they stand, the values under keys named like a
// secret (MaskInput's rule: every value under such a key, however deep)
// in each JSON object found in s: a line that is one, or a fragment of a
// line or of several ("HTTP 401: {…}"). Every other byte is kept; a
// brace that starts no JSON object is left as it is.
func MaskJSONIn(s, with string) string {
	if len(s) > maxJSONScan || !strings.Contains(s, "{") {
		return s
	}
	var b strings.Builder
	last := 0
	for i := 0; i < len(s); i++ {
		if s[i] != '{' {
			continue
		}
		spans, n, ok := secretValues(s[i:])
		if !ok {
			continue
		}
		for _, sp := range spans {
			b.WriteString(s[last : i+sp[0]])
			b.WriteString(`"` + with + `"`)
			last = i + sp[1]
		}
		i += n - 1
	}
	b.WriteString(s[last:])
	return b.String()
}

// secretValues reads the JSON object doc starts with and returns where
// each value to mask stands in it, and the object's length; ok is false
// when doc doesn't start with one.
func secretValues(doc string) (spans [][2]int, n int, ok bool) {
	dec := json.NewDecoder(strings.NewReader(doc))
	dec.UseNumber()
	type level struct {
		object, secret, keyed bool
		key                   string
	}
	var stack []level
	for {
		before := int(dec.InputOffset())
		tok, err := dec.Token()
		if err != nil {
			return nil, 0, false
		}
		end := int(dec.InputOffset())
		var top *level
		if len(stack) > 0 {
			top = &stack[len(stack)-1]
		}
		if d, isDelim := tok.(json.Delim); isDelim && (d == '}' || d == ']') {
			stack = stack[:len(stack)-1]
			if len(stack) == 0 {
				return spans, end, true
			}
			continue
		}
		if top != nil && top.object && !top.keyed { // a key
			top.key, _ = tok.(string)
			top.keyed = true
			continue
		}
		secret := top != nil && (top.secret || top.object && secretKey.MatchString(top.key) && !NotSecret(top.key))
		if top != nil {
			top.keyed = false
		}
		switch v := tok.(type) {
		case json.Delim:
			stack = append(stack, level{object: v == '{', secret: secret})
		case nil:
		case string:
			if secret && v != "" {
				spans = append(spans, valueAt(doc, before, end))
			}
		default: // a number or a bool
			if secret {
				spans = append(spans, valueAt(doc, before, end))
			}
		}
	}
}

// valueAt is where the value read between before and end stands, past
// the space, colon or comma read with it.
func valueAt(doc string, before, end int) [2]int {
	start := before + len(doc[before:end]) - len(strings.TrimLeft(doc[before:end], " \t\r\n:,"))
	return [2]int{start, end}
}
