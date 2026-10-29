import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_check_row.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

export 'package:nushi/github_check_row.dart' show checkIcon, checkTook;

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
              child: CheckRow(daemon: widget.daemon, ref: p.item.ref, check: c),
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
