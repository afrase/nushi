import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/picker.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_view.dart';
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
final List<String> recentRows = runList();

/// ⌘K: the palette. The chats (the pinned first, then the last opened
/// first), the actions that apply now ([appActions], the shown chat's
/// among them), then the archived chats; what's picked runs once it
/// closes.
Future<void> showPalette(BuildContext context, Daemon d) async {
  // Its rows act on what the Restart screen hides.
  if (d.blocked) return;
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
    routeSettings: Picker.palette.settings,
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
    () => chat.openInFiles(f),
    detail: fileDetail(f, fileChanged(absoluteIn(chat.folder, f))),
    icon: Icons.description_outlined,
  );
  final picked = await showDialog<PaletteRow>(
    context: context,
    routeSettings: Picker.artifacts.settings,
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
  if (!chat.panelFits()) {
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
  final hits = [
    for (final r in rows)
      if (matchesWords('${r.title} ${r.detail}', q)) r,
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

/// The palette's keys as its field's tooltip names them: ⌘K, or ⇧⌘P (in
/// a terminal too) while both are bound; one alone, or '' for none.
String get _paletteKeys =>
    switch ((keyLabel(paletteKey), keyLabel(paletteKeyToo))) {
      ('', '') => '',
      (final one, '') || ('', final one) => one,
      (final first, final second) => '$first, or $second (in a terminal too)',
    };

/// The palette: [rows] in a [PickBox], matched as [matchRows] says, its
/// keys at the field's end. ⌘K's, and Artifacts…'s with its own [hint].
class Palette extends StatelessWidget {
  const new({
    required this.rows,
    super.key,
    this.hint = 'Go to a chat or run an action…',
  });

  final List<PaletteRow> rows;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return PickBox<PaletteRow>(
      rows: rows,
      rank: matchRows,
      hint: hint,
      empty: 'Nothing matches',
      suffix: switch (_paletteKeys) {
        '' => null,
        final keys => tooltip(
          context,
          'The palette: $keys',
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: keyText(
              keyLabel(paletteKey).isEmpty
                  ? keyLabel(paletteKeyToo)
                  : keyLabel(paletteKey),
              theme.code(t.textMuted, size: 12),
            ),
          ),
        ),
      },
      row: (context, r) => Row(
        children: [
          SizedBox(
            width: 22,
            child: r.agent == null
                ? Icon(r.icon, size: 14, color: t.textMuted)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: AgentMark(r.agent!, size: 13),
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
            // A key in monospace, which has ⌘ and the other marks.
            if (r.agent == null && r.icon == Icons.bolt)
              keyText(r.detail, theme.code(t.textMuted, size: 12))
            else
              Text(r.detail, style: theme.ui(t.textMuted, size: 12)),
          ],
        ],
      ),
    );
  }
}

/// The pickers' one box: the palette's, Artifacts…'s, Open file…'s and
/// the rewind list's. A field (its [icon], [hint] and [suffix]), and under
/// it the [rows] that [rank] keeps for what's typed, each drawn by [row]
/// in a lazy list [rowHeight] high a row, [shownRows] showing before it
/// scrolls. ↑↓ move the selection, kept in view; ⏎ or a click picks (the
/// dialog pops with the row); Esc closes. [status], given, shows in the
/// rows' place (a turn to stop first), [empty] when none match, and
/// [footer] under it all.
class PickBox<T extends Object> extends StatefulWidget {
  const new({
    required this.rows,
    required this.rank,
    required this.row,
    required this.hint,
    super.key,
    this.icon = Icons.search,
    this.suffix,
    this.rowHeight = 28,
    this.rowPadding = const EdgeInsets.symmetric(horizontal: 8),
    this.status,
    this.empty,
    this.footer,
  });

  final List<T> rows;

  /// The rows that show for a query, the best first.
  final List<T> Function(List<T> rows, String query) rank;
  final Widget Function(BuildContext context, T row) row;
  final String hint;
  final IconData icon;
  final Widget? suffix;
  final double rowHeight;
  final EdgeInsetsGeometry rowPadding;
  final String? status;
  final String? empty;
  final Widget? footer;

  /// How many rows show before the list scrolls.
  static const shownRows = 12;

  @override
  State<PickBox<T>> createState() => _PickBoxState<T>();
}

class _PickBoxState<T extends Object> extends State<PickBox<T>> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  int _at = 0;

  /// The rows ranked last, and for which rows and query: a key and the
  /// build after it rank once.
  (List<T>, String, List<T>)? _ranked;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<T> get _shown {
    if (widget.status != null) return <T>[];
    final q = _text.text;
    if (_ranked case (final rows, final query, final shown)
        when identical(rows, widget.rows) && query == q) {
      return shown;
    }
    final shown = widget.rank(widget.rows, q);
    _ranked = (widget.rows, q, shown);
    return shown;
  }

  void _move(int at, [int _ = 0]) {
    setState(() => _at = at);
    revealRowAt(_scroll, at, widget.rowHeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final shown = _shown;
    _at = _at.clamp(0, shown.isEmpty ? 0 : shown.length - 1);
    final note = widget.status ?? (shown.isEmpty ? widget.empty : null);
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
                onKeyEvent: (_, e) {
                  final shown = _shown;
                  return pickKey(
                    e,
                    count: shown.length,
                    at: _at,
                    move: _move,
                    pick: () => Navigator.pop(context, shown[_at]),
                  );
                },
                skipTraversal: true,
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  style: theme.ui(t.text),
                  onChanged: (_) => _move(0),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    border: InputBorder.none,
                    prefixIcon: Icon(widget.icon, size: 15),
                    prefixIconConstraints: const BoxConstraints(minWidth: 28),
                    suffixIcon: widget.suffix,
                    suffixIconConstraints: const BoxConstraints(),
                  ),
                ),
              ),
              const Divider(height: 9),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(note, style: theme.ui(t.textMuted)),
                )
              else if (shown.isNotEmpty)
                SizedBox(
                  height:
                      widget.rowHeight *
                      shown.length.clamp(1, PickBox.shownRows),
                  child: ListView.builder(
                    controller: _scroll,
                    itemExtent: widget.rowHeight,
                    itemCount: shown.length,
                    itemBuilder: (context, i) => Tap(
                      onTap: () => Navigator.pop(context, shown[i]),
                      selected: i == _at,
                      padding: widget.rowPadding,
                      child: widget.row(context, shown[i]),
                    ),
                  ),
                ),
              if (widget.footer case final footer?) ...[
                const Divider(height: 9),
                footer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
