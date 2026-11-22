import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/artifacts_widget.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/context_report.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/mcp_widget.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_widget.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/worktree.dart';
import 'package:nushi/worktrees_widget.dart';

/// The panel beside a chat: widgets for its environment (folder or
/// repository, branch, worktree), its context and cost, and its folder's
/// changes (uncommitted, or the branch's for a worktree chat), as the
/// Changes view shows them, its subagents' worktrees, its background tasks,
/// MCP servers and artifacts.
/// They reload when a turn ends or the chat moves.
///
/// Another chat picked, the last one's rows stay until the new one's are
/// known ([Waits.handover] at most), dimmed past [Waits.loading] as what's
/// on its way out; then they fade out and the new one's fade in, as
/// they'll stay, the two never over each other:
/// no rows blank, none saying "Not reported yet" or "…" a moment, none
/// folding and growing as the numbers come.
class DetailsPanel extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onChanges,
    super.key,
    this.onPull,
  });

  /// Its one width (ADR 0092): Claude Code's rail's, which holds the
  /// longest Context row ("MCP server instructions", its count and share)
  /// and the pull request's merge control at the panel's type.
  static const width = 320.0;

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChanges;

  /// Shows the chat's pull request's tab.
  final VoidCallback? onPull;

  @override
  State<DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<DetailsPanel> {
  /// The panel whose rows show while [widget]'s chat's wait unseen.
  DetailsPanel? _leaving;

  /// The last chat whose rows showed.
  ChatState? _shown;

  /// Whether [_leaving]'s rows are dimmed: the wait went past
  /// [Waits.loading].
  bool _dim = false;
  Timer? _dimming;

  /// Whether [_leaving]'s rows fade out: the current chat's are known.
  bool _out = false;

  @override
  void didUpdateWidget(DetailsPanel old) {
    super.didUpdateWidget(old);
    if (old.chat == widget.chat) return;
    // What shows stays: the last chat's rows if they showed, or else what
    // already stayed for them.
    if (_shown == old.chat) _leaving = old;
    if (_leaving?.chat == widget.chat) _leaving = null;
    if (_leaving == null) {
      _settle();
    } else {
      _dimming ??= Timer(Waits.loading, () {
        if (mounted) setState(() => _dim = true);
      });
    }
  }

  @override
  void dispose() {
    _dimming?.cancel();
    super.dispose();
  }

  void _settle() {
    _dimming?.cancel();
    _dimming = null;
    _dim = false;
    _out = false;
  }

  void _onReady(ChatState chat) {
    if (!mounted || chat != widget.chat || _leaving == null) return;
    setState(() => _out = true);
  }

  void _onShown(ChatState chat) {
    if (!mounted || chat != widget.chat) return;
    setState(() {
      _shown = chat;
      _leaving = null;
      _settle();
    });
  }

  /// [of]'s rows, keyed by its chat at the wrapper: they keep their state
  /// as they go from the current to the leaving.
  Widget _details(DetailsPanel of, {required bool current}) => AnimatedOpacity(
    key: ObjectKey(of.chat),
    opacity: current
        ? 1
        : _out
        ? 0
        : _dim
        ? 0.5
        : 1,
    duration: reduceMotion(context) ? Duration.zero : Motion.standard,
    // Fading out, it's gone before the current chat's fade in.
    curve: !current && _out ? _ChatDetails.before : Curves.linear,
    child: _ChatDetails(
      chat: of.chat,
      daemon: of.daemon,
      onChanges: of.onChanges,
      onPull: of.onPull,
      handover: current && _leaving != null,
      onShown: current ? _onShown : null,
      onReady: current ? _onReady : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final leaving = _leaving;
    // The pane's own fill under both (ADR 0111): opaque, as it slides in
    // over the transcript.
    return ColoredBox(
      color: NushiTheme.of(context).t.base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (leaving != null) _details(leaving, current: false),
          _details(widget, current: true),
        ],
      ),
    );
  }
}

