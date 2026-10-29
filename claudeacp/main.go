package claudeacp

import (
	"io"
	"log/slog"
	"os"
	ossignal "os/signal" // signal is a test helper's name
	"syscall"
)

// Command is the subcommand name a program that embeds the agent can run
// it under, as Nushi's daemon does (nushid claude-acp).
const Command = "claude-acp"

// Main runs the agent on stdin and stdout, logging to stderr; it returns
// once the client has gone and every claude has exited. The claude it
// runs is $CLAUDE_CODE_EXECUTABLE, the variable claude-agent-acp reads
// too, else claude on PATH.
//
// Each claude stays in the agent's process group, as claude-agent-acp's
// does, so a client that kills the agent's group kills every claude with
// it, even one the agent had no time to close. SIGTERM and SIGINT end the
// agent as the end of stdin does: each session is closed, and its claude
// exits; a second one kills the agent at once.
func Main() {
	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	Serve(untilSignal(os.Stdin, log), os.Stdout, Config{CLIPath: os.Getenv("CLAUDE_CODE_EXECUTABLE"), Log: log, SharedGroup: true})
}

// untilSignal is r until it ends or the process gets SIGTERM or SIGINT,
// which end it as EOF would.
func untilSignal(r io.Reader, log *slog.Logger) io.Reader {
	pr, pw := io.Pipe()
	go func() {
		_, err := io.Copy(pw, r)
		_ = pw.CloseWithError(err)
	}()
	sigs := make(chan os.Signal, 1)
	ossignal.Notify(sigs, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		sig := <-sigs
		ossignal.Stop(sigs) // the next one has its default effect
		log.Info("closing the sessions on a signal", "signal", sig)
		_ = pw.Close()
	}()
	return pr
}
