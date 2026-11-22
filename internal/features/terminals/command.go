package terminals

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
