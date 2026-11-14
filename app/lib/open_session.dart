import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/session_rows.dart';
import 'package:nushi/session_search.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

export 'package:nushi/session_rows.dart' show mayOpen;

/// The agents found not to list their sessions, while the app runs: the
/// New chat dialog offers them no "Sessions →".
final Set<String> cantListSessions = runSet();

/// The New chat dialog's second step: [agent]'s sessions in [folder] ('':
/// every folder's) that aren't chats, newest first, for [onOpen]. Its
/// field filters them by title, case aside: those loaded so far, as each
/// page starts the agent (More loads the next). Once typing pauses, or on
/// Enter, it also searches what was said in every session
/// (SessionSearch), listed under the titles with the text around each
/// hit. The arrows move over both, Enter opens (or searches at once, right
/// after typing), Esc (or ← with the field empty) goes [onBack].
class SessionList extends StatefulWidget {
  const new({
    required this.daemon,
    required this.agent,
    required this.folder,
    required this.onOpen,
    required this.onBack,
    super.key,
  });

  final Daemon daemon;
  final String agent;
  final String folder;
  final ValueChanged<FoundSession> onOpen;
  final VoidCallback onBack;

  @override
  State<SessionList> createState() => _SessionListState();
}

class _SessionListState extends State<SessionList> {
  final _sessions = <FoundSession>[];
  ListAgentSessionsResponse? _last;
  String? _error;
  bool _loading = false;
  int _at = 0;
  // The selected row's, to keep it in view.
  final GlobalKey<State<StatefulWidget>> _shown = GlobalKey();

  final _scroll = ScrollController();
  final _filter = TextEditingController();
  String _filtered = '';

  /// The arrows moved the selection since the field changed: Enter opens
  /// it rather than search at once.
  bool _moved = false;
  late final _search = SessionSearch(widget.daemon, widget.agent, widget.folder)
    ..addListener(_searched);

  void _searched() => setState(() {});

