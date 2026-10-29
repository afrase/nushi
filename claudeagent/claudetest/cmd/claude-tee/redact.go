package main

import (
	"bytes"
	"encoding/json"
	"strings"
)

// secretKeys are the keys whose values a cassette never keeps, only their
// names: an MCP server's environment and HTTP headers (in --mcp-config,
// --settings, initialize and mcp_set_servers), where its tokens go, and
// the settings' env, which may hold an API key.
var secretKeys = map[string]bool{"env": true, "headers": true}

// redacted stands in for a value a cassette doesn't keep.
const redacted = "<redacted>"

// redactArgs is args with the secrets in any JSON value taken out: a JSON
// argument, or the value of --flag=JSON.
func redactArgs(args []string) []string {
	out := make([]string, len(args))
	for i, a := range args {
		out[i] = a
		flag, value, isFlag := strings.Cut(a, "=")
		if !isFlag || !strings.HasPrefix(flag, "-") {
			flag, value = "", a
		}
		if r, ok := redactJSON([]byte(value)); ok {
			out[i] = string(r)
			if flag != "" {
				out[i] = flag + "=" + string(r)
			}
		}
	}
	return out
}

// redactJSON is raw with every value under a secretKeys object replaced,
// and true, when raw is JSON holding one; else raw and false, untouched,
// so a frame without secrets keeps its bytes and its keys' order.
func redactJSON(raw []byte) ([]byte, bool) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] != '{' && raw[0] != '[' || !hasSecretKey(raw) {
		return raw, false
	}
	var v any
	d := json.NewDecoder(bytes.NewReader(raw))
	d.UseNumber()
	if d.Decode(&v) != nil {
		return raw, false
	}
	if !redact(v) {
		return raw, false
	}
	var b bytes.Buffer
	e := json.NewEncoder(&b)
	e.SetEscapeHTML(false)
	if err := e.Encode(v); err != nil {
		return raw, false
	}
	return bytes.TrimSpace(b.Bytes()), true
}

// hasSecretKey says whether raw may hold a secretKeys key: a quick look
// before decoding every frame.
func hasSecretKey(raw []byte) bool {
	for k := range secretKeys {
		if bytes.Contains(raw, []byte(`"`+k+`"`)) {
			return true
		}
	}
	return false
}

// redact replaces, in place, the values of each secretKeys object in v,
// and says whether it replaced any.
func redact(v any) bool {
	changed := false
	switch v := v.(type) {
	case map[string]any:
		for k, x := range v {
			if m, ok := x.(map[string]any); ok && secretKeys[k] {
				for name, value := range m {
					if value != redacted {
						m[name] = redacted
						changed = true
					}
				}
				continue
			}
			changed = redact(x) || changed
		}
	case []any:
		for _, x := range v {
			changed = redact(x) || changed
		}
	}
	return changed
}
