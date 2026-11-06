import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/widgets.dart';

// The preview pane's tabs (ADR 0070), in its title row in place of the file
// name when more than one tab is open: what each says, how wide it is, and
// the row. A browser tab (ADR 0094) is a tab like a file's, named for its
// page; with one in the row every tab is a chip, as Claude desktop's
// browser draws its tabs ([previewChips]).

/// What the tab of [file] says: its name, with as much of its folder as
/// tells it from the others of that name in [files] ("plan.md · docs"),
/// its bidi marks shown (plainPath).
String tabLabel(String file, List<String> files) =>
    plainPath(_label(file, files));

String _label(String file, List<String> files) {
  final name = baseName(file);
  final others = [
    for (final f in files)
      if (f != file && baseName(f) == name) folderOf(f),
  ];
  final folder = folderOf(file);
  if (others.isEmpty || folder.isEmpty) return name;
  final parts = folder.split('/');
  for (var n = 1; n < parts.length; n++) {
    final hint = parts.sublist(parts.length - n).join('/');
    if (!others.any((o) => o == hint || o.endsWith('/$hint'))) {
      return '$name · $hint';
    }
  }
  return '$name · $folder';
}

/// How narrow a tab gets before the row scrolls instead.
const double previewTabLeast = 88;

/// The text's inset in a tab, and the one file's name's in the pane's
/// title row, so the first name stays where the one file's name was.
const double previewNameInset = 5;

/// The room a tab keeps for its ✕, shown or not, so its name doesn't move.
const double _closeRoom = 18;

/// Whether [tabs] are drawn as chips: with a browser tab among them, as
/// Claude desktop's browser draws its tabs (a rounded fill, an icon, the
/// name, a ✕), a file's tab beside one a chip too so the row reads as one
/// (ADR 0094); files alone keep plain tabs (ADR 0071).
bool previewChips(List<PreviewEntry> tabs) => tabs.any((e) => e is BrowserTab);

/// The room at the ends of a title row of chips, the browser's (as
/// Claude's, a little in from the pane's edges).
const double previewChipInset = 8;

/// A chip's height, the room between chips, its icon's size and the room
/// around it, and the most a chip's name takes before it's cut: one long
/// title leaves the others their room, as Claude's chips do.
const double previewChipHeight = 28;
const double _chipGap = 4;
const double _chipIcon = 14;
const double _chipStart = 8;
const double _chipNameMost = 180;

/// How wide tabs that would like [widths] are in [room]. The widest give way
/// first, down to [previewTabLeast]; past that they add up to more than
/// [room], and the row scrolls.
List<double> fitTabs(List<double> widths, double room) {
  if (widths.fold(0.0, (a, b) => a + b) <= room) return widths;
  final narrowest = [...widths]..sort();
  var left = room;
  var most = narrowest.last;
  for (final (i, w) in narrowest.indexed) {
    final share = left / (narrowest.length - i);
    if (w >= share) {
      most = share;
      break;
    }
    left -= w;
  }
  most = max(most, previewTabLeast);
  return [for (final w in widths) min(w, most)];
}

/// The tabs of [tabs], [current] the one showing: plain names that fill the
/// slot the file name had, so the title row keeps its height and its
/// controls. Past the room they shrink, then scroll, the showing one brought
/// into view. Its state outlives the file's view (`PreviewPane.tabsKey`), so
/// picking a tab doesn't lose the row's place. A file's tab says its name
/// in the code face, a browser tab its page's title in the interface's.
class PreviewTabs extends StatefulWidget {
  const new({
    required this.chat,
    required this.tabs,
    required this.current,
    super.key,
  });

  final ChatState chat;
  final List<PreviewEntry> tabs;
  final PreviewEntry current;

  @override
  State<PreviewTabs> createState() => _PreviewTabsState();
}

class _PreviewTabsState extends State<PreviewTabs> {
  final _scroll = ScrollController();

  /// What the row last brought into view for: the tab, how many, the room.
  (PreviewEntry, int, double)? _revealed;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A tab's width with all its name showing: measured as a [Text] draws it,
  /// over the [DefaultTextStyle] (its letter spacing widens a name). A
  /// [chip]'s takes its icon and the gap after it too, its name at most
  /// [_chipNameMost].
  double _fullWidth(String label, TextStyle face, {required bool chip}) {
    final style = DefaultTextStyle.of(context).style.merge(face);
    final text = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = text.width.ceilToDouble();
    text.dispose();
    if (!chip) return width + previewNameInset + _closeRoom;
    return _chipStart +
        _chipIcon +
        6 +
        min(width, _chipNameMost) +
        _closeRoom +
        4 +
        _chipGap;
  }

  /// Scrolls no further than it takes to show from [start] to [end].
  void _reveal(double start, double end, double room) {
    if (!_scroll.hasClients) return;
    final at = _scroll.offset;
    if (at > start) {
      _scroll.jumpTo(start);
    } else if (at < end - room) {
      _scroll.jumpTo(min(end - room, start));
    }
  }

