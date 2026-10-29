import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// One of the palette's rows: a chat to go to, or an action.
class PaletteRow {
  const new(
    this.id,
    this.title,
    this.run, {
    this.detail = '',
    this.agent,
    this.icon = Icons.bolt,
    this.pinned = false,
  });

  final String id; // 'chat:<id>', 'act:<name>': what [recentRows] keeps
  final String title;
  final String detail; // a chat's folder, an action's key
  final String? agent; // a chat's: its mark in place of [icon]
  final IconData icon;
  final VoidCallback run;

  /// A pinned chat's: first, in Pinned's order, while nothing is typed.
  final bool pinned;
}

/// What was picked in the palette lately, the newest first, while the app
/// runs: first in it when nothing is typed.
final recentRows = <String>[];

/// ⌘K: the palette. The chats (the pinned first, then the last opened
/// first), the actions that apply now ([appActions], the shown chat's
/// among them), then the archived chats; what's picked runs once it
/// closes.
Future<void> showPalette(BuildContext context, Daemon d) async {
  final shown = d.chatShows ? d.selected : null;
  // The chats the last opened first, then the newest; whatever the project.
  int opened(ChatState c) =>
      chatOpened.value[c.id] ?? c.created.millisecondsSinceEpoch;
  final live = [for (final group in chatGroups(d).values) ...group]
    ..sort((a, b) => opened(b).compareTo(opened(a)));
  final rows = [
    for (final chat in [...pinnedChats(d), ...live])
      if (chat != shown)
        PaletteRow(
          'chat:${chat.id}',
          chat.shownTitle,
          () => d.select(chat.id),
          detail: chat.scratch ? '' : baseName(chat.home),
          agent: chat.agent,
          pinned: chat.pin > 0,
        ),
    for (final a in appActions(context, d))
      if (a.enabled)
        PaletteRow(
          'act:${a.act.name}',
          a.title,
          a.run,
          detail: a.shortcut ?? '',
        ),
    // Archived chats last, marked: the sidebar doesn't list them.
    for (final chat
        in d.chats.values.where((c) => c.archived).toList()
          ..sort((a, b) => b.created.compareTo(a.created)))
      if (chat != shown)
        PaletteRow(
          'chat:${chat.id}',
          chat.shownTitle,
          () => d.select(chat.id),
          detail: [
            'archived',
            if (!chat.scratch) baseName(chat.home),
          ].join(' · '),
          agent: chat.agent,
        ),
  ];
  final picked = await showDialog<PaletteRow>(
    context: context,
    builder: (_) => Palette(rows: rows),
  );
  if (picked == null) return;

  recentRows
    ..remove(picked.id)
    ..insert(0, picked.id);
  if (recentRows.length > 20) recentRows.removeLast();
  picked.run();
}

/// The palette's Artifacts…: [chat]'s artifacts, as the header's menu
/// lists them (the pinned and recent, then the older); the one picked
/// opens in its preview.
Future<void> showArtifacts(BuildContext context, ChatState chat) async {
  final a = chatArtifacts(chat);
  PaletteRow row(String f) => PaletteRow(
    'file:$f',
    baseName(f),
    () => chat.openPreview(f),
    detail: fileDetail(f, fileChanged(absoluteIn(chat.folder, f))),
    icon: Icons.description_outlined,
  );
  final picked = await showDialog<PaletteRow>(
    context: context,
    builder: (_) => Palette(
      rows: [
        for (final f in [...a.pinned, ...a.recent, ...a.older]) row(f),
      ],
      hint: 'Open an artifact…',
    ),
  );
  picked?.run();
}

/// Artifacts…: the details panel shown on Chat, its Artifacts widget opened
/// and scrolled to; where the window has no room for the panel, the
/// palette lists them instead.
void revealArtifacts(BuildContext context, ChatState chat) {
  if (!chat.panelFits) {
    unawaited(showArtifacts(context, chat));
    return;
  }
  chat.tab.value = ChatTab.chat;
  showDetails.value = true;
  revealWidget.value = 'Artifacts';
}

