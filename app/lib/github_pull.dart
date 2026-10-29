import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_checks.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_files.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/pull_activity.dart';
import 'package:nushi/pull_header.dart';
import 'package:nushi/pull_todo.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// How often an open pull request is asked for again (quietly).
const pullPoll = Duration(seconds: 30);

/// A pull request's page: its head ([PullHeader]: state, title, branches,
/// whose move it is, the status lights), then its activity (the
/// description, comments and reviews), its checks, or its files with the
/// review threads at their lines, in one scroll; the text in a column of
/// [readableWidth] at most, the files' diff the whole width and the
/// window's height.
///
/// In a chat's Pull request tab ([inChat]) it has no Start work or chats'
/// links (the chat is the one); [onLoad] gets each answer.
class GitHubPullPane extends StatefulWidget {
  const new({
    required this.daemon,
    required this.ref,
    super.key,
    this.now,
    this.inChat = false,
    this.onLoad,
  });

  final Daemon daemon;
  final GitHubRef ref;
  final DateTime? now;
  final bool inChat;
  final ValueChanged<GitHubPull>? onLoad;

  @override
  State<GitHubPullPane> createState() => _GitHubPullPaneState();
}

class _GitHubPullPaneState extends State<GitHubPullPane> {
  GitHubPull? _pull;
  String? _error;
  Timer? _poll;
  PullSection _tab = PullSection.activity;
  final _scroll = ScrollController();
  final GlobalKey _tabs = GlobalKey();
  final GlobalKey _todo = GlobalKey();

  /// Who the user is on its host ('' until known).
  String _me = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(
      githubLogin(widget.daemon, widget.ref.host).then((me) {
        if (mounted) setState(() => _me = me);
      }),
    );
    _poll = Timer.periodic(pullPoll, (_) => unawaited(_load(quiet: true)));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final r = await widget.daemon.client.getGitHubPull(
        GetGitHubPullRequest(ref: widget.ref, quiet: quiet),
      );
      if (mounted) {
        setState(() {
          _pull = r.pull;
          _error = null;
        });
        widget.onLoad?.call(r.pull);
      }
    } on Object catch (e) {
      // A failed poll keeps what shows, and says why.
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  /// Shows [s]: its tab picked, scrolled to the top.
  void _jump(PullSection s) {
    void show() {
      final to = (s == PullSection.todo ? _todo : _tabs).currentContext;
      if (to == null || !to.mounted) return;
      Scrollable.ensureVisible(
        to,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    if (s == PullSection.todo) return show();
    setState(() => _tab = s);
    WidgetsBinding.instance.addPostFrameCallback((_) => show());
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = _pull;
    if (p == null) {
      return Center(
        child: Text(
          _error ?? 'Loading…',
          style: theme.ui(_error == null ? t.textMuted : t.crashed),
        ),
      );
    }
    final failed = p.checks.where((c) => c.failed).length;
    final now = widget.now ?? clock();
    final items = todoItems(p);
    final open = p.item.state == 'open';
    // The text reads in a column of [readableWidth] at most, centred; the
    // files' diff takes the whole width.
    return LayoutBuilder(
      builder: (context, box) {
        final pad = readablePad(box.maxWidth);
        Widget column(Widget child, {double top = 0, double bottom = 0}) =>
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, top, pad, bottom),
              sliver: SliverToBoxAdapter(child: child),
            );
        return CustomScrollView(
          controller: _scroll,
          slivers: [
            column(
              PullHeader(
                pull: p,
                now: now,
                todo: items.length + (p.mergeable == 'conflicting' ? 1 : 0),
                onJump: _jump,
                threadsTo: open ? PullSection.todo : PullSection.activity,
                actions: _actions(context, p),
              ),
              top: 14,
            ),
            if (open)
              column(
                PullTodo(
                  key: _todo,
                  daemon: widget.daemon,
                  pull: p,
                  items: items,
                  now: now,
                  onChanged: _load,
                ),
                top: 16,
              ),
            if (!widget.inChat) column(_Chats(widget.daemon, p), top: 10),
            if (_error case final e?)
              column(
                Text('Not current: $e', style: theme.ui(t.needs, size: 12)),
                top: 6,
              ),
            column(
              Row(
                key: _tabs,
                children: [
                  Segmented(
                    value: _tab,
                    segments: [
                      (
                        PullSection.activity,
                        'Activity ${p.conversation.length + 1}',
                      ),
                      (
                        PullSection.checks,
                        failed > 0
                            ? 'Checks · $failed failing'
                            : 'Checks ${p.checks.length}',
                      ),
                      (PullSection.files, 'Files ${p.changedFiles}'),
                    ],
                    // Scrolled up to the section picked.
                    onChanged: _jump,
                  ),
                ],
              ),
              top: 18,
              bottom: 6,
            ),
            switch (_tab) {
              PullSection.checks => column(
                GitHubChecks(daemon: widget.daemon, pull: p, onChanged: _load),
                bottom: 20,
              ),
              PullSection.files => SliverToBoxAdapter(
                // The window's height, under the tabs: the list and the
                // diff scroll in it.
                child: SizedBox(
                  height: box.maxHeight - 40,
                  child: GitHubFiles(
                    daemon: widget.daemon,
                    pull: p,
                    now: widget.now,
                    onChanged: _load,
                  ),
                ),
              ),
              _ => column(
                PullActivity(
                  daemon: widget.daemon,
                  pull: p,
                  now: now,
                  me: _me,
                  onPosted: _load,
                  onTodo: () => _jump(PullSection.todo),
                ),
                top: 6,
                bottom: 24,
              ),
            },
          ],
        );
      },
    );
  }

  /// The head's buttons: Start work (the GitHub view), Review…, Open on
  /// GitHub.
  List<Widget> _actions(BuildContext context, GitHubPull p) {
    final it = p.item;
    final daemon = widget.daemon;
    final pending = p.pendingComments + reviewDrafts(it.ref).length;
    return [
      if (!widget.inChat) StartWork(daemon: daemon, item: it, button: true),
      Button(
        label: pending > 0 ? 'Review ($pending)…' : 'Review…',
        onPressed: () => submitReview(context, daemon, p, onDone: _load),
      ),
      Button(
        label: 'Open on GitHub',
        icon: Icons.open_in_new,
        onPressed: it.url.isEmpty ? null : () => openWeb(it.url),
      ),
    ];
  }
}