/// [DetailsPanel]'s rows for one chat.
class _ChatDetails extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onChanges,
    required this.onPull,
    required this.handover,
    required this.onShown,
    required this.onReady,
  });

  /// The parts of a handover's [Motion.standard]: the last chat's rows
  /// fade out in the first, the new one's fade in in the rest.
  static const before = Interval(0, 0.4);
  static const after = Interval(0.4, 1);

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChanges;
  final VoidCallback? onPull;

  /// Whether another chat's rows show meanwhile: it may wait longer.
  final bool handover;

  /// Its rows show in full: from the frame after, or once they faded in.
  final void Function(ChatState chat)? onShown;

  /// What its rows say is known, from the frame after: they fade in.
  final void Function(ChatState chat)? onReady;

  @override
  State<_ChatDetails> createState() => _ChatDetailsState();
}

class _ChatDetailsState extends State<_ChatDetails> with FollowsChanges {
  @override
  ChatState get chat => widget.chat;
  @override
  Daemon get daemon => widget.daemon;
  GetFolderStatusResponse? _status; // counted as the Changes view shows
  Scope _scope = Scope.uncommitted;
  List<Commit> _commits = []; // in Commits
  ListBranchesResponse? _branches; // for the Branch row's menu
  String? _error;
  late GetContextUsageResponse? _context = lastContext(chat.id)?.$2;
  Timer? _timer;
  bool _asking = false;
  bool _couldAsk = false; // the last time the chat changed
  late ChatPull _pull;

  // What it shows waits, briefly, for what it says to be known (the
  // chat's snapshot, its folder's status), its rows unseen meanwhile
  // (another chat's showing under them, if any): a chat just opened
  // doesn't flash "Not reported yet" and "…" for a frame or two, its rows
  // folding and growing again as the numbers come.
  bool _ready = false;
  Timer? _waiting;

  bool get _known => chat.loaded && (_status != null || _error != null);