/// [rows] that match [query] (each of its words in a row's title or
/// detail), the best first: a title starting with it, then a word of it,
/// then the rest; the recent before the others among equals. With no
/// query, the pinned chats first, then the recent, then the rest as they
/// are.
List<PaletteRow> matchRows(List<PaletteRow> rows, String query) {
  int recent(PaletteRow r) {
    if (r.pinned && query.trim().isEmpty) return -1; // above the recent
    final i = recentRows.indexOf(r.id);
    return i < 0 ? recentRows.length : i;
  }

  final q = query.trim().toLowerCase();
  final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final hits = [
    for (final r in rows)
      if (words.every('${r.title} ${r.detail}'.toLowerCase().contains)) r,
  ];
  int score(PaletteRow r) {
    final t = r.title.toLowerCase();
    return q.isEmpty || t.startsWith(q)
        ? 0
        : t.split(' ').any((w) => w.startsWith(q))
        ? 1
        : 2;
  }

  final order = {for (final (i, r) in hits.indexed) r: i};
  return hits..sort(
    (a, b) => switch (score(a) - score(b)) {
      0 => switch (recent(a) - recent(b)) {
        0 => order[a]! - order[b]!,
        final n => n,
      },
      final n => n,
    },
  );
}

/// The palette's box, as ⌘P's: a field, and under it the rows that match
/// what's typed. ↑↓ move, ⏎ or a click picks (the dialog pops with the
/// row), Esc closes.
class Palette extends StatefulWidget {
  const new({
    required this.rows,
    super.key,
    this.hint = 'Go to a chat or run an action…',
  });

  final List<PaletteRow> rows;
  final String hint;

  /// A row's height, and how many show before the list scrolls.
  static const rowHeight = 28.0;
  static const shownRows = 12;

  @override
  State<Palette> createState() => _PaletteState();
}

class _PaletteState extends State<Palette> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  int _at = 0;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<PaletteRow> get _shown => matchRows(widget.rows, _text.text);

  /// Moves the selection to [at], scrolling it into view.
  void _move(int at) {
    setState(() => _at = at);
    if (!_scroll.hasClients) return;
    const h = Palette.rowHeight;
    final view = _scroll.position.viewportDimension;
    if (at * h < _scroll.offset) {
      _scroll.jumpTo(at * h);
    } else if ((at + 1) * h > _scroll.offset + view) {
      _scroll.jumpTo((at + 1) * h - view);
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final shown = _shown;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp
          when shown.isNotEmpty:
        final step = e.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
        _move((_at + step) % shown.length);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when _at < shown.length:
        Navigator.pop(context, shown[_at]);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final shown = _shown;
    _at = _at.clamp(0, shown.isEmpty ? 0 : shown.length - 1);
    return Dialog(
      alignment: const Alignment(0, -0.6),
      child: SizedBox(
        width: 560,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onKeyEvent: _onKey,
                skipTraversal: true,
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  style: theme.ui(t.text),
                  onChanged: (_) => _move(0),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, size: 15),
                    prefixIconConstraints: const BoxConstraints(minWidth: 28),
                    suffixIcon: Tooltip(
                      message: 'The palette: ⌘K, or ⌘⇧P (in a terminal too)',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '⌘K',
                          style: theme.code(t.textMuted, size: 12),
                        ),
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(),
                  ),
                ),
              ),
              const Divider(height: 9),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Nothing matches', style: theme.ui(t.textMuted)),
                )
              else
                SizedBox(
                  height:
                      Palette.rowHeight *
                      shown.length.clamp(1, Palette.shownRows),
                  child: ListView.builder(
                    controller: _scroll,
                    itemExtent: Palette.rowHeight,
                    itemCount: shown.length,
                    itemBuilder: (context, i) => _row(shown[i], i == _at),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(PaletteRow r, bool selected) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Tap(
      onTap: () => Navigator.pop(context, r),
      selected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: r.agent == null
                ? Icon(r.icon, size: 14, color: t.textMuted)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: AgentMark(
                      r.agent!,
                      size: 13,
                      color: t.textSecondary,
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              r.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text),
            ),
          ),
          if (r.detail.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              r.detail,
              // A key in monospace, which has ⌘ and the other marks.
              style: r.agent == null && r.icon == Icons.bolt
                  ? theme.code(t.textMuted, size: 12)
                  : theme.ui(t.textMuted, size: 12),
            ),
          ],
        ],
      ),
    );
  }
}
