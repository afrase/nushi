import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The pull request [text] names: its link (https://host/owner/name/pull/n),
/// owner/name#n, or #n or n in [repo] on [host]; null for anything else.
GitHubRef? parsePullRef(String text, {String host = '', String repo = ''}) {
  final s = text.trim();
  final url = RegExp(r'^https?://([^/\s]+)/([\w.-]+/[\w.-]+)/pull/(\d+)\b')
      .firstMatch(s);
  if (url != null) {
    return GitHubRef(
      host: url[1]!.toLowerCase(),
      repo: url[2],
      number: int.parse(url[3]!),
    );
  }
  final named = RegExp(r'^([\w.-]+/[\w.-]+)#(\d+)$').firstMatch(s);
  if (named != null && host.isNotEmpty) {
    return GitHubRef(host: host, repo: named[1], number: int.parse(named[2]!));
  }
  final n = RegExp(r'^#?(\d+)$').firstMatch(s);
  if (n != null && host.isNotEmpty && repo.isNotEmpty) {
    return GitHubRef(host: host, repo: repo, number: int.parse(n[1]!));
  }
  return null;
}

/// Link pull request…: a field for its link or number, the pull request of
/// the folder's branch first when it has one the chat hasn't (a chat links
/// it by itself only once it pushed the branch: ADR 0059's amendment), and
/// the open pull requests of the chat's repository that are mine or ask my
/// review (the inbox's, asked once); picking one asks GitHub for it and
/// links it.
Future<void> linkPull(BuildContext context, ChatPull cp) =>
    showDialog<void>(context: context, builder: (_) => _LinkPull(cp));

class _LinkPull extends StatefulWidget {
  const new(this.cp);

  final ChatPull cp;

  @override
  State<_LinkPull> createState() => _LinkPullState();
}

class _LinkPullState extends State<_LinkPull> {
  final _text = TextEditingController();
  List<GitHubItem> _pulls = const [];

  /// The pull request of the folder's branch, when the chat hasn't it: its
  /// row as known (none before GitHub said), and the branch.
  (GitHubRef, GitHubItem?, String)? _branch;
  String? _error;
  bool _busy = false;

  String get _host => widget.cp.found?.host ?? widget.cp.current?.host ?? '';

  /// The chat has one: this one joins it (ADR 0117), and the list leaves
  /// out those linked.
  bool get _another => widget.cp.links.isNotEmpty;
  String get _repo => widget.cp.found?.repo ?? widget.cp.current?.repo ?? '';

  @override
  void initState() {
    super.initState();
    unawaited(_list());
    unawaited(_suggest());
  }

  /// Asks the daemon for the branch's pull request, not linked
  /// (FindChatPull's suggest), and GitHub for its row.
  Future<void> _suggest() async {
    final cp = widget.cp;
    try {
      final f = await cp.daemon.client.findChatPull(
        FindChatPullRequest(chatId: cp.chat.id, suggest: true),
      );
      if (!f.hasBranchPull() || !mounted) return;
      final a = addressOf(f.branchPull);
      final items = GitHubItems.of(cp.daemon);
      setState(() => _branch = (a.ref, null, f.branch));
      await items.ask([a], quiet: false);
      final it = items.look(a).item;
      if (mounted) setState(() => _branch = (a.ref, it, f.branch));
    } on Object {
      // The list and the field still link one.
    }
  }

  /// Whether [it] is the branch's, which shows first.
  bool _isBranch(GitHubItem it) {
    final b = _branch?.$1;
    return b != null &&
        b.host == it.ref.host &&
        b.repo.toLowerCase() == it.ref.repo.toLowerCase() &&
        b.number == it.ref.number;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _list() async {
    if (_host.isEmpty || _repo.isEmpty) return;
    try {
      final r = await widget.cp.daemon.client.listGitHubInbox(
        ListGitHubInboxRequest(host: _host, repos: [_repo]),
      );
      final seen = <int>{};
      final pulls = [
        for (final it in [...r.mine, ...r.review])
          if (it.pull &&
              it.state == 'open' &&
              seen.add(it.ref.number) &&
              !(_another &&
                  widget.cp.links.any((l) => l.number == it.ref.number)))
            it,
      ];
      if (mounted) setState(() => _pulls = pulls);
    } on Object {
      // The field still links one.
    }
  }

  Future<void> _link(GitHubRef ref) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.cp.daemon.client.getGitHubPull(
        GetGitHubPullRequest(ref: ref),
      );
      final link = GitHubLink(
        host: ref.host,
        repo: ref.repo,
        number: ref.number,
        id: r.pull.item.id,
        pull: true,
      );
      await (_another ? widget.cp.addLink(link) : widget.cp.setLink(link));
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final ref = parsePullRef(_text.text, host: _host, repo: _repo);
    if (ref == null) {
      setState(() => _error = "That isn't a pull request's link or number.");
      return;
    }
    unawaited(_link(ref));
  }

  /// A pull request to pick: its number in its state's color, its title
  /// and its author ([it] null: the number alone, until GitHub says).
  Widget _row(GitHubRef ref, GitHubItem? it) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Tap(
      onTap: _busy ? null : () => _link(ref),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Text(
            '#${ref.number}',
            style: theme.code(
              it == null ? t.textMuted : itemColor(t, it),
              size: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              it?.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text, size: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(it?.author ?? '', style: theme.ui(t.textMuted, size: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return nushiDialog(
      _another ? 'Link another pull request' : 'Link pull request',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_another)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "It joins this chat's pull requests; the others stay.",
                style: theme.ui(t.textMuted, size: 12),
              ),
            ),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): _submit,
            },
            child: TextField(
              controller: _text,
              autofocus: true,
              enabled: !_busy,
              style: theme.ui(t.text),
              decoration: InputDecoration(
                isDense: true,
                hintText: _repo.isEmpty
                    ? "A pull request's link"
                    : "A pull request's link, or its number in $_repo",
              ),
            ),
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(e, style: theme.ui(t.crashed, size: 12)),
            ),
          if (_branch case (final ref, final it, final branch)?) ...[
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'The pull request of '),
                  TextSpan(
                    text: branch,
                    style: theme.code(t.textSecondary, size: 11.5),
                  ),
                ],
              ),
              style: theme.ui(t.textMuted, size: 12),
            ),
            _row(ref, it),
          ],
          if (_pulls.where((it) => !_isBranch(it)) case final pulls
              when pulls.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final it in pulls.take(8)) _row(it.ref, it),
          ],
        ],
      ),
      [
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        Button(
          label: _busy ? 'Linking…' : 'Link',
          kind: ButtonKind.primary,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
