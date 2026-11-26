package secrets

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"regexp"
	"slices"
	"strings"
)

// InputMask stands in for a secret in a tool call's input, as the MCP
// view's Mask does.
const InputMask = "••••"

var (
	// secretKey is a JSON key whose string value is a secret.
	secretKey = regexp.MustCompile(`(?i)token|secret|passw(?:or)?d|api[_-]?key|authorization|cookie|private[_-]?key|credential`)
	// secretName is a NAME=value pair whose name says secret: it ends
	// in a word for one (secretWords), password=, MY_TOKEN=, apiKey=, but
	// isn't a plain name (NotSecret), masked beside the shapes every
	// secret mask knows. Narrower than the log's rule: a tool call's input
	// holds code ("key: value" in it is rarely a secret, nor is
	// secretary=, tokenizer= or credentialsFile=). Its floor is the rule
	// as main had it, which took any name holding the word after another
	// character (my_secretary=, max_tokens=).
	secretName = &NameRule{
		patterns: []*regexp.Regexp{regexp.MustCompile(`((?i)\b[\w.-]*(?:token|secret|passw(?:or)?d|key|credentials?)=)[^\s"',;&|]{4,}`)},
		accept:   secretNamed,
		floor:    regexp.MustCompile(`((?i)\b[A-Za-z_][\w.-]*(?:token|secret|passw(?:or)?d|api[_-]?key|credential)[\w.-]*=)[^\s"',;&|]{4,}`),
	}
)

// MaskInput masks what looks secret in a tool call's input, as JSON (its
// keys' order kept, indented) or as text: every value under a key named
// like a secret (strings, numbers, bools, however deep), and anything
// shaped like a key or token in any string or key. A chat's transcript
// and a workflow agent's steps mask the same way.
func MaskInput(input string) string {
	if out, err := maskJSON(input); err == nil {
		return out
	}
	return MaskText(input)
}

// secretWords are the last parts of a name that say secret (lower case).
var secretWords = map[string]bool{
	"token": true, "secret": true, "password": true, "passwd": true,
	"apikey": true, "credential": true, "credentials": true,
}

// secretNamed says whether a NAME= (its = kept) names a secret: split at
// . _ and - and where lower case turns upper (apiKey is api and Key), its
// last part is one of secretWords, or it is key after api (apiKey), or
// key with secret or private anywhere before it (SECRET_KEY,
// private_key, SECRET_ACCESS_KEY); and it isn't a plain name
// (NotSecret). The word must be a whole part, so secretary, tokenizer,
// tokens and passwordless are no secret's name, and the last, so
// credentialsFile and tokenUrl (a file, a URL) aren't; a key alone
// (primary_key, KEY) names no secret.
func secretNamed(group string) bool {
	name := strings.TrimSuffix(group, "=")
	parts := nameParts(name)
	n := len(parts)
	if n == 0 || NotSecret(name) {
		return false
	}
	if secretWords[parts[n-1]] {
		return true
	}
	if parts[n-1] != "key" || n < 2 {
		return false
	}
	return parts[n-2] == "api" || slices.Contains(parts[:n-1], "secret") || slices.Contains(parts[:n-1], "private")
}

// nameParts are a name's parts, lower case: split at . _ and -, and
// before an upper-case letter that follows a lower-case one.
func nameParts(name string) []string {
	var parts []string
	start := 0
	for i := 0; i <= len(name); i++ {
		switch {
		case i == len(name) || name[i] == '.' || name[i] == '_' || name[i] == '-':
		case i > 0 && 'a' <= name[i-1] && name[i-1] <= 'z' && 'A' <= name[i] && name[i] <= 'Z':
			parts = append(parts, strings.ToLower(name[start:i]))
			start = i
			continue
		default:
			continue
		}
		if i > start {
			parts = append(parts, strings.ToLower(name[start:i]))
		}
		start = i + 1
	}
	return parts
}

// MaskText masks the secret shapes in s and NAME=value pairs whose name
// says secret, keeping what names them (the "Bearer ", a URL's user, the
// NAME=): the rule for a tool call's text, such as a command.
func MaskText(s string) string { return Mask(s, InputMask, secretName) }

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
		if err := m.write(MaskText(top.key)); err != nil { // a token as a key too
			return err
		}
		m.out.WriteByte(':')
		return nil
	}
	if top != nil && !top.object && top.n > 0 {
		m.out.WriteByte(',')
	}
	secret := top != nil && (top.secret || top.object && secretKey.MatchString(top.key) && !NotSecret(top.key))
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
			v = InputMask
		}
		return m.write(MaskText(v))
	case nil:
		return m.write(v)
	default: // a number or a bool
		if secret {
			return m.write(InputMask)
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
