import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_filters.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Review requested's choice: "Only me" (pull requests asking me by
/// name) or "Me and my teams" (a team of mine asked too).
class Whose extends StatelessWidget {
  const new({required this.onPick, super.key});

  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    final teams = githubTeamReviews.value;
    return MenuField(
      compact: true,
      entries: [
        MenuEntry('Only me', checked: !teams, onPick: () => onPick(false)),
        MenuEntry(
          'Me and my teams',
          checked: teams,
          onPick: () => onPick(true),
        ),
      ],
      label: Text(teams ? 'Me and my teams' : 'Only me'),
    );
  }
}

/// The view's bar: the host shown (a menu of the others), which
/// repositories (all, the known folders', some owners'; those hidden),
/// the span of time, Refresh, Close.
class GitHubBar extends StatelessWidget {
  const new({
    required this.hosts,
    required this.host,
    required this.known,
    required this.knownRepos,
    required this.owners,
    required this.hidden,
    required this.seen,
    required this.onOwners,
    required this.onHidden,
    required this.onDays,
    required this.loading,
    required this.onHost,
    required this.onKnown,
    required this.onRefresh,
    required this.onClose,
    super.key,
    this.updated,
    this.now,
  });

  final List<GitHubHost> hosts;
  final GitHubHost? host;
  final bool known;
  final int knownRepos;
  final List<String> owners;
  final List<String> hidden;
  final List<String> seen;
  final ValueChanged<List<String>> onOwners;
  final ValueChanged<List<String>> onHidden;
  final ValueChanged<int> onDays;
  final bool loading;
  final DateTime? updated;
  final DateTime? now;
  final ValueChanged<String> onHost;
  final ValueChanged<bool> onKnown;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final h = host;
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          Text('GitHub', style: theme.ui(t.text, weight: FontWeight.w600)),
          const SizedBox(width: 12),
          if (hosts.length > 1)
            MenuField(
              compact: true,
              entries: [
                for (final x in hosts)
                  MenuEntry(
                    x.host,
                    detail: x.login,
                    checked: x.host == h?.host,
                    onPick: () => onHost(x.host),
                  ),
              ],
              label: Text(h?.host ?? ''),
            )
          else if (h != null)
            Flexible(
              child: Text(
                [h.host, if (h.login.isNotEmpty) h.login].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          const SizedBox(width: 12),
          if (h != null) ...[
            Flexible(
              child: ReposMenu(
                known: known,
                knownRepos: knownRepos,
                owners: owners,
                hidden: hidden,
                seen: seen,
                onKnown: onKnown,
                onOwners: onOwners,
                onHidden: onHidden,
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder(
              valueListenable: githubDays,
              builder: (context, days, _) =>
                  UpdatedMenu(days: days, onPick: onDays),
            ),
          ],
          const Spacer(),
          if (updatedLine(updated, loading: loading, now: now) case final line?)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(line, style: theme.ui(t.textMuted, size: 12)),
            ),
          IconTap(Icons.refresh, tooltip: 'Refresh (⌘R)', onTap: onRefresh),
          IconTap(Icons.close, tooltip: 'Close (⌘G)', onTap: onClose),
        ],
      ),
    );
  }
}
