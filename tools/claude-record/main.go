// Command claude-record records the Claude parity scenarios
// (internal/features/chats/testdata/claude-parity; its README says what
// a scenario is): for each, it serves the scenario's api.json from a fake
// Messages API, runs the ACP agent with claude-tee as its claude, plays
// client.json against the agent as Nushi would, and writes the
// scenario's cli.jsonl (and cli-2.jsonl… for each further claude) and
// acp-node.jsonl. make claude-record runs it.
//
//	claude-record -tee <claude-tee> -claude <claude> [-only all|name,…] [-- agent command…]
//
// The agent is Nushi's pinned claude-agent-acp under the node on PATH,
// set up once in a cache folder of its own, unless a command is given.
// Each run has a throwaway HOME, CLAUDE_CONFIG_DIR and TMPDIR, a dummy
// key and nothing else of the caller's environment but PATH, so no one's
// login or settings take part. A scenario's old recordings are replaced
// only by a run that went as its scripts say.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"slices"
	"strings"
	"syscall"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/npm"
)

func main() {
	scenarios := flag.String("scenarios", "internal/features/chats/testdata/claude-parity", "the scenarios' folder")
	only := flag.String("only", "all", `the scenarios to record: "all", or names with commas`)
	tee := flag.String("tee", "", "claude-tee, built")
	claudePath := flag.String("claude", os.Getenv("CLAUDE_TEE_REAL"), "the claude to record ($CLAUDE_TEE_REAL)")
	adapterDir := flag.String("adapter-dir", "", "where claude-agent-acp is set up (default: a cache folder)")
	acpName := flag.String("acp", "acp-node.jsonl", "the ACP recording's file name")
	flag.Parse()
	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	if *tee == "" || *claudePath == "" {
		log.Error("claude-record needs -tee and -claude (or CLAUDE_TEE_REAL)")
		os.Exit(2)
	}
	// The first Ctrl-C or SIGTERM stops the run and keeps no recording;
	// a second ends the recorder at once, as signals do by default (the
	// agent, in a process group of its own, goes on its stdin's end).
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	context.AfterFunc(ctx, cancel)
	if err := run(ctx, log, *scenarios, *only, *tee, *claudePath, *adapterDir, *acpName, flag.Args()); err != nil {
		log.Error("claude-record", "err", err)
		cancel()
		os.Exit(1) //nolint:gocritic // cancel ran
	}
}

func run(ctx context.Context, log *slog.Logger, scenarios, only, tee, claudePath, adapterDir, acpName string, agent []string) error {
	dirs, err := pick(scenarios, only)
	if err != nil {
		return err
	}
	abs := func(p string) (string, error) {
		if !strings.Contains(p, "/") {
			return p, nil // a program on PATH
		}
		return filepath.Abs(p)
	}
	if tee, err = filepath.Abs(tee); err != nil {
		return err
	}
	if claudePath, err = abs(claudePath); err != nil {
		return err
	}
	if len(agent) == 0 {
		if agent, err = nodeAgent(ctx, log, adapterDir); err != nil {
			return err
		}
	}
	r := &recorder{tee: tee, claude: claudePath, agent: agent, acp: acpName, log: log}
	var failed []string
	for _, dir := range dirs {
		if err := ctx.Err(); err != nil { // interrupted: the rest stay as they are
			return fmt.Errorf("stopped before %s: %w", filepath.Base(dir), err)
		}
		name := filepath.Base(dir)
		if err := r.record(ctx, dir); err != nil {
			log.Error("not recorded", "scenario", name, "err", err)
			failed = append(failed, name)
			continue
		}
		log.Info("recorded", "scenario", name)
	}
	if len(failed) > 0 {
		return fmt.Errorf("%d of %d scenarios failed: %s", len(failed), len(dirs), strings.Join(failed, ", "))
	}
	return nil
}

// pick is the scenarios' folders only names: those with a client.json
// and an api.json, or all of them.
func pick(scenarios, only string) ([]string, error) {
	found, err := filepath.Glob(filepath.Join(scenarios, "*", "client.json"))
	if err != nil {
		return nil, err
	}
	var all []string
	for _, f := range found {
		if _, err := os.Stat(filepath.Join(filepath.Dir(f), "api.json")); err == nil {
			all = append(all, filepath.Dir(f))
		}
	}
	if only == "all" || only == "" {
		if len(all) == 0 {
			return nil, fmt.Errorf("no scenarios in %s", scenarios)
		}
		return all, nil
	}
	var out []string
	for name := range strings.SplitSeq(only, ",") {
		dir := filepath.Join(scenarios, strings.TrimSpace(name))
		if !slices.Contains(all, dir) {
			return nil, fmt.Errorf("no scenario %q in %s", name, scenarios)
		}
		out = append(out, dir)
	}
	return out, nil
}

// nodeAgent is the command that runs Nushi's pinned claude-agent-acp,
// set up in dir (default: a cache folder) with internal/npm as Nushi sets
// it up, unless it is there at the pinned version already.
func nodeAgent(ctx context.Context, log *slog.Logger, dir string) ([]string, error) {
	if dir == "" {
		cache, err := os.UserCacheDir()
		if err != nil {
			return nil, err
		}
		dir = filepath.Join(cache, "nushi-claude-record", "claude-agent-acp")
	}
	want, err := pinned()
	if err != nil {
		return nil, err
	}
	var in npm.Installer
	version, program := in.Installed(dir, claude.AdapterPackage, claude.AdapterBin)
	if version != want {
		log.Info("setting up claude-agent-acp", "version", want, "folder", dir)
		if err := in.Install(ctx, claude.Adapter, dir, func() {}); err != nil {
			return nil, fmt.Errorf("set up claude-agent-acp: %w", err)
		}
		if version, program = in.Installed(dir, claude.AdapterPackage, claude.AdapterBin); version != want {
			return nil, errors.New("claude-agent-acp isn't there after setting it up")
		}
	}
	return []string{"node", program}, nil
}

// pinned is the claude-agent-acp version Nushi pins.
func pinned() (string, error) {
	b, err := fs.ReadFile(claude.Adapter, "package.json")
	if err != nil {
		return "", err
	}
	var p struct {
		Dependencies map[string]string `json:"dependencies"`
	}
	if err := json.Unmarshal(b, &p); err != nil || p.Dependencies[claude.AdapterPackage] == "" {
		return "", fmt.Errorf("no %s in Nushi's adapter package.json", claude.AdapterPackage)
	}
	return p.Dependencies[claude.AdapterPackage], nil
}
