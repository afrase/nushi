package main

import (
	"errors"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/claudehistory"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/npm"
	"github.com/afrase/nushi/internal/shellenv"
)

// newShellEnv is the environment of shell, the login shell, read once
// before it returns (shellenv.Timeout at most, and as long again for a
// plain login shell's when that fails) and again when Settings › Agents
// asks, whatever started the daemon (ADR 0048, 0101): agents start with
// it, and each reading that works is applied to the daemon's own
// environment, so what the daemon runs itself (claude mcp, gh, the trash)
// and its reads of agents' folders (CLAUDE_CONFIG_DIR, CODEX_HOME) agree
// with the agents. NUSHI_SHELL_ENV=off keeps the daemon's own (tests set
// PATH to their fake agents; the shell's would replace it).
func newShellEnv(shell string) *shellenv.Env {
	shellEnv := shellenv.New(knownShell(shell), os.Environ())
	if os.Getenv("NUSHI_SHELL_ENV") == "off" {
		shellEnv = shellenv.Off(os.Environ())
	}
	shellEnv.Use(setEnviron(os.Environ()))
	shellEnv.Start()
	shellEnv.Environ() // waits for the first reading
	return shellEnv
}

// fromLoginShell reads the login shell's environment and applies it to
// the daemon (newShellEnv), then reads what that environment decides:
// Claude's projects folder (CLAUDE_CONFIG_DIR, which a profile or rc may
// export), so the daemon reads Claude's history where its agents write
// it.
func fromLoginShell(shell string) (shellEnv *shellenv.Env, projects string, err error) {
	shellEnv = newShellEnv(shell)
	projects, err = claudehistory.Projects()
	return shellEnv, projects, err
}

// setEnviron applies each environment it's given to the daemon's own,
// which was base: it sets each of its variables and unsets those base or
// an earlier one had that it hasn't (the shell unset them; shellenv.Gone).
// Nushi's own variables are never in it, and stay (shellenv.Own).
func setEnviron(base []string) func(environ []string) {
	had := slices.Clone(base)
	return func(environ []string) {
		for _, name := range shellenv.Gone(had, environ) {
			_ = os.Unsetenv(name) // fails only on a malformed name
		}
		for _, kv := range environ {
			if name, value, ok := strings.Cut(kv, "="); ok && name != "" {
				_ = os.Setenv(name, value) // fails only on a malformed name, which no environment holds
			}
		}
		had = shellenv.Merge(had, environ)
	}
}

// newAgents is the agents feature: the agents Nushi knows, found on the
// PATH of shellEnv, the environment they start with (ADR 0048), their
// adapters set up in dir/agents.
func newAgents(dir string, known []knownagents.Agent, shellEnv *shellenv.Env) *agents.Service {
	var list []agents.Agent
	for _, a := range known {
		list = append(list, a.Agent)
	}
	return agents.New(list, agents.Run(shellEnv.Environ), shellEnv, filepath.Join(dir, "agents"), npm.Installer{Environ: shellEnv.Environ})
}

// chatKinds are the agents as chats run them, from dir (the daemon's
// folder): each started through the agents feature (ADR 0037), which says
// whether it could start (Ready) and adds to why it failed what may help
// (Explain), its harness the one that reads its own files on this Mac.
func chatKinds(dir string, known []knownagents.Agent, agentSvc *agents.Service) []chats.Kind {
	var kinds []chats.Kind
	for _, a := range known {
		name, harness := a.Agent.Name, a.Local
		kinds = append(kinds, chats.Kind{
			Harness:  harness,
			MCP:      a.MCP != nil,
			Explain:  signedOut(a.Agent.SignIn, agentSvc.Explain(name)),
			NoSignIn: a.Agent.NoSignIn,
			Ready:    func() error { _, err := agentSvc.Run(name); return err },
			Launch: func(h acp.Client, log *slog.Logger) (chats.Agent, error) {
				run, err := agentSvc.Run(name)
				if err != nil {
					return nil, err
				}
				agent, err := harness.Start(dir, run, h, log)
				if err != nil {
					return nil, err // not a nil *agentproc.Agent in a chats.Agent
				}
				return agent, nil
			},
		})
	}
	return kinds
}

// signedOutError is a start the agent refused for want of a sign-in, in
// the user's words; the agent's own error stays underneath.
type signedOutError struct {
	signIn string
	err    error
}

func (e *signedOutError) Error() string {
	if e.signIn == "" {
		return "it isn't signed in. Sign in with its CLI in a terminal, then start the chat again."
	}
	return "it isn't signed in. Run " + e.signIn + " in a terminal, then start the chat again."
}

func (e *signedOutError) Unwrap() error { return e.err }

// signedOut is explain, but for a start the agent refused with ACP's
// Authentication required (Codex with no login, through either of its
// agents): the plain message of how the user signs in, signIn being the
// command ("": unknown). It is all a start says when the agent offers no
// way Nushi can run, and what the phone shows; otherwise the error also
// carries the ways to sign in (chats.SignInError, the API's AgentSignIn),
// which the Mac's app offers (SignInAgent, ADR 0145).
func signedOut(signIn string, explain func(error) error) func(error) error {
	return func(err error) error {
		if aerr := (*acp.Error)(nil); errors.As(err, &aerr) && aerr.Code == acp.ErrorCodeAuthenticationRequired {
			return &signedOutError{signIn: signIn, err: err}
		}
		return explain(err)
	}
}
