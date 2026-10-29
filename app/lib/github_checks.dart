import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
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

/// A pull request's checks: what they came to (failing, passed, skipped)
/// with Re-run failed (the failed Actions jobs' runs, when the daemon can)
/// and Fix checks (each failed check's reply card in the chat's box); the
/// failed first, each a box that opens to its annotations and its log's
/// end (an Actions job's, asked of GitHub when opened), then those
/// running, then the passed in two columns (twelve, then Show the rest),
/// then the skipped. [onChanged] asks for the pull request again.
class GitHubChecks extends StatefulWidget {
  const new({
    required this.daemon,
    required this.pull,
    super.key,
    this.onChanged,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final Future<void> Function()? onChanged;

  @override
  State<GitHubChecks> createState() => _GitHubChecksState();
}

class _GitHubChecksState extends State<GitHubChecks> {
  bool _all = false;
  bool _rerunning = false;

  Future<void> _rerun(List<GitHubCheck> failed) async {
    setState(() => _rerunning = true);
    await tryOrShow(context, () async {
      final r = await widget.daemon.client.rerunGitHubChecks(
        RerunGitHubChecksRequest(
          ref: widget.pull.item.ref,
          jobs: [for (final c in failed) c.id],
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            r.runs == 1
                ? 'Re-running the failed jobs of 1 workflow run'
                : 'Re-running the failed jobs of ${r.runs} workflow runs',
          ),
        ),
      );
      await widget.onChanged?.call();
    });
    if (mounted) setState(() => _rerunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = widget.pull;
    final failed = [
      for (final c in p.checks)
        if (c.failed) c,
    ]..sort((a, b) => (b.required ? 1 : 0) - (a.required ? 1 : 0));
    final running = [
      for (final c in p.checks)
        if (c.state == 'pending') c,
    ];
    final passed = [
      for (final c in p.checks)
        if (c.state == 'success') c,
    ];
    final other = [
      for (final c in p.checks)
        if (!c.failed && c.state != 'pending' && c.state != 'success') c,
    ];
    if (p.checks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('No checks.', style: theme.ui(t.textMuted)),
      );
    }
    final jobs = failed.where((c) => c.id != 0).toList();
    Widget group(String name) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Text(
        name,
        style: theme.ui(t.textSecondary, size: 12, weight: FontWeight.w600),
      ),
    );
    final shown = _all || passed.length <= 14 ? passed : passed.take(12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (final (i, (n, words, color)) in [
                        (failed.length, 'failing', t.crashed),
                        (running.length, 'running', t.needs),
                        (passed.length, 'passed', t.done),
                        (other.length, 'skipped', t.textMuted),
                      ].where((x) => x.$1 > 0).indexed) ...[
                        if (i > 0)
                          TextSpan(text: '  ·  ', style: theme.ui(t.textMuted)),
                        TextSpan(
                          text: '$n $words',
                          style: theme.ui(
                            color,
                            weight: words == 'failing' ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (jobs.isNotEmpty && widget.daemon.daemonApi >= rerunApi) ...[
                Button(
                  label: _rerunning ? 'Re-running…' : 'Re-run failed',
                  icon: Icons.sync,
                  tooltip:
                      "Re-run the failed jobs of these checks' workflow runs "
                      'on GitHub',
                  onPressed: _rerunning ? null : () => _rerun(jobs),
                ),
                const SizedBox(width: 6),
              ],
              if (failed.isNotEmpty)
                SendButton(
                  label: 'Fix checks',
                  tooltip:
                      "Each failed check as a reply card in the chat's box, "
                      'to send',
                  onPressed: () => toAgent(
                    context,
                    widget.daemon,
                    p.item,
                    replies: () => checkReplies(widget.daemon, p.item.ref, p),
                  ),
                ),
            ],
          ),
        ),
        for (final c in [...failed, ...running])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: framed(
              border: c.failed
                  ? t.crashed.withValues(alpha: 0.35)
                  : t.borderSubtle,
              child: _Check(daemon: widget.daemon, ref: p.item.ref, check: c),
            ),
          ),
        if (passed.isNotEmpty) ...[
          group('Passed · ${passed.length}'),
          _Grid([for (final c in shown) _Mini(c)]),
          if (shown.length < passed.length)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: LinkText(
                'Show ${passed.length - shown.length} more',
                size: 12,
                onTap: () => setState(() => _all = true),
              ),
            ),
        ],
        if (other.isNotEmpty) ...[
          group('Skipped · ${other.length}'),
          _Grid([for (final c in other) _Mini(c)]),
        ],
      ],
    );
  }
}

/// [children] in two columns (one when narrow).
class _Grid extends StatelessWidget {
  const new(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final two = box.maxWidth >= 480;
      final w = two ? (box.maxWidth - 16) / 2 : box.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 2,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}

/// A check that passed or was skipped, on one line: its icon and name; a
/// click opens its page.
class _Mini extends StatelessWidget {
  const new(this.check);

  final GitHubCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = check;
    final (icon, color) = checkIcon(t, c);
    return Tap(
      onTap: c.url.isEmpty ? null : () => openWeb(c.url),
      tooltip: c.url.isEmpty ? '' : 'Open on GitHub',
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              c.workflow.isEmpty ? c.name : '${c.workflow} / ${c.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(
                c.state == 'success' ? t.textSecondary : t.textMuted,
                size: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                SendIcon(() => checkReply(widget.daemon, widget.ref, c)),
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