  /// Moves the selection, keeping it in view. Wrapped to the first or the
  /// last, the list jumps to its end: that row, away from the screen,
  /// isn't built.
  void _move(int by) {
    _moved = true;
    final to = _at + by;
    setState(() => _at = (to + _rows) % _rows);
    if (to >= 0 && to < _rows) return revealRow(_shown, down: by > 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_at == 0 ? 0 : _scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _filter.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _filter.addListener(_typed);
    unawaited(_more());
  }

  void _typed() {
    _search.typed(_filter.text);
    final text = _filter.text.trim().toLowerCase();
    if (text == _filtered) return; // the caret moved
    setState(() {
      _filtered = text;
      _at = 0;
      _moved = false;
    });
  }

  Future<void> _more() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.daemon.client.listAgentSessions(
        ListAgentSessionsRequest(
          agent: widget.agent,
          folder: widget.folder,
          cursor: _last?.nextCursor ?? '',
        ),
      );
      if (!mounted) return;
      if (!r.canList) cantListSessions.add(widget.agent);
      setState(() {
        _last = r;
        _sessions.addAll(r.sessions);
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = errorText(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasMore => _last?.nextCursor.isNotEmpty ?? false;

  /// The sessions loaded whose title says the field's text.
  List<FoundSession> get _titled => [
    for (final s in _sessions)
      if (s.title.toLowerCase().contains(_filtered)) s,
  ];

  /// The sessions the search found for what the field says.
  List<SessionHit> get _hits => _search.shown && _search.asked == _search.text
      ? _search.found?.hits ?? const []
      : const [];

  /// The rows the arrows move over: the titles shown, "More", then the
  /// sessions found.
  int get _rows => _titled.length + (_hasMore ? 1 : 0) + _hits.length;

  void _pick(int i) {
    final shown = _titled;
    final hits = _hits;
    final more = _hasMore ? 1 : 0;
    if (i < shown.length) {
      if (_why(shown[i]) == null) widget.onOpen(shown[i]);
    } else if (i < shown.length + more) {
      if (!_loading) unawaited(_more());
    } else if (_whyHit(hits[i - shown.length - more].session) == null) {
      widget.onOpen(hits[i - shown.length - more].session);
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (e.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onBack();
      case LogicalKeyboardKey.arrowLeft when _filter.text.isEmpty:
        widget.onBack();
      case LogicalKeyboardKey.arrowDown when _rows > 0:
        _move(1);
      case LogicalKeyboardKey.arrowUp when _rows > 0:
        _move(-1);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when _search.pending && !_moved:
        _search.now();
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when _rows > 0:
        _pick(_at);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final title = agentTitle(widget.agent);
    final last = _last;
    final shown = _titled;
    final hits = _hits;
    final filtering = _filtered.isNotEmpty;
    final note = switch (()) {
      _ when _error != null => _error,
      _ when last == null => 'Looking…',
      _ when !last.canList => "$title can't list its sessions.",
      _ when _sessions.isEmpty && !filtering => 'No other sessions here',
      _ => null,
    };
    final noTitle = switch (()) {
      _ when !filtering || shown.isNotEmpty || last == null => null,
      _ when _hasMore => 'No title loaded so far says “${_search.text}”',
      _ => 'No title says “${_search.text}”',
    };
    _at = _rows == 0 ? 0 : _at.clamp(0, _rows - 1);
    return Focus(
      onKeyEvent: _key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 8, 6),
            child: Row(
              children: [
                IconTap(
                  Icons.arrow_back,
                  tooltip: 'Back',
                  onTap: widget.onBack,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.folder.isEmpty
                        ? '$title sessions'
                        : '$title sessions in ${folderParts(widget.folder).$1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.text, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: TextField(
              controller: _filter,
              autofocus: true,
              style: theme.ui(t.text),
              decoration: InputDecoration(
                isDense: true,
                hintText: _search.searches
                    ? 'Filter titles, or search what was said'
                    : 'Filter by title',
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: Text(note, style: theme.ui(t.textMuted, size: 12)),
            ),
          if (shown.isNotEmpty || (_hasMore && last != null) || filtering)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView(
                controller: _scroll,
                shrinkWrap: true,
                children: [
                  if (filtering && _search.searches)
                    const SessionsHeading('Titles'),
                  if (noTitle != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                      child: Text(
                        noTitle,
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                    ),
                  for (final (i, s) in shown.indexed)
                    SessionRow(
                      s,
                      key: i == _at ? _shown : null,
                      selected: i == _at,
                      onTap: () => _pick(i),
                      everyFolder: widget.folder.isEmpty,
                      why: _why(s),
                    ),
                  if (_hasMore)
                    Tap(
                      key: _at == shown.length ? _shown : null,
                      onTap: () => _pick(shown.length),
                      selected: _at == shown.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: Text(
                        _loading ? 'Looking…' : 'More',
                        style: theme.ui(t.textSecondary, size: 12),
                      ),
                    ),
                  if (filtering) ..._said(shown.length + (_hasMore ? 1 : 0)),
                ],
              ),
            ),
          if (last != null && !last.seesOpen && shown.isNotEmpty ||
              hits.isNotEmpty && !(_search.found?.seesOpen ?? true))
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
              child: Text(
                'If one is still open in a terminal, both will write to '
                'its history.',
                style: theme.ui(t.textMuted, size: 11.5),
              ),
            ),
        ],
      ),
    );
  }

  /// The search's part of the list, its rows from [first] on: the
  /// sessions found, each with the text around its hit, or where the
  /// search stands.
  List<Widget> _said(int first) {
    final hits = _hits;
    if (!_search.searches || hits.isEmpty) return [SearchState(_search)];
    final t = NushiTheme.of(context);
    return [
      const SessionsHeading('What was said'),
      for (final (i, h) in hits.indexed)
        SessionRow(
          h.session,
          key: first + i == _at ? _shown : null,
          selected: first + i == _at,
          onTap: () => _pick(first + i),
          everyFolder: widget.folder.isEmpty,
          why: _whyHit(h.session),
          extra: h.count == 1 ? '1 mention' : '${h.count} mentions',
          below: HitExcerpt(h),
        ),
      if (_search.found?.more ?? false)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Text(
            'The search stopped early: older sessions may mention it too.',
            style: t.ui(t.t.textMuted, size: 11.5),
          ),
        ),
    ];
  }

  String? _why(FoundSession s) =>
      whyNotOpen(s, widget.agent, oneWriter: _last?.oneWriter ?? false);

  String? _whyHit(FoundSession s) =>
      whyNotOpen(s, widget.agent, oneWriter: _search.found?.oneWriter ?? false);
}
