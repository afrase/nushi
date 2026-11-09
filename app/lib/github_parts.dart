import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_views.dart' show openInDefaultBrowser;
import 'package:nushi/widgets.dart';

export 'package:nushi/markdown.dart' show openWeb;
export 'package:nushi/pull_states.dart' show checksIcon, itemColor, itemState;

/// A review decision in words, and its color.
(String, Color)? reviewWords(Tokens t, String review) => switch (review) {
  'approved' => ('Approved', t.done),
  'changes_requested' => ('Changes requested', t.crashed),
  'review_required' => ('Review required', t.textMuted),
  _ => null,
};

/// The chats on a GitHub item (started from it, or on its branch), the
/// newest first.
List<ChatState> chatsOnItem(Daemon daemon, GitHubRef ref) {
  final key = repoKey(ref.host, ref.repo);
  bool on(GitHubLink? l) =>
      l != null && repoKey(l.host, l.repo) == key && l.number == ref.number;
  return daemon.chats.values.where((c) => on(c.github) || on(c.pull)).toList()
    ..sort((a, b) => b.created.compareTo(a.created));
}

/// An item's small state line: its state, checks, review decision and
/// review threads not resolved.
class ItemBadges extends StatelessWidget {
  const new(this.item, {super.key, this.wide = true});

  final GitHubItem item;

  /// With the review decision's words (else only its color's dot).
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final it = item;
    final checks = checksIcon(t, it.checks);
    final review = reviewWords(t, it.review);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (checks != null)
          Tooltip(
            message: checks.words,
            child: Icon(checks.icon, size: 14, color: checks.color),
          ),
        if (review != null) ...[
          const SizedBox(width: 8),
          if (wide)
            Text(review.$1, style: theme.ui(review.$2, size: 11.5))
          else
            Tooltip(
              message: review.$1,
              child: Icon(
                Icons.rate_review_outlined,
                size: 13,
                color: review.$2,
              ),
            ),
        ],
        if (it.unresolved > 0) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: unresolvedWords(it.unresolved),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined, size: 13, color: t.needs),
                const SizedBox(width: 3),
                Text('${it.unresolved}', style: theme.ui(t.needs, size: 11.5)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// When an item changed, in one line of a fixed width (sized for
/// [agoShortLongest]): "12d", "5w", "3mo"; the date and time on hover.
class ItemAge extends StatelessWidget {
  const new(this.ms, {super.key});

  /// When (ms since the epoch).
  final int ms;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final style = theme.ui(theme.t.textMuted, size: 11.5);
    final when = DateTime.fromMillisecondsSinceEpoch(ms);
    final longest = TextPainter(
      text: TextSpan(text: agoShortLongest, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = longest.width.ceilToDouble();
    longest.dispose();
    return Tooltip(
      message: 'Updated ${dateTime(when)}',
      child: SizedBox(
        width: width,
        child: Text(
          agoShort(clock().difference(when)),
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.right,
          style: style,
        ),
      ),
    );
  }
}

/// Start work: a menu of folders (those that are clones of the item's
/// repository first), then the New chat dialog with the item picked.
class StartWork extends StatelessWidget {
  const new({required this.daemon, required this.item, super.key});

  final Daemon daemon;
  final GitHubItem item;

  @override
  Widget build(BuildContext context) => Menu(
    digits: true,
    entries: startEntries(context, daemon, item),
    builder: (context, open) => Button(
      label: 'Start work',
      icon: Icons.play_arrow,
      menu: true,
      onPressed: open,
    ),
  );
}

/// Start work's menu on [item]: the folders that are clones of its
/// repository first, then the others.
List<MenuEntry> startEntries(
  BuildContext context,
  Daemon daemon,
  GitHubItem item,
) {
  final clones = clonesOf(item.ref);
  return [
    for (final f in clones)
      MenuEntry(
        folderParts(f).$1,
        detail: folderParts(f).$2,
        onPick: () => startOn(context, daemon, item, f),
      ),
    if (clones.isNotEmpty) MenuEntry.divider,
    ...folderEntries(daemon, onPick: (f) => startOn(context, daemon, item, f)),
  ];
}

/// The folders that are clones of each repository, by [repoKey], as the
/// daemon last said (ListGitHubRepos).
final githubFolders = ValueNotifier<Map<(String, String), List<String>>>({});

/// A repository's key in any case: GitHub's names are unique regardless
/// of case, and a remote (so ListGitHubRepos, and a chat's pull request
/// found from its branch) may spell one differently from GitHub's items.
(String, String) repoKey(String host, String repo) =>
    (host.toLowerCase(), repo.toLowerCase());

/// The folders that are clones of [ref]'s repository.
List<String> clonesOf(GitHubRef ref) =>
    githubFolders.value[repoKey(ref.host, ref.repo)] ?? const [];

/// Asks the daemon which repositories the app's folders are clones of.
Future<List<GitHubRepo>> loadRepos(Daemon daemon) async {
  final r = await daemon.client.listGitHubRepos(
    ListGitHubReposRequest(folders: recentFolders(daemon.chats.values)),
  );
  githubFolders.value = {
    for (final repo in r.repos) repoKey(repo.host, repo.repo): repo.folders,
  };
  return r.repos;
}

/// Starts work on [item] in [folder] (one to choose, when null): the New
/// chat dialog with it picked, a worktree on its branch (a pull request's
/// head, which the daemon fetches).
Future<void> startOn(
  BuildContext context,
  Daemon daemon,
  GitHubItem item,
  String? folder,
) async {
  final f = folder ?? await getDirectoryPath(confirmButtonText: 'Choose');
  if (f == null || !context.mounted) return;
  await newChat(context, daemon, f, issue: IssueChat.github(item));
}

/// What an image in GitHub's text shows as: a link to it, opened in the
/// browser when clicked; nothing is fetched (an author could make the app
/// fetch anything, and tell who read it).
Widget githubImage(Uri uri, String? alt) {
  final link = webLink(uri.toString());
  return LinkText(
    '[image${alt == null || alt.isEmpty ? '' : ': $alt'}]',
    size: 12.5,
    tooltip: link == null ? '' : 'Open the image in the browser',
    onTap: link == null ? null : () => unawaited(openInDefaultBrowser(link)),
  );
}

/// Explains there's no GitHub host, with the way to Settings.
class NoHost extends StatelessWidget {
  const new({required this.onSettings, super.key, this.error});

  final VoidCallback onSettings;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error ??
                'Sign in with gh auth login in a terminal, or add a token in',
            textAlign: TextAlign.center,
            style: theme.ui(error == null ? t.textMuted : t.crashed),
          ),
          LinkText('Settings › GitHub', onTap: onSettings),
        ],
      ),
    );
  }
}

