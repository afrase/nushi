import 'package:nushi/clock.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/status.dart';

// A workflow: a run a tool call launched (Claude's Workflow), many
// subagents in phases, followed by the daemon from the agent's files
// (ADR 0127). Item.workflow is its summary; GetWorkflow its agents.

/// Whether [it] launched a workflow the daemon follows: it shows as a
/// workflow's card. One it doesn't (no files found, an older daemon) is a
/// plain call.
bool isWorkflow(Item it) =>
    it.kind == ItemKind.ITEM_KIND_TOOL_CALL &&
    it.hasWorkflow() &&
    it.workflow.state.isNotEmpty;

/// The workflows among [items], in order.
List<Item> workflowsOf(List<Item> items) => items.where(isWorkflow).toList();

/// Whether the workflow runs, stalled or not: it can be stopped. Whether
/// it counts as the chat's work adds that it isn't stalled (the daemon's
/// Workflow.Runs).
bool workflowLive(Workflow w) => w.state == 'running';

/// The phase it's in now: the last one reached that hasn't ended, else
/// the last reached; null when it reached none. One with no agent started
/// (the snapshot's list, at the end) isn't reached.
WorkflowPhase? currentPhase(Workflow w) {
  final reached = w.phases.where((p) => p.started > 0);
  for (final p in reached.toList().reversed) {
    if (p.done + p.failed < p.started) return p;
  }
  return reached.lastOrNull;
}

/// What a phase not reached says where a reached one has its count (ADR
/// 0141): "planned" while the run goes, "not reached" once it ended.
String plannedWords({required bool live}) => live ? 'planned' : 'not reached';

/// A phase's count, "5/7": its agents that ended, done or failed, of
/// those started. The card's rows, its state line and the pane all say it
/// so.
String phaseCount(WorkflowPhase p) => '${p.done + p.failed}/${p.started}';

/// A phase's progress: "Review 5/7" (its agents ended of those started).
String phaseProgress(WorkflowPhase p) => '${p.title} ${phaseCount(p)}';

/// Its state line, in a subagent row's order (#103, #106): while it runs
/// "Review 5/7, 3 running, 412k tokens, 4m 12s"; at its end "100
/// agents, 1.2M tokens, 14m 05s" (done says no word: its check does;
/// "failed", "stopped", "ended" when the agent didn't say how); stalled
/// "no activity for 1h, Review 5/7, 3 running, 412k tokens", without
/// its time, which no longer ticks and would be cut first where the line
/// is short (a phone's). Its tokens show once the daemon read some (API
/// 132); no cost, which the agent doesn't report for a workflow. Without
/// [count] its count of agents goes, without [tokens] its tokens.
String workflowState(Workflow w, {bool count = true, bool tokens = true}) {
  final time = ranFor(
    w.started.toInt(),
    w.ended.toInt(),
    runs: workflowLive(w),
  );
  final agents = '${w.agents} agent${w.agents == 1 ? '' : 's'}';
  final used = tokens && w.tokens > 0 ? tokenCount(w.tokens.toInt()) : null;
  if (workflowLive(w)) {
    final phase = currentPhase(w);
    return [
      if (w.stalled) 'no activity for ${_quiet(w)}',
      if (phase != null) phaseProgress(phase),
      if (w.runningCount > 0 && count) '${w.runningCount} running',
      if (phase == null && w.runningCount == 0) 'starting',
      ?used,
      if (time.isNotEmpty && !w.stalled) time,
    ].join(', ');
  }
  return [
    ?switch (w.state) {
      'done' => null,
      'failed' => 'failed',
      'stopped' => 'stopped',
      _ => 'ended',
    },
    if (w.agents > 0 && count) agents,
    ?used,
    if (time.isNotEmpty) time,
  ].join(', ');
}

/// Its state for a short line, the fullest first: [workflowState], then
/// without its count of agents, then without its tokens too, so where it
/// is and how long stay whole (a phone's card takes the first that fits).
List<String> workflowStates(Workflow w) => {
  workflowState(w),
  workflowState(w, count: false),
  workflowState(w, count: false, tokens: false),
}.toList();

/// How long its files have been still, roughly: "1h", "2h".
String _quiet(Workflow w) {
  final active = msTime(w.active.toInt());
  if (active == null) return '1h';
  final h = clock().difference(active).inHours;
  return '${h < 1 ? 1 : h}h';
}

/// What it says when it ended otherwise than done: the agent's own word
/// (the agent's title is [agent]), or the reason a failed run gave.
String workflowEndWords(Workflow w, String agent) => switch (w.state) {
  'unknown' => w.end.isEmpty ? "$agent didn't say how it ended" : w.end,
  'failed' when w.summary.isNotEmpty => w.summary,
  'stopped' when w.end.isNotEmpty && w.end != 'killed' => w.end,
  _ => '',
};
