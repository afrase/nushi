package claudeacp

import "encoding/json"

// completeFields reads a tool's input as the model streams it, a JSON
// object cut off anywhere: it is the object of the top-level fields
// already complete (those a comma at the top level has closed) and how
// many there are. A client sees the input grow a field at a time, never
// a value cut in half; the last field comes with the whole input.
func completeFields(partial string) (json.RawMessage, int) {
	depth, n, last := 0, 0, -1
	inString, escaped := false, false
	for i := range len(partial) {
		c := partial[i]
		switch {
		case inString:
			switch {
			case escaped:
				escaped = false
			case c == '\\':
				escaped = true
			case c == '"':
				inString = false
			}
		case c == '"':
			inString = true
		case c == '{' || c == '[':
			depth++
		case c == '}' || c == ']':
			depth--
		case c == ',' && depth == 1:
			n, last = n+1, i
		}
	}
	if last < 0 {
		return nil, 0
	}
	obj := json.RawMessage(partial[:last] + "}")
	if !json.Valid(obj) {
		return nil, 0
	}
	return obj, n
}
