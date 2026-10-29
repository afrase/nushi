package claude

import (
	"encoding/json"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// RunsShell says a process is Claude Code's shell running a Bash call's
// command (the call's input's, whole): Claude Code 2.1.312 runs one as
// [shell, "-c", ("-l",) script], the script's last two steps
// "eval <the command, shell-quoted> [< /dev/null] && pwd -P >| <file>"
// (docs/facts/claude.md, Background shells). The command is compared after
// unquoting, so a quoting Nushi doesn't foresee matches all the same; a
// command Claude Code changes before it runs (`>NUL` made `>/dev/null`),
// or whose input Nushi kept cut or masked, matches nothing.
func RunsShell(call model.Item, args []string) bool {
	var in struct {
		Command string `json:"command"`
	}
	if call.Tool != "Bash" || json.Unmarshal([]byte(call.Input), &in) != nil || in.Command == "" ||
		len(args) < 3 || len(args) > 4 || args[1] != "-c" || len(args) == 4 && args[2] != "-l" {
		return false
	}
	script := args[len(args)-1]
	for i := 0; i < len(script); i++ {
		j := strings.Index(script[i:], "eval ")
		if j < 0 {
			return false
		}
		i += j
		if (i == 0 || strings.HasSuffix(script[:i], " && ")) && evals(script[i+len("eval "):], in.Command) {
			return true
		}
	}
	return false
}

// evals says the rest of the script after an eval is command and Claude
// Code's steps after it, and nothing else.
func evals(rest, command string) bool {
	ws, ok := words(rest)
	if !ok || len(ws) < 6 || ws[0].text != command {
		return false
	}
	ws = ws[1:]
	if len(ws) == 7 && plain(ws[:2], "<", "/dev/null") {
		ws = ws[2:]
	}
	return len(ws) == 5 && plain(ws[:4], "&&", "pwd", "-P", ">|")
}

// plain says ws are these words, unquoted.
func plain(ws []word, want ...string) bool {
	return slices.EqualFunc(ws, want, func(w word, s string) bool { return !w.quoted && w.text == s })
}

type word struct {
	text   string
	quoted bool // some of it was quoted or escaped
}

// words splits s into a POSIX shell's words, unquoting them: single quotes
// keep everything, double quotes let a backslash escape $ ` " \ ! and a
// newline, a backslash outside quotes escapes any character (a newline:
// none). Not ok when a quote is left open.
func words(s string) (ws []word, ok bool) {
	var b strings.Builder
	in, quoted := false, false
	end := func() {
		if in {
			ws = append(ws, word{b.String(), quoted})
		}
		b.Reset()
		in, quoted = false, false
	}
	for i := 0; i < len(s); i++ {
		switch c := s[i]; c {
		case ' ', '\t', '\n':
			end()
		case '\'':
			j := strings.IndexByte(s[i+1:], '\'')
			if j < 0 {
				return nil, false
			}
			b.WriteString(s[i+1 : i+1+j])
			i += j + 1
			in, quoted = true, true
		case '"':
			n, ok := doubleQuoted(&b, s[i+1:])
			if !ok {
				return nil, false
			}
			i += n + 1
			in, quoted = true, true
		case '\\':
			if i+1 >= len(s) {
				return nil, false
			}
			i++
			if s[i] != '\n' {
				b.WriteByte(s[i])
				in = true
			}
			quoted = true
		default:
			b.WriteByte(c)
			in = true
		}
	}
	end()
	return ws, true
}

// doubleQuoted unquotes s up to its closing double quote into b, a
// backslash escaping $ ` " \ ! and a newline (none): how far that quote
// is into s; not ok when it never closes.
func doubleQuoted(b *strings.Builder, s string) (int, bool) {
	for i := 0; i < len(s); i++ {
		switch {
		case s[i] == '"':
			return i, true
		case s[i] == '\\' && i+1 < len(s) && strings.IndexByte("$`\"\\!\n", s[i+1]) >= 0:
			i++
			if s[i] != '\n' {
				b.WriteByte(s[i])
			}
		default:
			b.WriteByte(s[i])
		}
	}
	return 0, false
}
