package main

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/afrase/nushi/claudeagent/claudetest/fakeapi"
	"github.com/afrase/nushi/claudeagent/sessions"
	"github.com/afrase/nushi/internal/proctree"
)

// recorder records scenarios: the agent on claude-tee on claude, claude
// on the fake API, all in throwaway folders.
type recorder struct {
	tee    string   // claude-tee
	claude string   // the claude it runs
	agent  []string // the ACP agent's command line
	acp    string   // the ACP recording's file name in a scenario
	env    []string // more environment for the agent (tests')
	tmp    string   // where runs' scratch folders go; "" is the temp folder
	// mcpEcho is claudetest's mcp-echo, built: a scenario's "$mcp-echo"
	// is a copy of it in the run's folder. "" leaves "$mcp-echo" as it is.
	mcpEcho string
	log     *slog.Logger
}

// record records the scenario in dir, and puts its recordings there
// (cli.jsonl, cli-2.jsonl… and the ACP one) in place of the old ones
// only when it all went as the scenario says. A failed run's folder is
// kept, and the error names it.
func (r *recorder) record(ctx context.Context, dir string) error {
	script, err := fakeapi.Load(dir)
	if err != nil {
		return err
	}
	client, timeout, err := loadClient(dir)
	if err != nil {
		return err
	}
	scratch, err := os.MkdirTemp(r.tmp, "claude-record-")
	if err != nil {
		return err
	}
	if scratch, err = filepath.EvalSymlinks(scratch); err != nil { // the path claude sees
		return err
	}
	defer removeTaskFiles(filepath.Join(scratch, "work"))
	if err := r.run(ctx, scratch, script, client, timeout); err != nil {
		return fmt.Errorf("%w (its run is kept in %s)", err, scratch)
	}
	if err := keep(filepath.Join(scratch, "out"), dir, r.acp); err != nil {
		return err
	}
	return os.RemoveAll(scratch)
}

// run plays client against the agent in scratch, writing the
// recordings to scratch/out.
func (r *recorder) run(ctx context.Context, scratch string, script *fakeapi.Script, client *clientScript, timeout time.Duration) error {
	dirs := map[string]string{}
	for _, d := range []string{"home", "config", "tmp", "work", "out", "bin"} {
		dirs[d] = filepath.Join(scratch, d)
		if err := os.Mkdir(dirs[d], 0o700); err != nil {
			return err
		}
	}
	var mcpEcho string // a copy in the run's folder, so the recordings name no folder of the caller's
	if r.mcpEcho != "" {
		mcpEcho = filepath.Join(dirs["bin"], "mcp-echo")
		b, err := os.ReadFile(r.mcpEcho)
		if err != nil {
			return err
		}
		if err := os.WriteFile(mcpEcho, b, 0o700); err != nil {
			return err
		}
	}
	apiLog, err := os.Create(filepath.Join(scratch, "fakeapi.log"))
	if err != nil {
		return err
	}
	defer apiLog.Close() //nolint:errcheck // a log
	api := fakeapi.New(script, slog.New(slog.NewTextHandler(apiLog, nil)))
	url, stop, err := api.Start(ctx, "127.0.0.1:0")
	if err != nil {
		return err
	}
	defer stop() //nolint:errcheck // the run is over
	agentLog, err := os.Create(filepath.Join(scratch, "agent.log"))
	if err != nil {
		return err
	}
	defer agentLog.Close() //nolint:errcheck // a log
	acpRec, err := os.Create(filepath.Join(dirs["out"], r.acp))
	if err != nil {
		return err
	}
	defer acpRec.Close() //nolint:errcheck // written a line at a time

	cmd := exec.Command(r.agent[0], r.agent[1:]...) //nolint:noctx // the agent the caller names; stopped below, group and all
	cmd.Dir, cmd.Stderr = scratch, agentLog
	cmd.Env = append(r.environ(dirs, url), r.env...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true} // so claude goes with it
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start the agent: %w", err)
	}
	c := newConn(stdin, stdout, acpRec)
	p := &player{c: c, cwd: dirs["work"], timeout: timeout, ids: map[string]string{}, vars: map[string]string{}, async: map[string]<-chan msg{}}
	if mcpEcho != "" {
		p.vars["mcp-echo"] = mcpEcho
	}
	projects := filepath.Join(dirs["config"], "projects")
	snapshots := 0
	p.snapshot = func() error {
		snapshots++
		return history(projects, filepath.Join(dirs["out"], "history", strconv.Itoa(snapshots)))
	}
	p.kill = func(ctx context.Context, text string) error { return stopBelow(ctx, cmd.Process.Pid, text, timeout) }
	played := p.play(ctx, client.Steps)
	_ = stdin.Close() // the client goes, as Nushi's daemon does at Sleep
	stopped := r.stop(ctx, c, cmd)
	if err := history(projects, filepath.Join(dirs["out"], "history", "end")); err != nil {
		stopped = errors.Join(stopped, err)
	}
	var problems []string
	for _, m := range api.Misses() {
		problems = append(problems, "no turn of api.json matched a request for "+m.Model)
	}
	if n := api.Left(); n > 0 {
		problems = append(problems, fmt.Sprintf("%d turns of api.json were never asked for", n))
	}
	if cassettes, _ := filepath.Glob(filepath.Join(dirs["out"], "cli*.jsonl")); len(cassettes) == 0 {
		problems = append(problems, "claude never ran through claude-tee")
	}
	if len(problems) > 0 {
		played = errors.Join(played, errors.New(strings.Join(problems, "; ")))
	}
	return errors.Join(played, stopped)
}

