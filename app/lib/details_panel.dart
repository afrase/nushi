import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/artifacts_widget.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_changes.dart';
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
/// They reload when a turn ends or the chat moves ([ChatChanges]).
///
/// A chat seen before shows at once, as its folder last stood. One seen
/// for the first time waits for its snapshot and its folder's status
/// ([Waits.slow] at most), its rows unseen meanwhile, then fades in; over
/// another chat's, the last one's rows stay meanwhile ([Waits.handover] at
/// most), dimmed past [Waits.loading] as what's on its way out, then fade
/// out as the new one's fade in, the two never over each other: no rows
/// blank, none saying "Not reported yet" or "…" a moment, none folding and
/// growing as the numbers come.
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

  /// The parts of a handover's [Motion.standard]: the last chat's rows
  /// fade out in the first, the new one's fade in in the rest.
  static const before = Interval(0, 0.4);
  static const after = Interval(0.4, 1);

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChanges;

  /// Shows the chat's pull request's tab.
  final VoidCallback? onPull;

  @override
  State<DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<DetailsPanel> {
  ChatChanges get _changes => ChatChanges.of(widget.daemon, widget.chat);

  /// Whether the chat's rows show: what they say is known, or the wait for
  /// it ended.
  late bool _ready = _known;

  /// The last chat's panel, whose rows show while this chat's wait.
  DetailsPanel? _leaving;

  /// Whether [_leaving]'s rows are dimmed: the wait went past
  /// [Waits.loading].
  bool _dim = false;
  Timer? _dimming;

  /// Ends the wait: past it the rows show with what they have.
  Timer? _waiting;

  /// What the rows say is known: the chat's snapshot and its folder.
  bool get _known => widget.chat.loaded && _changes.known;

  @override
  void initState() {
    super.initState();
    _listen(widget.chat, _changes);
    if (!_ready) _waiting = Timer(Waits.slow, _show);
  }

  @override
  void didUpdateWidget(DetailsPanel old) {
    super.didUpdateWidget(old);
    if (old.chat == widget.chat) return;
    _forget(old.chat, ChatChanges.of(old.daemon, old.chat));
    _listen(widget.chat, _changes);
    _waiting?.cancel();
    _dimming?.cancel();
    _dim = false;
    // Seen before: as it last stood, at once.
    if (_changes.known) {
      _ready = true;
      _leaving = null;
      return;
    }
    // What shows stays: the last chat's rows if they showed, or else what
    // already stayed for them.
    if (_ready) _leaving = old;
    if (_leaving?.chat == widget.chat) _leaving = null;
    _ready = _known;
    if (_ready) {
      _leaving = null;
      return;
    }
    _waiting = Timer(_leaving == null ? Waits.slow : Waits.handover, _show);
    if (_leaving != null) {
      _dimming = Timer(Waits.loading, () {
        if (mounted) setState(() => _dim = true);
      });
    }
  }

  @override
  void dispose() {
    _forget(widget.chat, _changes);
    _waiting?.cancel();
    _dimming?.cancel();
    super.dispose();
  }

  void _listen(ChatState chat, ChatChanges changes) {
    chat.addListener(_check);
    changes.addListener(_check);
  }

  void _forget(ChatState chat, ChatChanges changes) {
    chat.removeListener(_check);
    changes.removeListener(_check);
  }

  void _check() {
    if (!_ready && _known) _show();
  }

  /// The rows show: they fade in, after the last chat's fade out.
  void _show() {
    if (!mounted || _ready) return;
    _waiting?.cancel();
    _dimming?.cancel();
    setState(() {
      _ready = true;
      if (reduceMotion(context)) _leaving = null;
    });
  }

  /// [of]'s rows, keyed by its chat at the wrapper: they keep their state
  /// as they go from the current to the leaving.
  Widget _details(DetailsPanel of, {required bool current}) {
    final handover = _leaving != null;
    return AnimatedOpacity(
      key: ObjectKey(of.chat),
      opacity: current
          ? (_ready ? 1 : 0)
          : _ready
          ? 0
          : _dim
          ? 0.5
          : 1,
      duration: reduceMotion(context)
          ? Duration.zero
          : handover && _ready
          ? Motion.standard
          : current
          ? Motion.quick
          : Motion.standard,
      // Fading out, they're gone before the current chat's fade in.
      curve: !handover || !_ready
          ? Curves.linear
          : current
          ? DetailsPanel.after
          : DetailsPanel.before,
      onEnd: current || !_ready
          ? null
          : () {
              if (mounted) setState(() => _leaving = null);
            },
      child: _ChatDetails(
        chat: of.chat,
        daemon: of.daemon,
        onChanges: of.onChanges,
        onPull: of.onPull,
      ),
    );
  }

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

/// [DetailsPanel]'s rows for one chat, from its [ChatChanges].
class _ChatDetails extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onChanges,
    required this.onPull,
  });

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChanges;
  final VoidCallback? onPull;

  @override
  State<_ChatDetails> createState() => _ChatDetailsState();
}

class _ChatDetailsState extends State<_ChatDetails> {
  ChatState get chat => widget.chat;
  Daemon get daemon => widget.daemon;
  late final ChatChanges _changes = ChatChanges.of(daemon, chat);
  late GetContextUsageResponse? _context = lastContext(chat.id)?.$2;
  Timer? _timer;
  bool _asking = false;
  bool _couldAsk = false; // the last time the chat changed
  late ChatPull _pull;

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
    _changes
      ..follow()
      ..moved.addListener(_schedule);
    _schedule();
    _pull = ChatPull.of(daemon, chat)..follow();
  }

  @override
  void dispose() {
    _timer?.cancel();
    chat.removeListener(_onChat);
    _changes
      ..unfollow()
      ..moved.removeListener(_schedule);
    _pull.unfollow();
    super.dispose();
  }

  // Live with the chat (usage, subagents), not only when a turn ends; and
  // with its side chat coming and going (its line follows its usage).
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      chat,
      chat.side,
      _pull,
      chat.related,
      _changes,
    ]),
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
    final span = _changes.span;
    final status = span?.status;
    final scope = span?.scope ?? Scope.uncommitted;
    final spanCommits = span?.commits ?? const <Commit>[];
    final error = _changes.error;
    final muted = theme.ui(t.textMuted, size: 12);
    final commits = scope == Scope.commits;
    final unread = switch (_context) {
      final c? => c.categories.isEmpty && c.markdown.isNotEmpty,
      null => false,
    };
    final (added, removed) = commits
        ? spanCommits.fold((0, 0), (n, c) => (n.$1 + c.added, n.$2 + c.removed))
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
    return ColoredBox(
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
                list: _changes.branches,
                onOpen: () => unawaited(_changes.listBranches()),
                onChanged: () => _changes.reload().ignore(),
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
          note: error == null && status != null && !status.git
              ? (status.gone ? 'The folder is gone' : 'Not a git repository')
              : null,
          summary: lines,
          onTap: status != null && status.git ? widget.onChanges : null,
          rows: [
            if (error != null)
              (null, error)
            else if (status == null)
              (null, '…')
            else if (!status.git)
              (
                null,
                status.gone ? 'The folder is gone' : 'Not a git repository',
              )
            else ...[
              (scope.label, lines!),
              if (commits)
                (
                  'Number',
                  spanCommits.isEmpty ? 'None' : '${spanCommits.length}',
                )
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
    );
  }
}
