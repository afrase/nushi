package opencodeskills

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/tailscale/hujson"

	"github.com/afrase/nushi/internal/jsonsettings"
)

// opencode's settings are JSON with comments. It reads its global folder's
// opencode.json and opencode.jsonc as two documents, the first before the
// second, and adds their policies up (docs/facts/opencode.md): for a
// skill, the earliest document holding a skill.use statement whose
// resource matches its id decides, by the last such statement in it;
// with none the skill is allowed. Nushi reads those two files only.
// Managed settings come before them and can overrule them; a project's
// documents come after and can't undo what these say.

// globalFiles are the global config's two files, in opencode's order.
func globalFiles() [2]string {
	dir := configDir()
	return [2]string{filepath.Join(dir, "opencode.json"), filepath.Join(dir, "opencode.jsonc")}
}

// statement is a skill.use policy.
type statement struct {
	resource string
	deny     bool
	// ours says it is an entry as Nushi writes one (entry, in switch.go),
	// which Nushi may take out again.
	ours bool
}

// document is one config file's skill.use statements, in its order.
type document struct {
	path       string
	statements []statement
}

// documents are the global config's, in opencode's order.
type documents []document

// readGlobal reads the global config's policies. A file that doesn't
// read is left out, as opencode leaves it, and named in the error.
func readGlobal() (documents, error) {
	var docs documents
	var errs []error
	for _, file := range globalFiles() {
		b, err := jsonsettings.ReadFile(file)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		var top *hujson.Object
		if err == nil {
			top, _, err = parse(b)
		}
		if err != nil {
			errs = append(errs, fmt.Errorf("%s doesn't read: %w", file, err))
			continue
		}
		docs = append(docs, document{path: file, statements: statements(top)})
	}
	return docs, errors.Join(errs...)
}

// parse reads a config file's text: an object, or nothing at all (an
// empty one). Its values keep their places in b; end is where the object
// ends there.
func parse(b []byte) (top *hujson.Object, end int, err error) {
	if len(bytes.TrimSpace(b)) == 0 {
		return &hujson.Object{}, 0, nil
	}
	// opencode takes a comment on the last line without a line break
	// after it; hujson wants the break.
	v, err := hujson.Parse(append(slices.Clip(b), '\n'))
	if err != nil {
		return nil, 0, syntaxError(err)
	}
	top, ok := v.Value.(*hujson.Object)
	if !ok {
		return nil, 0, errors.New("not an object")
	}
	return top, v.EndOffset, nil
}

// syntaxError is hujson's err in fixed words with only its place: its
// own text quotes a character of the file.
func syntaxError(err error) error {
	var line, column int
	if _, scanErr := fmt.Sscanf(err.Error(), "hujson: line %d, column %d:", &line, &column); scanErr != nil {
		return errors.New("not JSON with comments")
	}
	return fmt.Errorf("not JSON with comments (line %d, column %d)", line, column)
}

// member is the value of obj's member called name, the last if several
// (the one a JSON reader keeps); nil without one.
func member(obj *hujson.Object, name string) *hujson.Value {
	var v *hujson.Value
	for i := range obj.Members {
		if s, _ := text(&obj.Members[i].Name); s == name {
			v = &obj.Members[i].Value
		}
	}
	return v
}

// text is what a JSON string says.
func text(v *hujson.Value) (string, bool) {
	lit, ok := v.Value.(hujson.Literal)
	if !ok || lit.Kind() != '"' {
		return "", false
	}
	return lit.String(), true
}

// field is the string obj's member called name holds.
func field(obj *hujson.Object, name string) (string, bool) {
	v := member(obj, name)
	if v == nil {
		return "", false
	}
	return text(v)
}

// list is what obj's member called name lists.
func list(obj *hujson.Object, name string) []hujson.Value {
	v := member(obj, name)
	if v == nil {
		return nil
	}
	arr, _ := v.Value.(*hujson.Array)
	if arr == nil {
		return nil
	}
	return arr.Elements
}

