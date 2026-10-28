package chats

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"regexp"
	"strings"
)

// secretMask stands in for a secret in a tool call's input, as the MCP
// view's Mask does.
const secretMask = "••••" //nolint:gosec // a mask, not a credential

var (
	// secretKey is a JSON key whose string value is a secret.
	secretKey = regexp.MustCompile(`(?i)token|secret|passw(?:or)?d|api[_-]?key|authorization|cookie|private[_-]?key|credential`)
	// secretShape is what a key or token looks like in any string: vendors'
	// prefixes, AWS key ids, JWTs, PEM blocks, and the values of bearer
	// and basic credentials (as internal/logs redacts a log's lines).
	secretShape = regexp.MustCompile(strings.Join([]string{
		`()\bsk-[A-Za-z0-9_-]{16,}`,                                          // Anthropic (sk-ant-…), OpenAI (sk-proj-…)
		`()\b(?:gh[pousr]_|github_pat_)\w{20,}`,                              // GitHub
		`()\bxox[abposr]-[A-Za-z0-9-]{10,}`,                                  // Slack
		`()\b(?:AKIA|ASIA)[0-9A-Z]{16}\b`,                                    // AWS key ids
		`()\beyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{8,}`,                             // JWTs
		`()-----BEGIN [A-Z0-9 ]+-----[\s\S]*?(?:-----END [A-Z0-9 ]+-----|$)`, // PEM, to its end or the cut
		`((?i)\b(?:bearer|basic)\s+)[\w.~+/=-]{8,}`,
		`(://[^/\s:@]+:)[^/\s@]+@`, // a password in a URL
		`((?i)\b[A-Za-z_][\w.-]*(?:token|secret|passw(?:or)?d|api[_-]?key|credential)[\w.-]*=)[^\s"',;&|]{4,}`, // NAME=value
	}, "|"))
)

// maskSecrets masks what looks secret in a tool call's input, as JSON
// (its keys' order kept) or as text: the string values of keys named like
// a secret, and anything shaped like a key or token in any string.
func maskSecrets(input string) string {
	if out, err := maskJSON(input); err == nil {
		return out
	}
	return maskShapes(input)
}

// maskShapes masks the secret shapes in s, keeping what names them (the
// "Bearer ", a URL's user).
func maskShapes(s string) string {
	return secretShape.ReplaceAllStringFunc(s, func(m string) string {
		for _, g := range secretShape.FindStringSubmatch(m)[1:] {
			if g != "" && strings.HasPrefix(g, "://") { // a URL's user:password@
				return g + secretMask + "@"
			} else if g != "" {
				return g + secretMask
			}
		}
		return secretMask
	})
}

// maskJSON masks a JSON document token by token, so its keys keep their
// order, and indents it again.
func maskJSON(input string) (string, error) {
	dec := json.NewDecoder(strings.NewReader(input))
	dec.UseNumber()
	var m jsonMasker
	for {
		tok, err := dec.Token()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return "", err
		}
		if err := m.token(tok); err != nil {
			return "", err
		}
	}
	var b bytes.Buffer
	if err := json.Indent(&b, m.out.Bytes(), "", "  "); err != nil {
		return "", err
	}
	return b.String(), nil
}

// jsonMasker writes a JSON document again from its tokens, masked.
type jsonMasker struct {
	out   bytes.Buffer
	stack []jsonLevel
}

// jsonLevel is an object or array being written.
type jsonLevel struct {
	object bool
	secret bool   // an array a secret key holds: its strings are secrets
	n      int    // values written
	key    string // the object's key being given its value
	keyed  bool   // a key was written, its value comes next
}

func (m *jsonMasker) token(tok json.Token) error {
	var top *jsonLevel
	if len(m.stack) > 0 {
		top = &m.stack[len(m.stack)-1]
	}
	if d, ok := tok.(json.Delim); ok && (d == '}' || d == ']') {
		m.out.WriteString(d.String())
		m.stack = m.stack[:len(m.stack)-1]
		return nil
	}
	if top != nil && top.object && !top.keyed { // a key
		if top.n > 0 {
			m.out.WriteByte(',')
		}
		top.key, _ = tok.(string)
		top.keyed = true
		if err := m.write(top.key); err != nil {
			return err
		}
		m.out.WriteByte(':')
		return nil
	}
	if top != nil && !top.object && top.n > 0 {
		m.out.WriteByte(',')
	}
	secret := top != nil && (top.object && secretKey.MatchString(top.key) || top.secret)
	if top != nil {
		top.n++
		top.keyed = false
	}
	switch v := tok.(type) {
	case json.Delim:
		m.out.WriteString(v.String())
		m.stack = append(m.stack, jsonLevel{object: v == '{', secret: secret && v == '['})
		return nil
	case string:
		if secret && v != "" {
			v = secretMask
		}
		return m.write(maskShapes(v))
	default:
		return m.write(v)
	}
}

// write writes v as JSON, a command's && as written.
func (m *jsonMasker) write(v any) error {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return err
	}
	m.out.Write(bytes.TrimSuffix(b.Bytes(), []byte("\n")))
	return nil
}
