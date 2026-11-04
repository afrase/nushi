// Command claude-record records the Claude parity scenarios
// (internal/features/chats/testdata/claude-parity; its README says what
// a scenario is): for each, it serves the scenario's api.json from a fake
// Messages API, runs the ACP agent with claude-tee as its claude, plays
// client.json against the agent as Nushi would, and writes the
// scenario's cli.jsonl (and cli-2.jsonl… for each further claude) and
// acp.jsonl. make claude-record runs it, with Nushi's Go agent (`nushid
// claude-acp`) as the agent.
//
//	claude-record -tee <claude-tee> -claude <claude> [-only all|name,…] -- agent command…
//
// The scenarios recorded until 2026-11-03 ran claude-agent-acp, the Node
// adapter Claude ran through before the Go agent (ADR 0066). Each run has a throwaway HOME, CLAUDE_CONFIG_DIR and TMPDIR, a dummy
// key and nothing else of the caller's environment but PATH, so no one's
// login or settings take part. A scenario's old recordings are replaced
// only by a run that went as its scripts say.
package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"slices"
	"strings"
	"syscall"
)

func main() {
	scenarios := flag.String("scenarios", "internal/features/chats/testdata/claude-parity", "the scenarios' folder")
	only := flag.String("only", "all", `the scenarios to record: "all", or names with commas`)
	tee := flag.String("tee", "", "claude-tee, built")
	claudePath := flag.String("claude", os.Getenv("CLAUDE_TEE_REAL"), "the claude to record ($CLAUDE_TEE_REAL)")
	acpName := flag.String("acp", "acp.jsonl", "the ACP recording's file name")
	mcpEcho := flag.String("mcp-echo", "", "claudetest's mcp-echo, built: the scenarios' $mcp-echo")
	flag.Parse()
	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	if *tee == "" || *claudePath == "" || flag.NArg() == 0 {
		log.Error("claude-record needs -tee, -claude (or CLAUDE_TEE_REAL) and the agent's command after --")
		os.Exit(2)
	}
	// The first Ctrl-C or SIGTERM stops the run and keeps no recording;
	// a second ends the recorder at once, as signals do by default (the
	// agent, in a process group of its own, goes on its stdin's end).
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	context.AfterFunc(ctx, cancel)
	r := &recorder{tee: *tee, claude: *claudePath, agent: flag.Args(), acp: *acpName, mcpEcho: *mcpEcho, log: log}
	if err := run(ctx, *scenarios, *only, r); err != nil {
		log.Error("claude-record", "err", err)
		cancel()
		os.Exit(1) //nolint:gocritic // cancel ran
	}
}

// run records the scenarios only names in scenarios with r, whose paths
// it makes absolute.
func run(ctx context.Context, scenarios, only string, r *recorder) error {
	dirs, err := pick(scenarios, only)
	if err != nil {
		return err
	}
	abs := func(p string) (string, error) {
		if !strings.Contains(p, "/") {
			return p, nil // a program on PATH, or none
		}
		return filepath.Abs(p)
	}
	if r.tee, err = filepath.Abs(r.tee); err != nil {
		return err
	}
	if r.claude, err = abs(r.claude); err != nil {
		return err
	}
	if r.mcpEcho, err = abs(r.mcpEcho); err != nil {
		return err
	}
	if r.agent[0], err = abs(r.agent[0]); err != nil {
		return err
	}
	log := r.log
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