  /// Whether its rows show: once what they say is known, or it waited
  /// long enough (Waits.slow, or Waits.handover over another chat's), from
  /// then on.
  bool _shows() {
    if (_ready) return true;
    if (!_known && _waiting!.isActive) return false;
    _waiting!.cancel();
    // There at once (known as it's first built, or Reduce Motion): shown
    // from the frame after. Else once it faded in ([_rows]).
    if (widget.onShown case final shown?
        when !_built || reduceMotion(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => shown(chat));
    }
    if (widget.onReady case final ready?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ready(chat));
    }
    return _ready = true;
  }

  /// Whether it was built before: rows known only since fade in.
  bool _built = false;

  /// [rows] unseen until [_shows], then fading in: over [Motion.quick],
  /// or after the last chat's fade out in a handover.
  Widget _rows(Widget rows) {
    final shows = _shows();
    _built = true;
    return AnimatedOpacity(
      opacity: shows ? 1 : 0,
      duration: reduceMotion(context)
          ? Duration.zero
          : widget.handover
          ? Motion.standard
          : Motion.quick,
      curve: widget.handover ? _ChatDetails.after : Curves.linear,
      // Under Reduce Motion there at once, and shown from the frame after
      // ([_shows]): its end comes as it's built.
      onEnd: () {
        if (_ready && !reduceMotion(context)) widget.onShown?.call(chat);
      },
      child: rows,
    );
  }

  /// Whether the agent can be asked what fills its context: the daemon
  /// says so, and the chat is idle.
  bool get _canAsk => chat.canAskContext && !chat.busy && !chat.archived;

  /// Whether Compact session is offered: the agent lists a `compact`
  /// command (Claude's) and the chat isn't archived. It works while the
  /// chat is idle ([_canCompact]).
  bool get _compactable =>
      !chat.archived && chat.commands.any((c) => c.name == 'compact');

  /// Whether Compact works now: it's offered and the chat is idle.
  bool get _canCompact => _compactable && !chat.busy;

  /// Has the agent compact its context, as `/compact` typed would.
  void _compact() => unawaited(
    tryOrShow(
      context,
      () => daemon.sendPrompt(
        SendPromptRequest(chatId: chat.id, text: '/compact'),
      ),
    ),
  );

  /// Asks the agent, unseen, what fills its context.
  Future<void> _askContext() async {
    if (mounted) setState(() => _asking = true);
    try {
      final r = await daemon.client.getContextUsage(
        GetContextUsageRequest(chatId: chat.id),
      );
      askedContext(chat.id, r);
      if (mounted) setState(() => _context = r);
    } on Object {
      // The widget keeps what it had; it asks again after the next turn.
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  /// Asks on its own whenever the chat is idle, the Context widget open or
  /// not (so it's there when opened): a moment after a turn ends or the
  /// chat becomes askable (woken, its commands listed), at most once a
  /// minute.
  void _schedule() {
    _timer?.cancel();
    bool ready() => mounted && _canAsk;
    if (!ready()) return;
    final last = contextAskedAt(chat.id);
    var wait = const Duration(seconds: 1);
    if (last != null) {
      final next = last.add(const Duration(minutes: 1)).difference(clock());
      if (next > wait) wait = next;
    }
    _timer = Timer(wait, () {
      if (ready()) unawaited(_askContext());
    });
  }

  /// The chat became askable (idle, awake, its commands listed): ask.
  void _onChat() {
    final can = _canAsk;
    if (can && !_couldAsk) _schedule();
    _couldAsk = can;
  }

  @override
  void initState() {
    super.initState();
    _couldAsk = _canAsk;
    chat.addListener(_onChat);
    _pull = ChatPull.of(daemon, chat)..follow();
    // Past it, the rows show with what they have.
    _waiting = Timer(widget.handover ? Waits.handover : Waits.slow, () {
      if (mounted && !_ready) setState(() {});
    });
  }

  @override
  void dispose() {
    _waiting?.cancel();
    _timer?.cancel();
    chat.removeListener(_onChat);
    _pull.unfollow();
    super.dispose();
  }

  /// The folder's branches and worktrees, for the Branch row's menu: asked
  /// with the rest, and again as the menu opens.
  Future<void> _listBranches() async {
    try {
      final r = await daemon.client.listBranches(
        ListBranchesRequest(folder: chat.folder),
      );
      if (mounted) setState(() => _branches = r);
    } on Object catch (e) {
      // Outside git, or gone: the menu says Loading… until asked again.
      reloadFailed(e);
    }
  }

  @override
  Future<void> reload() async {
    _schedule();
    unawaited(_listBranches());
    try {
      final span = await ChangeSpan.of(daemon, chat);
      if (mounted) {
        setState(() {
          _status = span.status;
          _scope = span.scope;
          _commits = span.commits;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
      reloadFailed(e);
    }
  }

  // Live with the chat (usage, subagents), not only when a turn ends; and
  // with its side chat coming and going (its line follows its usage).
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([chat, chat.side, _pull, chat.related]),
    builder: (context, _) => _panel(chat.side.value),
  );

  /// The Context widget's line for [side], the chat's side chat: its own
  /// meter and cost, always under the chat's, so neither changes meaning
  /// with the focus. What fills it isn't asked: the breakdown is the chat's.
  (String, Object) _sideRow(ChatState side) => (
    'Side chat',
    ListenableBuilder(
      listenable: side,
      builder: (context, _) {
        final theme = NushiTheme.of(context);
        final t = theme.t;
        final u = side.usage;
        final spent = cost(u);
        if (u.contextSize == 0 && spent.isEmpty) {
          return Text(
            'Not reported yet',
            style: theme.ui(t.textMuted, size: 12),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            if (u.contextSize > 0)
              tooltip(
                context,
                '${tokens(u.contextUsed.toInt())} / '
                '${tokens(u.contextSize.toInt())}',
                ContextMeter(u),
              ),
            if (spent.isNotEmpty)
              Text(spent, style: theme.ui(t.text, size: 12)),
          ],
        );
      },
    ),
  );

  Widget _panel(ChatState? side) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final u = chat.usage;
    final status = _status;
    final muted = theme.ui(t.textMuted, size: 12);
    final commits = _scope == Scope.commits;
    final unread = switch (_context) {
      final c? => c.categories.isEmpty && c.markdown.isNotEmpty,
      null => false,
    };
    final (added, removed) = commits
        ? _commits.fold((0, 0), (n, c) => (n.$1 + c.added, n.$2 + c.removed))
        : (status?.added ?? 0, status?.removed ?? 0);
    final lines = status == null || !status.git
        ? null
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '+$added', style: theme.code(t.done, size: 12)),
                TextSpan(
                  text: '  −$removed',
                  style: theme.code(t.crashed, size: 12),
                ),
              ],
            ),
          );
    // The cards lie on the pane's own fill (ADR 0111), which hides the
    // last chat's rows once these show.
    return _rows(
      ColoredBox(
        color: t.base,
        child: PanelWidgets([
          PanelWidget(
            title: 'Environment',
            summary: Text(
              folderParts(chat.home, scratch: chat.scratch).$1,
              style: muted,
              overflow: TextOverflow.ellipsis,
            ),
            rows: [
              (
                chat.worktree == null ? 'Folder' : 'Repository',
                FolderButton(chat: chat, daemon: daemon, stacked: true),
              ),
              if (status != null && status.git)
                ...worktreeRows(
                  context,
                  chat,
                  daemon,
                  status.branch,
                  list: _branches,
                  onOpen: () => unawaited(_listBranches()),
                  onChanged: () => unawaited(reload()),
                  onChanges: widget.onChanges,
                ),
              if (status != null && status.gone)
                (
                  null,
                  Text(
                    chat.worktree == null
                        ? 'The folder is gone.'
                        : 'Its worktree was removed. Delete the chat to clean '
                              'up its branch ${chat.worktree!.branch}.',
                    style: theme.ui(t.crashed, size: 12),
                  ),
                ),
            ],
          ),
          PanelWidget(
            title: 'Context',
            // Nothing to show yet: one line.
            note:
                side == null &&
                    u.contextSize == 0 &&
                    cost(u).isEmpty &&
                    lastTurn(u).isEmpty &&
                    _context == null &&
                    !_asking
                ? 'Not reported yet'
                : null,
            summary: ContextMeter(u, breakdown: _context),
            rows: [
              if (u.contextSize == 0 && cost(u).isEmpty && _context == null)
                (null, 'Not reported yet'),
              // As Claude's rail: the line, the bar, what fills it.
              if (u.contextSize > 0 || _context != null)
                (
                  null,
                  ContextReport(
                    u,
                    // As last asked, brought up to the agent's latest count.
                    categories: liveCategories(_context?.categories ?? [], u),
                    lists: unread ? const [] : _context?.lists ?? const [],
                    compactable: _compactable,
                    onCompact: _canCompact ? _compact : null,
                  ),
                ),
              // An answer the daemon couldn't read kinds from: as the agent
              // wrote it, under the line and the bar.
              if (unread) (null, AgentMarkdown(_context!.markdown)),
              // Why there's no breakdown yet, for an agent that can say.
              if (_context == null &&
                  (_asking || u.contextSize > 0 && chat.canAskContext))
                (
                  null,
                  _asking
                      ? 'Asking what fills it…'
                      : chat.asleep
                      ? 'What fills it, once the chat is awake'
                      : chat.busy
                      ? 'What fills it, after this turn'
                      : 'What fills it, in a moment',
                ),
              if (lastTurn(u).isNotEmpty)
                (
                  'Last turn',
                  tooltip(
                    context,
                    cacheUse(u).isEmpty ? '' : 'Cache: ${cacheUse(u)}',
                    Text(lastTurn(u), style: theme.ui(t.text, size: 12)),
                  ),
                ),
              if (cost(u).isNotEmpty)
                ('Cost', Text(cost(u), style: theme.ui(t.text, size: 12))),
              if (side != null) _sideRow(side),
            ],
          ),
          PanelWidget(
            title: 'Changes',
            note: _error == null && status != null && !status.git
                ? (status.gone ? 'The folder is gone' : 'Not a git repository')
                : null,
            summary: lines,
            onTap: status != null && status.git ? widget.onChanges : null,
            rows: [
              if (_error != null)
                (null, _error!)
              else if (status == null)
                (null, '…')
              else if (!status.git)
                (
                  null,
                  status.gone ? 'The folder is gone' : 'Not a git repository',
                )
              else ...[
                (_scope.label, lines!),
                if (commits)
                  ('Number', _commits.isEmpty ? 'None' : '${_commits.length}')
                else
                  ('Files', status.files == 0 ? 'None' : '${status.files}'),
              ],
            ],
          ),
          ?pullWidget(_pull, onShow: widget.onPull),
          ?worktreesWidget(chat, onChanges: widget.onChanges),
          ?backgroundTasksWidget(chat, daemon),
          mcpWidget(chat, daemon),
          ?artifactsWidget(chat),
        ]),
      ),
    );
  }
}
