import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_check_row.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/pull_segment_lists.dart' show NoneLine;
import 'package:nushi/pull_segments.dart' show quietSend;
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// How a check went, as GitHub words it: "Failing after 2m 14s",
/// "Successful in 1m 12s", "Cancelled after 30m", "In progress",
/// "Skipped".
String checkWords(GitHubCheck c) {
  final took = checkTook(c);
  return switch (c.state) {
    'success' => took.isEmpty ? 'Successful' : 'Successful in $took',
    'pending' => 'In progress',
    'skipped' => 'Skipped',
    'cancelled' => took.isEmpty ? 'Cancelled' : 'Cancelled after $took',
    'neutral' => 'Neutral',
    'stale' => 'Stale',
    'timed_out' => took.isEmpty ? 'Timed out' : 'Timed out after $took',
    _ when c.kind == CheckKind.failed =>
      took.isEmpty ? 'Failing' : 'Failing after $took',
    final s => s,
  };
}

/// Which jobs a re-run of [picked] takes, in words: "failed",
/// "cancelled" or "failed and cancelled" (a cancelled check is never
/// called failed).
String rerunWhat(List<GitHubCheck> picked) {
  final failed = picked.any((c) => c.kind == CheckKind.failed);
  final cancelled = picked.any((c) => c.kind == CheckKind.cancelled);
  return failed && cancelled
      ? 'failed and cancelled'
      : cancelled
      ? 'cancelled'
      : 'failed';
}

/// What a re-run of [picked] says once GitHub took it, over [runs]
/// workflow runs.
String rerunWords(List<GitHubCheck> picked, int runs) =>
    'Re-running the ${rerunWhat(picked)} jobs of $runs workflow '
    'run${runs == 1 ? '' : 's'}';

/// The Checks segment's list: every check, failing first, then the
/// cancelled, each its state, name and how it went; a failing one's Send
/// to agent (a cancelled one isn't a failure to fix); a ⋯ of its log,
/// Re-run (a failed or cancelled Actions job's run) and Open on GitHub.
class ChecksList extends StatelessWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.onChanged,
    required this.narrow,
    super.key,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final Future<void> Function() onChanged;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final s = splitChecks(pull);
    final all = [
      ...s.failed,
      ...s.cancelled,
      ...s.running,
      ...s.passed,
      ...s.other,
    ];
    if (all.isEmpty) return const NoneLine('No checks');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in all.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(height: 1, thickness: 1, color: t.line),
            ),
          _CheckLine(
            key: ValueKey(c.id != 0 ? c.id : '${c.workflow}/${c.name}'),
            daemon: daemon,
            pull: pull,
            check: c,
            narrow: narrow,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

class _CheckLine extends StatefulWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.check,
    required this.narrow,
    required this.onChanged,
    super.key,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final GitHubCheck check;
  final bool narrow;
  final Future<void> Function() onChanged;

  @override
  State<_CheckLine> createState() => _CheckLineState();
}

class _CheckLineState extends State<_CheckLine> {
  bool _log = false;

  Future<void> _rerun() => tryOrShow(context, () async {
    final r = await widget.daemon.client.rerunGitHubChecks(
      RerunGitHubChecksRequest(
        ref: widget.pull.item.ref,
        jobs: [widget.check.id],
      ),
    );
    if (!mounted) return;
    showToast(Toasts.maybeOf(context), rerunWords([widget.check], r.runs));
    await widget.onChanged();
  });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = widget.check;
    final (icon, ink) = checkIcon(t, c);
    final name = c.workflow.isEmpty ? c.name : '${c.workflow} / ${c.name}';
    final failed = c.kind == CheckKind.failed;
    final cancelled = c.kind == CheckKind.cancelled;
    // A cancelled one holds the merge back until it runs again.
    final rerun = (failed || cancelled) && c.id != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
          child: SizedBox(
            height: 30,
            child: Row(
              children: [
                CheckMark(icon, size: 16, color: ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: name,
                          style: theme.ui(t.text, weight: FontWeight.w500),
                        ),
                        TextSpan(
                          text:
                              '  ${checkWords(c)}'
                              '${c.required ? ' · Required' : ''}',
                          style: theme.ui(
                            failed
                                ? t.crashed
                                : cancelled
                                ? t.textSecondary
                                : t.textMuted,
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (failed)
                  ControlScale.compact(
                    child: quietSend(
                      context,
                      narrow: widget.narrow,
                      onPressed: () => toAgent(
                        context,
                        widget.daemon,
                        widget.pull.item,
                        what: name,
                        replies: () async => [
                          await checkReply(
                            widget.daemon,
                            widget.pull.item.ref,
                            c,
                          ),
                        ],
                      ),
                    ),
                  ),
                MenuIcon(
                  Icons.more_horiz,
                  tooltip: 'More',
                  entries: [
                    if (c.id != 0)
                      MenuEntry(
                        _log ? 'Hide the log' : 'Show the log',
                        onPick: () => setState(() => _log = !_log),
                      ),
                    if (rerun) MenuEntry('Re-run', onPick: _rerun),
                    MenuEntry(
                      'Open on GitHub',
                      onPick: c.url.isEmpty
                          ? null
                          : () => openWeb(context, c.url),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_log)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final a in c.annotations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${a.path}:${a.line}  ${a.message}',
                      style: theme.code(
                        a.level == 'failure' ? t.crashed : t.needs,
                        size: 11.5,
                      ),
                    ),
                  ),
                JobLog(
                  daemon: widget.daemon,
                  ref: widget.pull.item.ref,
                  check: c,
                  maxHeight: 260,
                  failing: failed,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
