import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_checks.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_files.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/pull_activity.dart';
import 'package:nushi/pull_cache.dart';
import 'package:nushi/pull_chats.dart';
import 'package:nushi/pull_header.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_skeleton.dart';
import 'package:nushi/pull_todo.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// How often an open pull request is asked for again (quietly), in the
/// GitHub view.
const pullPoll = Duration(seconds: 30);

/// Each pull request's tab (Activity, Checks, Files) as left, while the
/// app runs: a look at a chat comes back to it, and to what was being
/// written there.
final _tabLeft = <String, PullSection>{};

/// No pull request's tab left (tests: each starts afresh).
@visibleForTesting
void forgetPullTabs() => _tabLeft.clear();

/// A pull request's page: its head ([PullHeader]: state, title, branches,
/// whose move it is, the status lights), then its activity (the
/// description, comments and reviews), its checks, or its files with the
/// review threads at their lines, in one scroll; the text in a column of
/// [readableWidth] at most, the files' diff the whole width and the
/// window's height.
///
/// In a chat's Pull request tab it shows the chat's pull request as
/// [source] has it, asked on its timer (the pane has none of its own),
/// with no Start work or chats' links (the chat is the one); its comments
/// are seen while it shows.
class GitHubPullPane extends StatefulWidget {
  const new({
    required this.daemon,
    required this.ref,
    super.key,
    this.now,
    this.source,
  });

  final Daemon daemon;
  final GitHubRef ref;
  final DateTime? now;

  /// The chat's pull request, in its Pull request tab.
  final ChatPull? source;

  @override
  State<GitHubPullPane> createState() => _GitHubPullPaneState();
}

class _GitHubPullPaneState extends State<GitHubPullPane> {
  /// What shows in the GitHub view: the pull request read last (kept from
  /// before, from [_keptAt], until the first answer), else nothing yet
  /// (the skeleton). In a chat's tab its [GitHubPullPane.source]'s.
  late GitHubPull? _pull = _kept?.$2;
  late final (DateTime, GitHubPull)? _kept = widget.source == null
      ? cachedPull(widget.ref)
      : null;
  late DateTime? _keptAt = _kept?.$1;
  bool _asking = true;
  String? _error;
  Timer? _poll;
  late PullSection _tab = _tabLeft[_refKey] ?? PullSection.activity;
  String get _refKey =>
      '${widget.ref.host} ${widget.ref.repo} ${widget.ref.number}';
  final _scroll = ScrollController();
  final GlobalKey _tabs = GlobalKey();
  final GlobalKey _todo = GlobalKey();

  /// A review To do pointed at in Activity, and its key.
  (String, GlobalKey)? _shown;

  /// Who the user is on its host ('' until known).
  String _me = '';

  bool get _inChat => widget.source != null;

