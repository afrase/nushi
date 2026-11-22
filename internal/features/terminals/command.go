package terminals

import (
	"errors"
	"fmt"
	"strings"
	"unicode"
	"unicode/utf8"
)

// signaled is a Shell that says which signal killed its program (a
// *terminal.Terminal does).
type signaled interface{ Signal() int }

// exitOf is sh's exit as the terminal reports it. A command's terminal
// reports a program killed by a signal as a shell does, 128 plus the
// signal (130 for ⌃C), not -1: without job control, ⌃C there kills the
// shell running the command, and the app tells a stopped command from a
// failed one by that code.
func exitOf(sh Shell, command string) (exited bool, code int) {
	exited, code = sh.Exit()
	if s, ok := sh.(signaled); ok && exited && command != "" && code < 0 {
		if sig := s.Signal(); sig > 0 {
			code = 128 + sig
		}
	}
	return exited, code
}

// ErrBadCommand is a command a terminal won't run (checkCommand).
var ErrBadCommand = errors.New("a command a terminal won't run")

// maxCommand is the longest command a terminal runs, in bytes, as Claude
// Code limits a "!" command.
const maxCommand = 64 << 10

// checkCommand refuses a command of only spaces, one over maxCommand
// bytes, one holding a control character other than tab and newline (as
// Claude Code does for a "!" command), and one holding a bidirectional
// mark or override (as ▷ refuses a block holding one): a carriage return
// or an escape could hide what runs from what was shown, and a bidi
// override shows the text in another order than the shell reads it. ""
// is no command: a shell.
func checkCommand(command string) error {
	switch {
	case command == "":
		return nil
	case strings.TrimSpace(command) == "":
		return fmt.Errorf("%w: it is empty", ErrBadCommand)
	case len(command) > maxCommand:
		return fmt.Errorf("%w: it is over %d bytes", ErrBadCommand, maxCommand)
	case !utf8.ValidString(command):
		return fmt.Errorf("%w: it isn't UTF-8 text", ErrBadCommand)
	case strings.ContainsFunc(command, func(r rune) bool { return r != '\t' && r != '\n' && unicode.IsControl(r) }):
		return fmt.Errorf("%w: it holds a control character other than tab and newline", ErrBadCommand)
	case strings.ContainsFunc(command, bidi):
		return fmt.Errorf("%w: it holds a bidirectional override", ErrBadCommand)
	}
	return nil
}

// bidi says whether r reorders text as it shows: the bidirectional marks,
// embeddings, overrides and isolates (U+200E, U+200F, U+202A–U+202E,
// U+2066–U+2069).
func bidi(r rune) bool {
	return r == 0x200e || r == 0x200f || r >= 0x202a && r <= 0x202e || r >= 0x2066 && r <= 0x2069
}