  /// A wheel only turns up and down: here that goes sideways, as the row has
  /// no other way. A trackpad's pan is the scroll view's own.
  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    final by = event.scrollDelta;
    if (by.dx != 0 || by.dy == 0) return;
    final p = _scroll.position;
    _scroll.jumpTo((p.pixels + by.dy).clamp(0, p.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // A page's title and address change its tab's name.
    listenable: Listenable.merge([
      for (final b in widget.tabs.whereType<BrowserTab>()) ...[
        b.title,
        b.address,
      ],
    ]),
    builder: (context, _) => LayoutBuilder(builder: _row),
  );

  Widget _row(BuildContext context, BoxConstraints box) {
    final theme = NushiTheme.of(context);
    final tabs = widget.tabs;
    final files = [for (final f in tabs.whereType<PreviewFile>()) f.path];
    final labels = [
      for (final e in tabs)
        switch (e) {
          PreviewFile(:final path) => tabLabel(path, files),
          final BrowserTab b => b.label,
        },
    ];
    final chips = previewChips(tabs);
    TextStyle face(PreviewEntry e, Color color) => e is BrowserTab
        ? theme.ui(color, size: chips ? 12.5 : 12)
        : theme.code(color, size: 12);
    final widths = fitTabs([
      for (final (i, e) in tabs.indexed)
        _fullWidth(labels[i], face(e, theme.t.text), chip: chips),
    ], box.maxWidth);
    final at = tabs.indexOf(widget.current);
    final seen = (widget.current, tabs.length, box.maxWidth);
    if (at >= 0 && seen != _revealed) {
      _revealed = seen;
      final start = widths.take(at).fold(0.0, (a, b) => a + b);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(start, start + widths[at], box.maxWidth);
      });
    }
    return Listener(
      onPointerSignal: _wheel,
      // No scrollbar: it would lie over the names, in a row this thin.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          // Past the last tab is the header's empty space, which zooms the
          // window (ADR 0080); the row scrolls only when tabs fill it.
          hitTestBehavior: HitTestBehavior.deferToChild,
          child: TabLine(
            value: chips ? null : widget.current,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, e) in tabs.indexed)
                  SizedBox(
                    key: switch (e) {
                      PreviewFile(:final path) => ValueKey(path),
                      BrowserTab() => ObjectKey(e),
                    },
                    width: widths[i],
                    child: _Tab(
                      chat: widget.chat,
                      tab: e,
                      label: labels[i],
                      tooltip: switch (e) {
                        PreviewFile(:final path) => plainPath(path),
                        final BrowserTab b => plainPath(b.address.value),
                      },
                      face: (color) => face(e, color),
                      showing: e == widget.current,
                      chip: chips,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tab: its name, which shows it, and a ✕ always on the one showing, on the
/// others under the pointer. Neither a box nor a tint: the one showing is the
/// primary text with a line under it, the rest muted. A [chip] is Claude
/// desktop's browser's tab instead ([_Chip]).
class _Tab extends StatelessWidget {
  const new({
    required this.chat,
    required this.tab,
    required this.label,
    required this.tooltip,
    required this.face,
    required this.showing,
    this.chip = false,
  });

  final ChatState chat;
  final PreviewEntry tab;
  final String label;
  final String tooltip;
  final TextStyle Function(Color color) face;
  final bool showing;
  final bool chip;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    if (chip) return _Chip(this);
    return Hover(
      builder: (context, {required hover}) => TabFace(
        showing: showing,
        id: tab,
        child: Row(
          children: [
            Expanded(
              child: Pressable(
                onTap: () => chat.showPreviewTab(tab),
                tooltip: tooltip,
                builder: (context, look) => Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: previewNameInset),
                  foregroundDecoration: focusRing(t, look),
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: face(tabText(t, showing: showing, hover: hover)),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _closeRoom,
              child: Opacity(
                opacity: hover || showing ? 1 : 0,
                child: IconTap.line(
                  LineIcon.close,
                  size: 12,
                  padding: 3,
                  tooltip: 'Close tab',
                  onTap: () => chat.closePreview(tab),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tab as Claude desktop's browser draws one: a rounded chip, filled on
/// the one showing and tinted under the pointer, its kind's icon (a globe,
/// a file's), its name, and a ✕, always on the one showing, on the others
/// under the pointer.
class _Chip extends StatelessWidget {
  const new(this.tab);

  final _Tab tab;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final showing = tab.showing;
    final round = BorderRadius.circular(NushiTheme.card);
    return Padding(
      padding: const EdgeInsets.only(right: _chipGap),
      child: Center(
        child: Hover(
          builder: (context, {required hover}) {
            final ink = tabText(t, showing: showing, hover: hover);
            return Container(
              height: previewChipHeight,
              decoration: BoxDecoration(
                color: showing
                    ? t.selected
                    : hover
                    ? t.hover
                    : null,
                borderRadius: round,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Pressable(
                      onTap: () => tab.chat.showPreviewTab(tab.tab),
                      tooltip: tab.tooltip,
                      builder: (context, look) => Container(
                        padding: const EdgeInsets.only(left: _chipStart),
                        foregroundDecoration: focusRing(t, look, radius: round),
                        child: Row(
                          spacing: 6,
                          children: [
                            switch (tab.tab) {
                              BrowserTab() => LineIcon.globe.view(
                                size: _chipIcon,
                                color: ink,
                              ),
                              PreviewFile(:final path) => Icon(
                                (previewKind(path) ?? PreviewKind.code).icon,
                                size: _chipIcon,
                                color: ink,
                              ),
                            },
                            Flexible(
                              child: Text(
                                tab.label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: tab.face(ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: SizedBox(
                      width: _closeRoom,
                      child: Opacity(
                        opacity: hover || showing ? 1 : 0,
                        child: IconTap.line(
                          LineIcon.close,
                          size: 12,
                          padding: 3,
                          color: ink,
                          tooltip: 'Close tab',
                          onTap: () => tab.chat.closePreview(tab.tab),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
