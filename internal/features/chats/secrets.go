package chats

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"regexp"
	"strings"

	"github.com/afrase/nushi/internal/secrets"
)

// secretMask stands in for a secret in a tool call's input, as the MCP
// view's Mask does.
const secretMask = "••••" //nolint:gosec // a mask, not a credential

var (
	// secretKey is a JSON key whose string value is a secret.
	secretKey = regexp.MustCompile(`(?i)token|secret|passw(?:or)?d|api[_-]?key|authorization|cookie|private[_-]?key|credential`)
	// countKey is a key about how many tokens (a model's max_tokens, a
	// usage's input_tokens), not a token: its value shows.
	countKey = regexp.MustCompile(`(?i)(max|min|input|output|total|cached|reasoning|thinking)[_-]?tokens?|tokens?[_-]?(count|limit|budget|used|usage)`)
	// secretName is a NAME=value pair whose name says secret, masked after
	// the shapes every secret mask knows (internal/secrets). Narrower than
	// the log's rule: a tool call's input holds code ("key: value" in it is
	// rarely a secret).
	secretName = regexp.MustCompile(`((?i)\b[A-Za-z_][\w.-]*(?:token|secret|passw(?:or)?d|api[_-]?key|credential)[\w.-]*=)[^\s"',;&|]{4,}`)
)

// maskSecrets masks what looks secret in a tool call's input, as JSON
// (its keys' order kept) or as text: every value under a key named like a
// secret (strings, numbers, bools, however deep), and anything shaped
// like a key or token in any string or key.
func maskSecrets(input string) string {
	if out, err := maskJSON(input); err == nil {
		return out
	}
	return maskShapes(input)
}

// maskShapes masks the secret shapes in s, keeping what names them (the
// "Bearer ", a URL's user).
func maskShapes(s string) string { return secrets.Mask(s, secretMask, secretName) }

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
	secret bool   // under a secret key: every value in it is a secret
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
		if err := m.write(maskShapes(top.key)); err != nil { // a token as a key too
			return err
		}
		m.out.WriteByte(':')
		return nil
	}
	if top != nil && !top.object && top.n > 0 {
		m.out.WriteByte(',')
	}
	secret := top != nil && (top.secret || top.object && secretKey.MatchString(top.key) && !countKey.MatchString(top.key))
	if top != nil {
		top.n++
		top.keyed = false
	}
	switch v := tok.(type) {
	case json.Delim:
		m.out.WriteString(v.String())
		m.stack = append(m.stack, jsonLevel{object: v == '{', secret: secret})
		return nil
	case string:
		if secret && v != "" {
			v = secretMask
		}
		return m.write(maskShapes(v))
	case nil:
		return m.write(v)
	default: // a number or a bool
		if secret {
			return m.write(secretMask)
		}
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