/// A chat's GitHub pull request or issue in its header: its number in its
/// state's color, its checks, review and threads not resolved, asked of
/// the daemon while it shows (each minute, quietly); the details on
/// hover; a click shows it in the GitHub view.
class GitHubChip extends StatefulWidget {
  const new({required this.daemon, required this.link, super.key});

  final Daemon daemon;
  final GitHubLink link;

  @override
  State<GitHubChip> createState() => _GitHubChipState();
}

class _GitHubChipState extends State<GitHubChip> {
  GitHubItem? _item;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_load(quiet: false));
    _poll = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _load(quiet: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool quiet}) async {
    try {
      final r = await widget.daemon.client.getGitHubStates(
        GetGitHubStatesRequest(items: [widget.link], quiet: quiet),
      );
      final it = r.items.where((i) => i.id == widget.link.id).firstOrNull;
      if (mounted && it != null) setState(() => _item = it);
    } on Object {
      // The last state stays; the chip says nothing new.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final l = widget.link;
    final it = _item;
    final checks = it == null ? null : checksIcon(t, it.checks);
    final review = it == null ? null : reviewWords(t, it.review);
    final details = it == null
        ? '${l.repo}#${l.number}'
        : [
            '${l.repo}#${l.number}: ${it.title}',
            itemState(it),
            ?checks?.words,
            ?review?.$1,
            if (it.unresolved > 0) unresolvedWords(it.unresolved),
          ].join('\n');
    return Tap(
      tooltip: details,
      onTap: () => showItem(widget.daemon, l.asRef, pull: l.pull),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            l.pull ? Icons.merge_type : Icons.adjust,
            size: 13,
            color: it == null ? t.textMuted : itemColor(t, it),
          ),
          const SizedBox(width: 3),
          Text('#${l.number}', style: theme.code(t.link, size: 12)),
          if (it != null) ...[
            const SizedBox(width: 6),
            ItemBadges(it, wide: false),
          ],
        ],
      ),
    );
  }
}

/// "3 review threads not resolved".
String unresolvedWords(int n) =>
    '$n review thread${n == 1 ? '' : 's'} not resolved';