  @override
  void initState() {
    super.initState();
    if (widget.source case final s?) {
      s.addListener(_sourceChanged);
      // Asked as the tab opens, unless it was a moment ago.
      unawaited(s.refresh(again: false));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) s.markSeen();
      });
    } else {
      unawaited(_load());
      _poll = Timer.periodic(pullPoll, (_) => unawaited(_load(quiet: true)));
    }
    unawaited(
      githubLogin(widget.daemon, widget.ref.host).then((me) {
        if (mounted) setState(() => _me = me);
      }),
    );
    _redraw.addListener(_changed);
  }

  void _changed() => setState(() {});

  /// The chat's pull request was asked for: its comments are seen.
  void _sourceChanged() {
    widget.source?.markSeen();
    setState(() {});
  }

  @override
  void dispose() {
    _tabLeft[_refKey] = _tab;
    widget.source?.removeListener(_sourceChanged);
    _redraw.removeListener(_changed);
    _poll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Asks for the pull request again (it changed here): the chat's, or
  /// the pane's own. An ask of the chat's under way may have started
  /// before the change, so another follows it.
  Future<void> _refresh() async {
    final s = widget.source;
    if (s == null) return await _load();
    if (s.asking) await s.refresh();
    await s.refresh();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final r = await widget.daemon.client.getGitHubPull(
        GetGitHubPullRequest(ref: widget.ref, quiet: quiet),
      );
      keepPull(widget.ref, r.pull);
      if (mounted) {
        setState(() {
          _pull = r.pull;
          _keptAt = null;
          _error = null;
        });
      }
    } on Object catch (e) {
      // A failed poll keeps what shows, and says why.
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted && _asking) setState(() => _asking = false);
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

  /// Shows review [c] in Activity, To do's pointer to it.
  void _showReview(GitHubComment c) {
    setState(() {
      _tab = PullSection.activity;
      _shown = (c.id, GlobalKey());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final to = _shown?.$2.currentContext;
      if (to == null || !to.mounted) return;
      Scrollable.ensureVisible(
        to,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final (pull, keptAt, asking, error) = switch (widget.source) {
      final s? => (s.pull, s.keptAt, s.asking, s.error),
      null => (_pull, _keptAt, _asking, _error),
    };
    final p = pull;
    if (p == null) {
      return error == null
          ? const PullSkeleton()
          : Center(child: Text(error, style: theme.ui(t.crashed)));
    }
    final failed = p.checks.where((c) => c.failed).length;
    final now = widget.now ?? clock();
    final todo = todoOf(p);
    final items = todo.items;
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
            if (keptAt case final at?)
              column(
                Text(
                  updatedLine(at, loading: asking, now: now)!,
                  key: const ValueKey('pull-kept'),
                  textAlign: TextAlign.right,
                  style: theme.ui(t.textMuted, size: 11.5),
                ),
                top: 8,
              ),
            column(
              PullHeader(
                pull: p,
                now: now,
                todo: items.length + (hasConflicts(p) ? 1 : 0),
                onJump: _jump,
                threadsTo: open ? PullSection.todo : PullSection.activity,
                actions: _actions(context, p),
              ),
              top: keptAt == null ? 14 : 2,
            ),
            if (open)
              column(
                PullTodo(
                  key: _todo,
                  daemon: widget.daemon,
                  pull: p,
                  items: items,
                  older: todo.older,
                  onOlder: _showReview,
                  now: now,
                  onChanged: _refresh,
                ),
                top: 16,
              ),
            if (!_inChat) column(PullChats(widget.daemon, p), top: 10),
            if (error case final e?)
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
                GitHubChecks(
                  daemon: widget.daemon,
                  pull: p,
                  onChanged: _refresh,
                ),
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
                    onChanged: _refresh,
                  ),
                ),
              ),
              _ => column(
                PullActivity(
                  daemon: widget.daemon,
                  pull: p,
                  now: now,
                  me: _me,
                  onPosted: _refresh,
                  onTodo: () => _jump(PullSection.todo),
                  findings: findingCounts(items),
                  shown: _shown,
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
      if (!_inChat) StartWork(daemon: daemon, item: it, button: true),
      Button(
        label: pending > 0 ? 'Review ($pending)…' : 'Review…',
        onPressed: () => submitReview(context, daemon, p, onDone: _refresh),
      ),
      Button(
        label: 'Open on GitHub',
        icon: Icons.open_in_new,
        onPressed: it.url.isEmpty ? null : () => openWeb(it.url),
      ),
    ];
  }
}

/// What redraws the pane: Settings' Findings from review bots (the To
/// do list), and the review's drafts (Review (n)…).
final _redraw = Listenable.merge([
  githubFindings,
  githubFindingBots,
  githubFindingHeadings,
  draftsChanged,
]);

/// [p]'s To do, with the bots' findings when Settings reads them.
Todo todoOf(GitHubPull p) => todo(
  p,
  findings: githubFindings.value
      ? findingsSetup(githubFindingBots.value, githubFindingHeadings.value)
      : null,
);
