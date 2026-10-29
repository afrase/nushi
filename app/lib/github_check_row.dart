import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/send_to_agent.dart';
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

/// How long a check took ("4m 12s"), or '' when it hasn't ended.
String checkTook(GitHubCheck c) {
  final from = c.startedMs.toInt();
  final to = c.completedMs.toInt();
  if (from <= 0 || to < from) return '';
  final s = (to - from) ~/ 1000;
  return s < 60
      ? '${s}s'
      : '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
}

/// A failed or running check: its state, workflow and name, whether it's
/// required, how long it took, Send to agent and its link; open, its
/// annotations and its log's end (an Actions job's, asked of GitHub).
class CheckRow extends StatefulWidget {
  const new({
    required this.daemon,
    required this.ref,
    required this.check,
    super.key,
  });

  final Daemon daemon;
  final GitHubRef ref;
  final GitHubCheck check;

  @override
  State<CheckRow> createState() => _CheckRowState();
}

class _CheckRowState extends State<CheckRow> {
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
      if (mounted) setState(() => _error = errorText(e));
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
              if (checkTook(c) case final took when took.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(took, style: theme.ui(t.textMuted, size: 11.5)),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(c.state, style: theme.ui(color, size: 11.5)),
              ),
              if (c.failed)
                SendIcon(
                  () => checkReply(widget.daemon, widget.ref, c),
                  what: c.workflow.isEmpty
                      ? c.name
                      : '${c.workflow} / ${c.name}',
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