/// The chats on the pull request, in the GitHub view: each a link to it.
class _Chats extends StatelessWidget {
  const new(this.daemon, this.pull);

  final Daemon daemon;
  final GitHubPull pull;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chats = chatsOnItem(daemon, pull.item.ref);
    if (chats.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Chats:', style: theme.ui(t.textMuted, size: 12)),
        for (final c in chats.take(4))
          Tap(
            onTap: () => daemon.select(c.id),
            tooltip: 'Open the chat',
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AgentMark(c.agent, size: 13, color: t.textSecondary),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    c.title.isEmpty ? 'New chat' : c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.link, size: 12),
                  ),
                ),
              ],
            ),
          ),
        if (chats.length > 4)
          Text(
            '+${chats.length - 4} chats',
            style: theme.ui(t.textMuted, size: 12),
          ),
      ],
    );
  }
}

/// Whether the pull request can merge, in a few words.
(String, Color) mergeWords(Tokens t, GitHubPull p) {
  if (p.item.state != 'open') return (itemState(p.item), itemColor(t, p.item));
  if (p.item.draft) return ('Draft: not ready to merge', t.textMuted);
  if (p.mergeable == 'conflicting') {
    return ('Conflicts with its base', t.crashed);
  }
  return switch (p.mergeState) {
    'clean' || 'has_hooks' => ('Ready to merge', t.done),
    'blocked' => ('Blocked: a review or a check its base requires', t.needs),
    'behind' => ('Behind its base', t.needs),
    'unstable' => ('Checks failing', t.needs),
    'dirty' => ('Conflicts with its base', t.crashed),
    _ => ('Checking whether it can merge…', t.textMuted),
  };
}
