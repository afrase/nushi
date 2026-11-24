// Package shellenv reads the environment the user's login shell gives a
// terminal: it runs the shell as a login, interactive shell that prints
// its environment between two marks, as VS Code's "resolve shell
// environment" does (read_unix.go). Windows has no login shell: there it
// reads the registry's environment, which a new terminal gets
// (read_windows.go). Agents start with it, and the daemon applies it to
// its own environment (ADR 0048), whatever started the daemon. The values are never logged or kept anywhere but in memory;
// the log has the shell, how long it took and how it ended, and the names
// the shell adds at DEBUG.
package shellenv

import (
	"slices"
	"strings"
)

// Resolving is set in the shell's environment while it's read, so a shell
// config can skip what only a terminal wants (starting tmux, a greeting).
const Resolving = "NUSHI_RESOLVING_ENVIRONMENT"

// Own says the variable named name is Nushi's: the daemon's settings
// (NUSHI_DATA, NUSHI_LOG), what its launcher sets (NUSHID_DATA), a chat's
// tools server's (NUSHI_SOCKET, NUSHI_TOOLS_KEY).
// None goes to an agent.
func Own(name string) bool {
	return strings.HasPrefix(name, "NUSHI_") || strings.HasPrefix(name, "NUSHID_")
}

// Merge is base with over's variables on top (over wins), and Nushi's own
// left out. The order is base's, then what over adds. A name is the same
// one as the OS takes it (nameKey: on Windows, whatever its case).
func Merge(base, over []string) []string {
	at := map[string]int{}
	var out []string
	for _, list := range [][]string{base, over} {
		for _, kv := range list {
			name, _, _ := strings.Cut(kv, "=")
			if Own(name) {
				continue
			}
			if i, ok := at[nameKey(name)]; ok {
				out[i] = kv
				continue
			}
			at[nameKey(name)] = len(out)
			out = append(out, kv)
		}
	}
	return out
}

// Gone are the names of had's variables that environ hasn't (whatever
// their case on Windows, nameKey), but Nushi's own (Own): what a daemon
// that had had and now takes environ unsets.
func Gone(had, environ []string) []string {
	has := map[string]bool{}
	for _, kv := range environ {
		name, _, _ := strings.Cut(kv, "=")
		has[nameKey(name)] = true
	}
	var out []string
	for _, kv := range had {
		if name, _, _ := strings.Cut(kv, "="); name != "" && !has[nameKey(name)] && !Own(name) && !slices.Contains(out, name) {
			out = append(out, name)
		}
	}
	return out
}

// Get is the value of the variable named name in env, the last one when
// it's there twice (as exec does); "" when it isn't. On Windows a name is
// the same whatever its case (nameKey).
func Get(env []string, name string) string {
	for _, kv := range slices.Backward(env) {
		if n, v, ok := strings.Cut(kv, "="); ok && nameKey(n) == nameKey(name) {
			return v
		}
	}
	return ""
}
