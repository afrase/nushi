import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// An item's state's color: open green (gray when a draft), merged
/// violet, closed red.
Color itemColor(Tokens t, GitHubItem it) => switch (it.state) {
  'merged' => t.subagentAccent,
  'closed' => t.crashed,
  _ => it.draft ? t.textMuted : t.done,
};

/// An item's state as a word: "Open", "Draft", "Merged", "Closed".
String itemState(GitHubItem it) => switch (it.state) {
  'merged' => 'Merged',
  'closed' => 'Closed',
  _ => it.draft ? 'Draft' : 'Open',
};

/// A review decision in words, and its color.
(String, Color)? reviewWords(Tokens t, String review) => switch (review) {
  'approved' => ('Approved', t.done),
  'changes_requested' => ('Changes requested', t.crashed),
  'review_required' => ('Review required', t.textMuted),
  _ => null,
};

/// A checks' state's icon and color.
(IconData, Color, String)? checksIcon(Tokens t, String state) =>
    switch (state) {
      'success' => (Icons.check, t.done, 'Checks passed'),
      'failure' || 'error' => (Icons.close, t.crashed, 'Checks failed'),
      'pending' => (Icons.schedule, t.needs, 'Checks running'),
      _ => null,
    };

/// The chats on a GitHub item, the newest first.
List<ChatState> chatsOnItem(Daemon daemon, GitHubRef ref) =>
    daemon.chats.values
        .where(
          (c) =>
              c.github?.host == ref.host &&
              c.github?.repo == ref.repo &&
              c.github?.number == ref.number,
        )
        .toList()
      ..sort((a, b) => b.created.compareTo(a.created));

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
            message: checks.$3,
            child: Icon(checks.$1, size: 14, color: checks.$2),
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
            message: _unresolved(it.unresolved),
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

/// A row of the inbox: repository and number, title, state, checks,
/// review, threads not resolved, its chats, when it changed, Start work.
class ItemRow extends StatelessWidget {
  const new({
    required this.daemon,
    required this.item,
    required this.selected,
    required this.now,
    required this.onOpen,
    required this.startMenu,
    super.key,
  });

  final Daemon daemon;
  final GitHubItem item;
  final bool selected;
  final DateTime now;
  final VoidCallback onOpen;

  /// Takes the row's Start work menu, for ⌘⏎ (when it's selected).
  final void Function(OpenMenu open) startMenu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _row(context, wide: box.maxWidth > 760),
  );

  Widget _row(BuildContext context, {required bool wide}) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final it = item;
    final chats = chatsOnItem(daemon, it.ref);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Tap(
        selected: selected,
        onTap: onOpen,
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        child: Row(
          children: [
            Tooltip(
              message: itemState(it),
              child: Icon(
                it.pull ? Icons.merge_type : Icons.adjust,
                size: 14,
                color: itemColor(t, it),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: wide ? 190 : 120,
              child: Text(
                '${it.ref.repo}#${it.ref.number}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.code(t.textSecondary, size: 11.5),
              ),
            ),
            Expanded(
              child: Text(
                it.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.text),
              ),
            ),
            const SizedBox(width: 8),
            ItemBadges(it, wide: wide),
            if (chats.isNotEmpty) ChatMarks(daemon, chats),
            const SizedBox(width: 8),
            ItemAge(it.updatedMs.toInt(), now: now),
            StartWork(
              daemon: daemon,
              item: it,
              menu: selected ? startMenu : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// When an item changed, in one line of a fixed width (sized for
/// [agoShortLongest]): "12d", "5w", "3mo"; the date and time on hover.
class ItemAge extends StatelessWidget {
  const new(this.ms, {required this.now, super.key});

  /// When (ms since the epoch).
  final int ms;
  final DateTime now;

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
          agoShort(now.difference(when)),
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
  const new({
    required this.daemon,
    required this.item,
    super.key,
    this.menu,
    this.button = false,
  });

  final Daemon daemon;
  final GitHubItem item;

  /// Takes the menu's opener, for ⌘⏎.
  final void Function(OpenMenu open)? menu;

  /// As a button rather than a link.
  final bool button;

  @override
  Widget build(BuildContext context) {
    final clones =
        githubFolders.value[(item.ref.host, item.ref.repo)] ?? const [];
    return Menu(
      digits: true,
      entries: [
        for (final f in clones)
          MenuEntry(
            folderParts(f).$1,
            detail: folderParts(f).$2,
            onPick: () => startOn(context, daemon, item, f),
          ),
        if (clones.isNotEmpty) MenuEntry.divider,
        ...folderEntries(
          daemon,
          onPick: (f) => startOn(context, daemon, item, f),
        ),
      ],
      builder: (context, open) {
        menu?.call(open);
        return Button(
          label: 'Start work',
          icon: button ? Icons.play_arrow : null,
          menu: true,
          tooltip: menu != null ? '⌘⏎' : '',
          onPressed: open,
        );
      },
    );
  }
}

/// The folders that are clones of each repository, by host and
/// owner/name, as the daemon last said (ListGitHubRepos).
final githubFolders = ValueNotifier<Map<(String, String), List<String>>>({});

/// Asks the daemon which repositories the app's folders are clones of.
Future<List<GitHubRepo>> loadRepos(Daemon daemon) async {
  final r = await daemon.client.listGitHubRepos(
    ListGitHubReposRequest(folders: recentFolders(daemon.chats.values)),
  );
  githubFolders.value = {
    for (final repo in r.repos) (repo.host, repo.repo): repo.folders,
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

/// The agents of an item's chats (three at most, then how many more); a
/// click opens the newest.
class ChatMarks extends StatelessWidget {
  const new(this.daemon, this.chats, {super.key});

  final Daemon daemon;
  final List<ChatState> chats;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = chats.length;
    return Tap(
      onTap: () => daemon.select(chats.first.id),
      tooltip: n == 1 ? 'Open its chat' : 'Open its newest chat (it has $n)',
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in chats.take(3))
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: AgentMark(c.agent, size: 13, color: t.textSecondary),
            ),
          if (n > 3) Text('+${n - 3}', style: theme.ui(t.textMuted, size: 11)),
        ],
      ),
    );
  }
}

/// What an image in GitHub's text shows as: a link to it, opened in the
/// browser when clicked; nothing is fetched (an author could make the app
/// fetch anything, and tell who read it).
Widget githubImage(Uri uri, String? alt) => Builder(
  builder: (context) {
    final theme = NushiTheme.of(context);
    final link = webLink(uri.toString());
    return Tap(
      onTap: link == null ? null : () => unawaited(launchUrl(link)),
      tooltip: link == null ? '' : 'Open the image in the browser',
      child: Text(
        '[image${alt == null || alt.isEmpty ? '' : ': $alt'}]',
        style: theme.ui(
          link == null ? theme.t.textMuted : theme.t.link,
          size: 12.5,
        ),
      ),
    );
  },
);

/// Opens [url] in the browser, http and https only.
void openWeb(String url) {
  if (webLink(url) case final u?) unawaited(launchUrl(u));
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
  void didUpdateWidget(GitHubChip old) {
    super.didUpdateWidget(old);
    if (old.link.id != widget.link.id) unawaited(_load(quiet: false));
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
            ?checks?.$3,
            ?review?.$1,
            if (it.unresolved > 0) _unresolved(it.unresolved),
          ].join('\n');
    return Tap(
      tooltip: details,
      onTap: () => widget.daemon.showGitHub(
        open: true,
        item: GitHubRef(host: l.host, repo: l.repo, number: l.number),
      ),
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

String _unresolved(int n) =>
    '$n review thread${n == 1 ? '' : 's'} not resolved';