// environ is the agent's environment: none of the caller's but PATH (for
// node), throwaway folders, the fake API with a dummy key, claude-tee as
// claude, and the CLI's calls home off.
func (r *recorder) environ(dirs map[string]string, url string) []string {
	return []string{
		"PATH=" + os.Getenv("PATH"),
		"HOME=" + dirs["home"],
		"CLAUDE_CONFIG_DIR=" + dirs["config"],
		"TMPDIR=" + dirs["tmp"],
		"LANG=en_US.UTF-8",
		"ANTHROPIC_BASE_URL=" + url,
		"ANTHROPIC_API_KEY=fakeapi-dummy-key",
		"CLAUDE_CODE_EXECUTABLE=" + r.tee,
		"CLAUDE_TEE_REAL=" + r.claude,
		"CLAUDE_TEE_OUT=" + filepath.Join(dirs["out"], "cli.jsonl"),
		"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1",
		"DISABLE_AUTOUPDATER=1",
		"DISABLE_TELEMETRY=1",
		"DISABLE_ERROR_REPORTING=1",
	}
}

// stop waits for the agent to end after its stdin closed, as it should,
// and then for the rest of its process group (claude, which may still be
// writing its transcript as it exits), so the run's history is complete
// and no claude outlives the run. Whatever of the group is left after
// groupGrace is ended (SIGTERM, then SIGKILL). It says whether the agent
// had to be stopped. When ctx is done (the recorder interrupted) it
// doesn't wait, and the run fails: its recordings are cut short.
func (r *recorder) stop(ctx context.Context, c *conn, cmd *exec.Cmd) error {
	pgid := cmd.Process.Pid
	exited := make(chan struct{}) // the agent is reaped: its group holds only the rest
	go func() {
		<-c.done
		_ = cmd.Wait() // its exit after a SIGTERM isn't the scenario's business
		close(exited)
	}()
	var err error
	select {
	case <-exited:
	case <-ctx.Done():
		err = ctx.Err()
	case <-time.After(10 * time.Second):
		err = errors.New("the agent didn't end when its stdin closed")
	}
	if err == nil && groupGone(ctx, pgid, groupGrace) {
		return nil
	}
	ending := context.WithoutCancel(ctx)     // the group is ended even when interrupted; each wait is bounded
	_ = syscall.Kill(-pgid, syscall.SIGTERM) // what is left of its group: claude, if the agent left it
	if !groupGone(ending, pgid, 5*time.Second) {
		_ = syscall.Kill(-pgid, syscall.SIGKILL)
	}
	<-exited
	if !groupGone(ending, pgid, 5*time.Second) {
		err = errors.Join(err, errors.New("a process of the agent's group outlived SIGKILL"))
	}
	return err
}

// groupGrace is how long the agent's group has to end by itself after
// the agent did: claude ends on its stdin's end, its transcript written.
const groupGrace = 15 * time.Second

// groupGone waits up to d, or until ctx is done, for process group pgid
// to have no process left, and says whether it has none.
func groupGone(ctx context.Context, pgid int, d time.Duration) bool {
	deadline := time.Now().Add(d)
	for {
		if err := syscall.Kill(-pgid, 0); errors.Is(err, syscall.ESRCH) {
			return true
		}
		if time.Now().After(deadline) {
			return false
		}
		t := time.NewTimer(50 * time.Millisecond) // a process's exit: nothing says when, in another's group
		select {
		case <-t.C:
		case <-ctx.Done():
			t.Stop()
			return false
		}
	}
}

// stopBelow stops the process group below the agent (pid root) whose
// command line has text, as Nushi stops a background command (ADR 0065),
// waiting up to timeout for it to start.
func stopBelow(ctx context.Context, root int, text string, timeout time.Duration) error {
	var tree proctree.Tree
	deadline := time.Now().Add(timeout)
	for {
		procs, err := tree.Under(root)
		if err != nil {
			return err
		}
		for _, p := range procs {
			if p.Pgid == p.Pid && strings.Contains(strings.Join(p.Args, " "), text) {
				return tree.StopGroup(root, p)
			}
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("no process group below the agent runs %q", text)
		}
		t := time.NewTimer(100 * time.Millisecond) // another program's start: nothing says when
		select {
		case <-t.C:
		case <-ctx.Done():
			t.Stop()
			return ctx.Err()
		}
	}
}

// keep puts the recordings in out into dir, in place of the old ones:
// the cassettes, the ACP recording and claude's history.
func keep(out, dir, acpName string) error {
	old, _ := filepath.Glob(filepath.Join(dir, "cli*.jsonl"))
	for _, f := range append(old, filepath.Join(dir, acpName)) {
		if err := os.Remove(f); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	if err := os.RemoveAll(filepath.Join(dir, "history")); err != nil {
		return err
	}
	if err := os.CopyFS(filepath.Join(dir, "history"), os.DirFS(filepath.Join(out, "history"))); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	files, err := filepath.Glob(filepath.Join(out, "*.jsonl"))
	if err != nil {
		return err
	}
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			return err
		}
		if err := os.WriteFile(filepath.Join(dir, filepath.Base(f)), b, 0o644); err != nil {
			return err
		}
	}
	return nil
}

// removeTaskFiles removes what claude keeps of a run outside its
// throwaway folders: background tasks' output, under
// /tmp/claude-<uid>/<the work folder's project name>, whatever TMPDIR
// says. Left there, it outlives the run, and Nushi, which reads a
// background command's output from that file, would read it in a later
// parity test on this machine.
func removeTaskFiles(work string) {
	name := filepath.Base(sessions.Store{}.ProjectDir(work))
	if !strings.Contains(name, "claude-record-") { // only a run's own folder
		return
	}
	_ = os.RemoveAll(filepath.Join("/tmp/claude-"+strconv.Itoa(os.Getuid()), name))
}
