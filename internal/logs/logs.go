// Package logs is the daemon's log (ADR 0038): slog's text format into
// nushid.log in the data folder, rotated by size, with the home folder
// written as ~ and known secret shapes masked on every line.
package logs

import (
	"fmt"
	"io"
	"log/slog"
	"os"
	"strings"
)

// Level is the lowest level written: INFO, or DEBUG when NUSHI_LOG=debug
// or the setting says so (SetDebug).
var Level = func() *slog.LevelVar {
	l := new(slog.LevelVar)
	if fromEnv {
		l.Set(slog.LevelDebug)
	}
	return l
}()

// fromEnv says NUSHI_LOG=debug asks for DEBUG whatever the setting says.
var fromEnv = strings.EqualFold(os.Getenv("NUSHI_LOG"), "debug")

// SetDebug follows the debug setting.
func SetDebug(on bool) {
	if on || fromEnv {
		Level.Set(slog.LevelDebug)
	} else {
		Level.Set(slog.LevelInfo)
	}
}

// Handler writes records to w in slog's text format, at Level and above.
func Handler(w io.Writer) slog.Handler {
	home, _ := os.UserHomeDir()
	return slog.NewTextHandler(w, &slog.HandlerOptions{Level: Level, ReplaceAttr: func(_ []string, a slog.Attr) slog.Attr {
		var s string
		switch v := a.Value.Any(); a.Value.Kind() {
		case slog.KindString:
			s = a.Value.String()
		case slog.KindAny:
			if _, ok := v.(fmt.Stringer); !ok {
				if _, ok := v.(error); !ok {
					return a // numbers, lists: what the code put there
				}
			}
			s = fmt.Sprint(v)
		default:
			return a
		}
		return slog.String(a.Key, Redact(tilde(s, home)))
	}})
}

// tilde writes home as ~ in s, where it is a whole folder name.
func tilde(s, home string) string {
	if home == "" || home == "/" {
		return s
	}
	var b strings.Builder
	for {
		i := strings.Index(s, home)
		if i < 0 {
			break
		}
		rest := s[i+len(home):]
		b.WriteString(s[:i])
		if rest == "" || !strings.ContainsAny(rest[:1], nameChars) {
			b.WriteString("~")
		} else {
			b.WriteString(home)
		}
		s = rest
	}
	b.WriteString(s)
	return b.String()
}

// nameChars go on a folder's name: home followed by one is another folder.
const nameChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"

// Setup makes path the log, for the slog default: the daemon calls it once
// it holds the socket, so a second daemon, which only says why it stops,
// never rotates the first one's log.
func Setup(path string) (*File, error) {
	f, err := Open(path, true)
	if err != nil {
		return nil, err
	}
	slog.SetDefault(slog.New(Handler(f)))
	return f, nil
}
