import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_checks.dart';
import 'package:nushi/github_files.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/item_chats.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/pull_cache.dart';
import 'package:nushi/pull_comments.dart';
import 'package:nushi/pull_commits.dart';
import 'package:nushi/pull_header.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_merge_card.dart';
import 'package:nushi/pull_merge_state.dart';
import 'package:nushi/pull_overview.dart';
import 'package:nushi/pull_skeleton.dart';
import 'package:nushi/pull_thread_card.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/review_findings.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Each pull request's tab (Overview, Commits, Checks, Files changed) as
/// left, while the app runs: a look at a chat comes back to it, and to
/// what was being written there.
final Map<String, PullSection> _tabLeft = runMap();

/// No pull request's tab left (tests: each starts afresh).
@visibleForTesting
void forgetPullTabs() => _tabLeft.clear();

/// Opens [ref]'s pull request at [section] the next time it shows (a
/// row's View changes, its badge's Show checks).
void openPullAt(GitHubRef ref, PullSection section) =>
    _tabLeft['${ref.host} ${ref.repo} ${ref.number}'] = section;

/// A pull request's page, after GitHub's own (ADR 0137): the head
/// ([PullHeader]: the title, Merge status and Submit review at its
/// right, state, who opened it, base ← head; the slim bar, [PullBar],
/// over the page once its title has scrolled away), the tabs (Overview,
/// Commits, Checks, Files changed) and the tab's content in one scroll,
/// in a column of [pullPageWidth] at most; the files' diff the whole
/// width and the window's height.
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
    this.source,
    this.refreshes,
  });

  final Daemon daemon;
  final GitHubRef ref;

  /// Asks the page again each time it tells: the GitHub view's bar's
  /// Refresh and ⌘R.
  final Listenable? refreshes;

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
  ViewPoll? _poll;

  /// When GitHub last answered, and whether the quiet poll after it
  /// failed: what shows is then that answer, "as of" its time (ADR 0046).
  DateTime? _okAt;
  bool _failed = false;
  late PullSection _tab = _tabLeft[_refKey] ?? PullSection.overview;
  String get _refKey =>
      '${widget.ref.host} ${widget.ref.repo} ${widget.ref.number}';
  final _scroll = ScrollController();
  final GlobalKey _tabs = GlobalKey();
  final _mergeKey = GlobalKey<MergeCardState>();
  final _threadKeys = <String, GlobalKey<PullThreadState>>{};
  final _reviewKeys = <String, GlobalKey>{};
  CommentFilter _filter = CommentFilter.all;
  late final PullCommits _commits = PullCommits(widget.daemon, widget.ref);

  /// The head's title row, which the slim bar watches.
  final GlobalKey _title = GlobalKey();

  /// Who the user is on its host ('' until known).
  String _me = '';

  bool get _inChat => widget.source != null;

  @override
  void initState() {
    super.initState();
    if (widget.source case final s?) {
      // Read whole while the tab shows (ADR 0140): asked as it opens,
      // unless it was a moment ago.
      s
        ..addListener(_sourceChanged)
        ..showTab();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) s.markSeen();
      });
    } else {
      unawaited(_load());
      // As every pull poll's pace (ADR 0140): each minute, every 15 once
      // merged or closed; only while seen (a view's poll, ADR 0046), and
      // re-armed after each load, so its state picks the next wait.
      _poll = viewPoll(
        () => pullPoll(_pull),
        () => unawaited(_load(quiet: true)),
      );
    }
    unawaited(
      githubLogin(widget.daemon, widget.ref.host).then((me) {
        if (mounted) setState(() => _me = me);
      }),
    );
    _redraw.addListener(_changed);
    minuteClock.addListener(_changed); // "Updated 2m ago" moves on
    widget.refreshes?.addListener(_refreshed);
  }

  /// The bar's Refresh (or ⌘R) under way: another press while it asks
  /// joins it, as the chat's tab's does, rather than asking again.
  Future<void>? _refreshing;

  /// The bar's Refresh still shown working: the line is busy for
  /// [Waits.refreshShown] at least, as the chat's tab's is; another press
  /// in that time changes nothing.
  Timer? _shown;

  void _refreshed() {
    if (_shown != null) return;
    setState(
      () => _shown = Timer(Waits.refreshShown, () {
        setState(() => _shown = null);
      }),
    );
    if (_refreshing != null) return;
    _refreshing = _load().whenComplete(() => _refreshing = null);
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
    widget.source
      ?..removeListener(_sourceChanged)
      ..hideTab();
    _redraw.removeListener(_changed);
    minuteClock.removeListener(_changed);
    widget.refreshes?.removeListener(_refreshed);
    _shown?.cancel();
    _poll?.cancel();
    _scroll.dispose();
    _commits.dispose();
    super.dispose();
  }

  /// Asks for the pull request again (it changed here): the chat's, or
  /// the pane's own.
  Future<void> _refresh() async {
    final s = widget.source;
    if (s == null) return await _load();
    await s.again();
  }

  /// The newest [_load]'s number: an older answer (a poll overtaken by the
  /// reload after a merge or a post) is dropped.
  int _asked = 0;

  Future<void> _load({bool quiet = false}) async {
    final n = ++_asked;
    // Its line says so ("· refreshing"); true already as it opens.
    if (!_asking) setState(() => _asking = true);
    try {
      final r = await widget.daemon.client.getGitHubPull(
        GetGitHubPullRequest(ref: widget.ref, quiet: quiet),
      );
      if (n != _asked) return;
      keepPull(widget.ref, r.pull);
      if (mounted) {
        setState(() {
          _pull = r.pull;
          _keptAt = null;
          _okAt = clock();
          _failed = false;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted && n == _asked && _pull != null) {
        // A failed ask (a poll or the bar's Refresh) keeps what shows,
        // saying it's from then, as the chat's tab does.
        setState(() {
          _keptAt ??= _okAt;
          _failed = _keptAt != null;
          _error = errorText(e); // the failure line's tooltip, else shown
        });
      } else if (mounted && n == _asked) {
        setState(() => _error = errorText(e));
      }
    } finally {
      if (mounted && n == _asked && _asking) {
        setState(() => _asking = false);
      }
      if (mounted && n == _asked) _poll?.again();
    }
  }

  /// Scrolls [key]'s widget into view, after this frame: up to the slim
  /// bar's bottom, as the bar shows once the head has gone.
  void _toView(GlobalKey key) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final to = key.currentContext?.findRenderObject();
        final port = to == null ? null : RenderAbstractViewport.maybeOf(to);
        if (to == null || port == null || !_scroll.hasClients) return;
        final at = _scroll.position;
        final y = (port.getOffsetToReveal(to, 0).offset - pullBarHeight).clamp(
          at.minScrollExtent,
          at.maxScrollExtent,
        );
        if (reduceMotion(context)) {
          _scroll.jumpTo(y);
        } else {
          _scroll.animateTo(
            y,
            duration: Motion.standard,
            curve: Curves.easeOutCubic,
          );
        }
      });

  /// Shows tab [s], scrolled up to the tabs.
  void _jump(PullSection s) {
    setState(() => _tab = s);
    _toView(_tabs);
  }

  /// The bar's Merge status: the card, its first segment not met open.
  void _mergeStatus() {
    setState(() => _tab = PullSection.overview);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _mergeKey.currentState?.reveal(),
    );
    _toView(_mergeKey);
  }

  /// A thread's row in the merge status card: the thread, open.
  void _showThread(GitHubThread x) {
    setState(() {
      if (_filter == CommentFilter.mine) _filter = CommentFilter.all;
    });
    final key = _threadKey(x.id);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => key.currentState?.show(),
    );
    _toView(key);
  }

  /// A finding's row: the review it's in.
  void _showReview(String id) {
    setState(() => _filter = CommentFilter.all);
    _toView(_reviewKey(id));
  }

  GlobalKey<PullThreadState> _threadKey(String id) =>
      _threadKeys.putIfAbsent(id, GlobalKey<PullThreadState>.new);
  GlobalKey _reviewKey(String id) => _reviewKeys.putIfAbsent(id, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final (
      pull,
      keptAt,
      readAt,
      asking,
      error,
      failed,
    ) = switch (widget.source) {
      final s? => (s.pull, s.keptAt, s.readAt, s.busy, s.error, s.failed),
      null => (
        _pull,
        _keptAt,
        _keptAt ?? _okAt,
        _asking || _shown != null,
        _error,
        _failed,
      ),
    };
    final p = pull;
    if (p == null) {
      if (error == null) return const PullSkeleton();
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(error, style: theme.ui(t.crashed)),
            // Nothing read yet, so no line to hold it: the tab's Refresh
            // goes under the error, where it's wanted most.
            if (widget.source case final s?) _refreshButton(s),
          ],
        ),
      );
    }
    if (_tab == PullSection.overview || _tab == PullSection.commits) {
      _commits.want(p.headOid);
    }
    final failing = p.checks.where((c) => c.kind == CheckKind.failed).length;
    final todo = todoOf(p);
    final open = p.item.state == 'open';
    return LayoutBuilder(
      builder: (context, box) {
        final pad = pullPad(box.maxWidth);
        final narrow = box.maxWidth < pullNarrow;
        Widget column(Widget child, {double top = 0, double bottom = 0}) =>
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, top, pad, bottom),
              sliver: SliverToBoxAdapter(child: child),
            );
        Widget actions() => PullActions(
          pull: p,
          narrow: narrow,
          actions: _actions(context, p),
          onMergeStatus: open && mergeView(p) != null ? _mergeStatus : null,
        );
        // The slim bar lies over the scroll's top, so it comes and goes
        // without moving the page.
        return Stack(
          children: [
            Positioned.fill(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  // How fresh it is, always (docs/design.md's state cues):
                  // "Updated 2m ago", "· refreshing" while it's asked, the
                  // failure's line once an ask failed.
                  if (updatedLine(readAt, loading: asking, failed: failed)
                      case final line?)
                    column(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 2,
                          children: [
                            Flexible(
                              child: _fresh(
                                context,
                                line,
                                failed && !asking,
                                error,
                              ),
                            ),
                            // The tab has no bar: its Refresh is here
                            // (the GitHub view's is in its bar).
                            if (widget.source case final s?) _refreshButton(s),
                          ],
                        ),
                      ),
                      top: _inChat ? 4 : 8,
                    ),
                  column(
                    PullHeader(
                      daemon: widget.daemon,
                      pull: p,
                      onSaved: _refresh,
                      titleKey: _title,
                      actions: actions(),
                    ),
                    top: readAt == null ? 24 : (_inChat ? 0 : 4),
                  ),
                  if (error case final e? when !failed)
                    column(
                      Text(
                        'Not current: $e',
                        style: theme.ui(t.needs, size: 12),
                      ),
                      top: 6,
                    ),
                  column(
                    Column(
                      key: _tabs,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: PlainTabs(
                              value: _tab,
                              tabs: [
                                (PullSection.overview, 'Overview'),
                                (PullSection.commits, 'Commits  ${p.commits}'),
                                (
                                  PullSection.checks,
                                  failing > 0
                                      ? 'Checks  $failing failing'
                                      : 'Checks  ${p.checks.length}',
                                ),
                                (
                                  PullSection.files,
                                  'Files changed  ${p.changedFiles}',
                                ),
                              ],
                              onChanged: _jump,
                            ),
                          ),
                        ),
                        Divider(height: 1, thickness: 1, color: t.line),
                      ],
                    ),
                    top: 16,
                    bottom: 20,
                  ),
                  switch (_tab) {
                    PullSection.commits => column(
                      PullCommitsList(commits: _commits),
                      bottom: 24,
                    ),
                    PullSection.checks => column(
                      GitHubChecks(
                        daemon: widget.daemon,
                        pull: p,
                        onChanged: _refresh,
                      ),
                      bottom: 20,
                    ),
                    PullSection.files => SliverToBoxAdapter(
                      // The window's height, under the tabs: the list and
                      // the diff scroll in it.
                      child: SizedBox(
                        height: box.maxHeight - 84,
                        child: GitHubFiles(
                          daemon: widget.daemon,
                          pull: p,
                          onChanged: _refresh,
                        ),
                      ),
                    ),
                    PullSection.overview => column(
                      PullOverview(
                        daemon: widget.daemon,
                        pull: p,
                        todo: todo,
                        me: _me,
                        narrow: narrow,
                        commits: _commits,
                        filter: _filter,
                        onFilter: (f) => setState(() => _filter = f),
                        onChanged: _refresh,
                        onCommits: () => _jump(PullSection.commits),
                        onThread: _showThread,
                        onReview: _showReview,
                        mergeKey: _mergeKey,
                        threadKeys: _threadKey,
                        reviewKeys: _reviewKey,
                        stale: keptAt != null,
                        sideTop: _inChat
                            ? null
                            : ItemChats(widget.daemon, p.item.ref),
                      ),
                      bottom: 48,
                    ),
                  },
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: StickyPullBar(
                scroll: _scroll,
                titleKey: _title,
                bar: PullBar(pull: p, pad: pad, actions: actions()),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The chat's tab's Refresh (the GitHub view's is in its bar).
  Widget _refreshButton(ChatPull s) => IconTap(
    Icons.refresh,
    key: const ValueKey('pull-refresh'),
    tooltip: withKey('Refresh', cmdLabel(LogicalKeyboardKey.keyR)),
    onTap: s.refreshAsked,
  );

  /// The page's line ([updatedLine]), spinning while it's asked; a failed
  /// one says why on hover.
  Widget _fresh(BuildContext context, String line, bool failed, String? why) {
    final text = updatedText(
      context,
      line,
      failed: failed,
      busy: line.endsWith(refreshingWords),
      size: 11.5,
      key: const ValueKey('pull-kept'),
    );
    return failed && why != null ? tooltip(context, why, text) : text;
  }

  /// The bar's buttons: Start work (the GitHub view), Submit review.
  List<Widget> _actions(BuildContext context, GitHubPull p) {
    final it = p.item;
    final pending = p.pendingComments + reviewDrafts(it.ref).length;
    return [
      if (!_inChat) StartWork(daemon: widget.daemon, item: it),
      Button(
        label: pending > 0 ? 'Submit review ($pending)' : 'Submit review',
        tooltip: 'Comment, approve or request changes',
        onPressed: () => _review(context, p),
      ),
    ];
  }

  /// Opens the review dialog; who I am is asked then, as a token changed
  /// in Settings while this pane shows can be another account's.
  Future<void> _review(BuildContext context, GitHubPull p) async {
    final me = await githubLogin(widget.daemon, p.item.ref.host);
    if (!context.mounted) return;
    await submitReview(
      context,
      widget.daemon,
      p,
      onDone: _refresh,
      mine: me.isNotEmpty && me.toLowerCase() == p.item.author.toLowerCase(),
    );
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

/// What blocks [p]'s merge for the agent ([todo]), with the bots' findings
/// when Settings reads them.
Todo todoOf(GitHubPull p) => todo(
  p,
  findings: githubFindings.value
      ? findingsSetup(githubFindingBots.value, githubFindingHeadings.value)
      : null,
);
