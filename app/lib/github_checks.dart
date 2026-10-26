import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A check's state as an icon and its color.
(IconData, Color) checkIcon(Tokens t, GitHubCheck c) => switch (c.state) {
  'success' => (Icons.check_circle_outline, t.done),
  'pending' => (Icons.schedule, t.needs),
  'skipped' ||
  'neutral' ||
  'cancelled' ||
  'stale' => (Icons.remove_circle_outline, t.textMuted),
  _ when c.failed => (Icons.cancel_outlined, t.crashed),
  _ => (Icons.help_outline, t.textMuted),
};

/// A pull request's checks: the failed first, then those running, then
/// the rest; each with its state, workflow and name, whether it's
/// required, its link; a failed one's annotations, and its log's end
/// (an Actions job's, asked of GitHub when opened).
class GitHubChecks extends StatelessWidget {
  const new({required this.daemon, required this.pull, super.key});

  final Daemon daemon;
  final GitHubPull pull;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    int rank(GitHubCheck c) => c.failed
        ? 0
        : c.state == 'pending'
        ? 1
        : 2;
    final checks = [...pull.checks]..sort((a, b) => rank(a).compareTo(rank(b)));
    if (checks.isEmpty) {
      return Center(child: Text('No checks.', style: theme.ui(t.textMuted)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      children: [
        for (final c in checks)
          _Check(daemon: daemon, ref: pull.item.ref, check: c),
      ],
    );
  }
}

class _Check extends StatefulWidget {
  const new({required this.daemon, required this.ref, required this.check});

  final Daemon daemon;
  final GitHubRef ref;
  final GitHubCheck check;

  @override
  State<_Check> createState() => _CheckState();
}

class _CheckState extends State<_Check> {
  bool _open = false;
  String? _log;
  String? _error;

  Future<void> _toggle() async {
    setState(() => _open = !_open);
    if (!_open || _log != null || widget.check.id == 0) return;
    try {
      final r = await widget.daemon.client.getGitHubJobLog(
        GetGitHubJobLogRequest(ref: widget.ref, job: widget.check.id),
      );
      if (mounted) setState(() => _log = r.tail);
    } on Object catch (e) {
      if (mounted) setState(() => _error = githubError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = widget.check;
    final (icon, color) = checkIcon(t, c);
    final more =
        c.failed &&
        (c.id != 0 || c.annotations.isNotEmpty || c.summary.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tap(
          onTap: more ? _toggle : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              if (more)
                Icon(
                  _open ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: t.textMuted,
                )
              else
                const SizedBox(width: 14),
              const SizedBox(width: 4),
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (c.workflow.isNotEmpty)
                        TextSpan(
                          text: '${c.workflow} / ',
                          style: theme.ui(t.textMuted, size: 12.5),
                        ),
                      TextSpan(text: c.name),
                      if (c.title.isNotEmpty)
                        TextSpan(
                          text: '  ${c.title}',
                          style: theme.ui(t.textMuted, size: 12),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text, size: 12.5),
                ),
              ),
              if (c.required)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'Required',
                    style: theme.ui(t.textMuted, size: 11.5),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(c.state, style: theme.ui(color, size: 11.5)),
              ),
              IconTap(
                Icons.open_in_new,
                size: 13,
                tooltip: 'Open on GitHub',
                onTap: c.url.isEmpty ? null : () => openWeb(c.url),
              ),
            ],
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 2, 8, 10),
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
                if (_error case final e?)
                  Text(e, style: theme.ui(t.crashed, size: 12))
                else if (c.id != 0 && _log == null)
                  Text(
                    'Loading the log…',
                    style: theme.ui(t.textMuted, size: 12),
                  )
                else if (_log case final log?)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    padding: const EdgeInsets.all(8),
                    decoration: box(t.borderSubtle, fill: t.codeBlock),
                    child: SingleChildScrollView(
                      reverse: true, // the end is what matters
                      child: SelectableText(
                        log.isEmpty ? '(an empty log)' : log,
                        style: theme.code(t.text, size: 11.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
