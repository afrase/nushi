import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/workflows.dart';

/// A workflow card opened in place (#103): its description, then each
/// phase reached, a line each, with its mark, its title and progress, and
/// the labels of its agents running now (cut, never how many more run);
/// then the phases it plans and hasn't reached, each with an empty ring,
/// its title dimmed and "planned" (ADR 0141). All of it from the run's
/// summary on its item, so the phone shows it too; the Workflow pane keeps
/// the whole tree.
class WorkflowPhases extends StatelessWidget {
  const new(this.w, {super.key, this.still = false});

  final Workflow w;

  /// No shine (a golden, a waiting chat).
  final bool still;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final rows = workflowPhaseRows(w);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (w.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              w.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.textSecondary, size: 12),
            ),
          ),
        for (final r in rows) _PhaseLine(r, live: workflowLive(w) && !still),
        if (rows.isEmpty)
          Text('No phases yet', style: theme.ui(t.textMuted, size: 12)),
      ],
    );
  }
}

/// A phase as the opened card shows it: its title ('' for the agents in
/// none), its progress ("4/7", '' for those in none), its state for its
/// mark, the labels of its agents running, and how many more run.
typedef PhaseRow = ({
  String title,
  String progress,
  String state,
  List<String> running,
  int more,
});

/// The opened card's lines: each phase reached, in order, then the
/// running agents in no phase, if any. A phase whose agents all ended is
/// done, or failed when one failed; one with agents still going runs
/// while the run does, else stopped with it.
List<PhaseRow> workflowPhaseRows(Workflow w) {
  final live = workflowLive(w);
  final labels = <int, List<String>>{};
  for (var i = 0; i < w.running.length; i++) {
    final at = i < w.runningPhases.length ? w.runningPhases[i] : -1;
    (labels[at < w.phases.length ? at : -1] ??= []).add(w.running[i]);
  }
  final rows = <PhaseRow>[];
  for (final (i, p) in w.phases.indexed) {
    if (p.started == 0) {
      rows.add(_planned(p, live: live)); // the snapshot's, never reached
      continue;
    }
    final ended = p.done + p.failed;
    final going = math.max(0, p.started - ended);
    final shown = live ? labels[i] ?? const <String>[] : const <String>[];
    rows.add((
      title: p.title,
      progress: phaseCount(p),
      state: switch ((going, p.failed)) {
        (0, 0) => 'done',
        (0, _) => 'failed',
        _ when live => 'running',
        _ => 'stopped',
      },
      running: shown,
      more: live ? math.max(0, going - shown.length) : 0,
    ));
  }
  final none = labels[-1];
  if (live && none != null) {
    // Those in no phase: how many run beyond the labels isn't known by
    // phase, so only what's left of the run's count once the phases' own
    // are taken.
    final inPhases = rows.fold(0, (n, r) => n + r.running.length + r.more);
    rows.add((
      title: '',
      progress: '',
      state: 'running',
      running: none,
      more: math.max(0, w.runningCount - inPhases - none.length),
    ));
  }
  // Then what it plans and hasn't reached, in the script's order.
  return rows..addAll([for (final p in w.planned) _planned(p, live: live)]);
}

/// A phase the run plans and hasn't reached (ADR 0141): "planned" while
/// it runs, "not reached" once it ended.
PhaseRow _planned(WorkflowPhase p, {required bool live}) => (
  title: p.title,
  progress: plannedWords(live: live),
  state: 'planned',
  running: const [],
  more: 0,
);

/// One phase's line: its mark (the running dot while its agents run, as
/// the pane's rows), "Review 4/7", then who runs, muted, cut before a
/// "+3" that stays whole.
class _PhaseLine extends StatelessWidget {
  const new(this.r, {required this.live});

  final PhaseRow r;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    final running = r.state == 'running';
    final planned = r.state == 'planned';
    final title = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: r.title.isEmpty ? 'No phase' : r.title,
            style: theme.ui(
              switch (r.state) {
                'failed' => t.crashed,
                'planned' => t.textSecondary,
                _ => t.text,
              },
              size: 12,
              weight: planned ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
          if (r.progress.isNotEmpty)
            TextSpan(
              text: ' ${r.progress}',
              style: planned ? muted : theme.ui(t.textSecondary, size: 12),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return SizedBox(
      height: 24,
      child: Row(
        spacing: 8,
        children: [
          SizedBox(
            width: TaskMark.size,
            child: Center(
              // One TaskMark, so its check draws itself as the phase ends.
              child: TaskMark(r.state, dot: running),
            ),
          ),
          // The title is cut only past half the line; who runs takes the
          // rest, cut, before its count of more.
          Flexible(child: title),
          if (r.running.isNotEmpty || r.more > 0)
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Shine(
                      on: live,
                      child: Text(
                        r.running.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ),
                  ),
                  if (r.more > 0)
                    Text(
                      r.running.isEmpty ? '${r.more} running' : ' +${r.more}',
                      maxLines: 1,
                      style: muted,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