// statements are a document's skill.use policies as opencode orders
// them: experimental.policies (the old place), then policies.
func statements(top *hujson.Object) []statement {
	var out []statement
	read := func(entries []hujson.Value, native bool) {
		for i := range entries {
			if s, ok := statementOf(&entries[i]); ok {
				s.ours = s.ours && native
				out = append(out, s)
			}
		}
	}
	if v := member(top, "experimental"); v != nil {
		if obj, ok := v.Value.(*hujson.Object); ok {
			read(list(obj, "policies"), false)
		}
	}
	read(list(top, "policies"), true)
	return out
}

// statementOf reads one entry of a policies list; ok is false for one
// that isn't about skills, or that opencode drops (not a statement). An
// integration.use of "skill:<id>" is skill.use's old spelling.
func statementOf(v *hujson.Value) (s statement, ok bool) {
	obj, isObj := v.Value.(*hujson.Object)
	if !isObj {
		return s, false
	}
	action, _ := field(obj, "action")
	resource, has := field(obj, "resource")
	effect, _ := field(obj, "effect")
	if !has || effect != "allow" && effect != "deny" {
		return s, false
	}
	s = statement{resource: resource, deny: effect == "deny"}
	s.ours = action == "skill.use" && s.deny && len(obj.Members) == 3 && !commented(obj)
	if rest, cut := strings.CutPrefix(resource, "skill:"); cut && action == "integration.use" {
		action, s.resource = "skill.use", rest
	}
	return s, action == "skill.use"
}

// commented says a comment is written inside obj, whose members hold
// plain values: taking the entry out would take the comment with it.
func commented(obj *hujson.Object) bool {
	extras := []hujson.Extra{obj.AfterExtra}
	for _, m := range obj.Members {
		extras = append(extras, m.Name.BeforeExtra, m.Name.AfterExtra, m.Value.BeforeExtra, m.Value.AfterExtra)
	}
	return slices.ContainsFunc(extras, hasComment)
}

// hasComment says extra (the blanks and comments between two values)
// holds a comment: each starts with a slash.
func hasComment(extra hujson.Extra) bool { return bytes.IndexByte(extra, '/') >= 0 }

// match is opencode's wildcard match of a skill's id against a policy's
// resource: * is any text, ? any one character, and a trailing " *" may
// be missing altogether.
func match(id, pattern string) bool {
	if !strings.ContainsAny(pattern, `*?\`) && !strings.Contains(id, `\`) {
		return id == pattern
	}
	p := regexp.QuoteMeta(strings.ReplaceAll(pattern, `\`, "/"))
	p = strings.ReplaceAll(strings.ReplaceAll(p, `\*`, ".*"), `\?`, ".")
	if head, ok := strings.CutSuffix(p, " .*"); ok {
		p = head + "( .*)?"
	}
	re, err := regexp.Compile("(?s)^" + p + "$")
	return err == nil && re.MatchString(strings.ReplaceAll(id, `\`, "/"))
}

// denies says whether opencode leaves the skill id out and the file
// whose statement decides ("" when none matches: allowed). withoutOurs
// reads the files as if Nushi's own entries for id weren't in them.
func (d documents) denies(id string, withoutOurs bool) (bool, string) {
	for _, doc := range d {
		for _, s := range slices.Backward(doc.statements) {
			if withoutOurs && s.ours && s.resource == id {
				continue
			}
			if match(id, s.resource) {
				return s.deny, doc.path
			}
		}
	}
	return false, ""
}

// off says opencode leaves the skill id out, and the file that decides
// when taking Nushi's own entries out wouldn't bring it back (another
// statement, a pattern, the old spelling).
func (d documents) off(id string) (bool, string) {
	if deny, _ := d.denies(id, false); !deny {
		return false, ""
	}
	if deny, file := d.denies(id, true); deny {
		return true, file
	}
	return true, ""
}
