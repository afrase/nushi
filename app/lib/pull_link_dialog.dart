import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
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

/// Link pull request…: a field for its link or number, and the open pull
/// requests of the chat's repository that are mine or ask my review (the
/// inbox's, asked once); picking one asks GitHub for it and links it.
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
  String? _error;
  bool _busy = false;

  String get _host => widget.cp.found?.host ?? widget.cp.link?.host ?? '';
  String get _repo => widget.cp.found?.repo ?? widget.cp.link?.repo ?? '';

  @override
  void initState() {
    super.initState();
    unawaited(_list());
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
          if (it.pull && it.state == 'open' && seen.add(it.ref.number)) it,
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
      await widget.cp.setLink(
        GitHubLink(
          host: ref.host,
          repo: ref.repo,
          number: ref.number,
          id: r.pull.item.id,
          pull: true,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return nushiDialog(
      'Link pull request',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          if (_pulls.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final it in _pulls.take(8))
              Tap(
                onTap: _busy ? null : () => _link(it.ref),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Text(
                      '#${it.ref.number}',
                      style: theme.code(itemColor(t, it), size: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        it.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.text, size: 12.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(it.author, style: theme.ui(t.textMuted, size: 12)),
                  ],
                ),
              ),
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
