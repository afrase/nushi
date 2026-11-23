import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/double_clicks.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/widgets.dart';

// A pane's tabs (ADR 0070): a file view's, in its title row in place of the
// file name when more than one file is open, as plain names (ADR 0071), each
// led by its kind's icon; the browser pane's (ADR 0094), named for their
// pages, as chips, as Claude desktop's browser draws its tabs. The two kinds
// never share a row (ADR 0071). What each says, how wide it is, and the row.

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

/// How narrow a tab gets before the row scrolls instead, while the row
/// is wider (one in a narrower row is as wide as the row: a chip shrinks
/// to its icon and ✕ rather than being cut).
const double previewTabLeast = 88;

/// The text's inset in a tab, and the one file's name's in the pane's
/// title row, so the first name stays where the one file's name was.
const double previewNameInset = 5;

/// The room a tab keeps for its ✕, shown or not, so its name doesn't move.
const double _closeRoom = 18;

/// A file's kind's icon before its name, in a plain tab and before the one
/// file's name alike, and the gap after it: so a tab's icon and name are
/// where the one file's were.
const double previewKindIcon = 14;
const double previewKindGap = 6;

/// How narrow a file's plain tab gets: [previewTabLeast] past its kind's
/// icon, so its name keeps the room it had without one.
const double previewFileTabLeast =
    previewTabLeast + previewKindIcon + previewKindGap;

/// A chip's height, the room between chips, its icon's size, the room
/// before it and after it, the room a chip keeps for its ✕ and after it,
/// and the most a chip's name takes before it's cut: one long title leaves
/// the others their room, as Claude's chips do. Its name, icon and ✕ are
/// as large as Claude's, the name the address field's size.
const double previewChipHeight = 28;
const double _chipGap = 4;
const double _chipIcon = 16;
const double _chipStart = 9;
const double _chipIconGap = 7;
const double _chipCloseRoom = 24;
const double _chipEnd = 1;
const double _chipNameMost = 180;

/// A chip with no room for its name: its icon, its ✕ and their room.
const double previewChipLeast =
    _chipStart +
    _chipIcon +
    _chipIconGap +
    _chipCloseRoom +
    _chipEnd +
    _chipGap;

/// The + after the browser's chips, which opens a new browser tab: Claude's
/// is always there.
class NewBrowserTab extends StatelessWidget {
  const new({required this.chat, super.key});

  final ChatState chat;

  @override
  Widget build(BuildContext context) => IconTap.line(
    LineIcon.plus,
    tooltip: 'New browser tab',
    size: 20,
    padding: 4,
    color: NushiTheme.of(context).t.text,
    onTap: chat.openBrowserTab,
  );
}

/// How wide tabs that would like [widths] are in [room]. The widest give way
/// first, down to [previewTabLeast] (or the room, when that's less, but
/// never under [least]: a chip's icon and ✕, a file tab's
/// [previewFileTabLeast]); past that they add up to
/// more than [room], and the row scrolls.
List<double> fitTabs(List<double> widths, double room, {double least = 0}) {
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
  most = max(most, max(least, min(previewTabLeast, room)));
  return [for (final w in widths) min(w, most)];
}

/// The tabs of [tabs], [current] the one showing: a file view's plain names
/// ([PaneTabs.files]) that fill the slot the file name had, so the title row
/// keeps its height and its controls, or the browser's chips
/// ([PaneTabs.browser]). Past the room they shrink, then scroll, the showing
/// one brought into view. Its state outlives each tab's view
/// (`FileView.tabsKey`), so picking a tab doesn't lose the row's place. A
/// file's tab says its name in the code face, a browser tab its page's title
/// in the interface's.
class PaneTabs extends StatefulWidget {
  /// A file view's tabs: plain names (ADR 0071), each after its kind's icon.
  const new files({
    required this.chat,
    required List<PreviewFile> this.tabs,
    required PreviewFile this.current,
    super.key,
  }) : chips = false;

  /// The browser's tabs, drawn as Claude desktop's browser draws its tabs (a
  /// rounded fill, a globe, the name, a ✕; ADR 0094).
  const new browser({
    required this.chat,
    required List<BrowserTab> this.tabs,
    required BrowserTab this.current,
    super.key,
  }) : chips = true;

  final ChatState chat;

  /// Every one a [PreviewFile] for [PaneTabs.files], a [BrowserTab] for
  /// [PaneTabs.browser].
  final List<PreviewEntry> tabs;
  final PreviewEntry current;

  /// Whether these are the browser's chips.
  final bool chips;

  @override
  State<PaneTabs> createState() => _PaneTabsState();
}

class _PaneTabsState extends State<PaneTabs> {
  final _scroll = ScrollController();

  /// A file's tab clicked twice is kept (preview tabs, ADR 0070).
  final _clicks = DoubleClicks();

  /// What the row last brought into view for: the tab, how many, the room.
  (PreviewEntry, int, double)? _revealed;

  @override
  void dispose() {
    _clicks.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A tab's width with all its name showing: measured as a [Text] draws it,
  /// over the [DefaultTextStyle] (its letter spacing widens a name). A
  /// [chip]'s takes its icon and the gap after it too, its name at most
  /// [_chipNameMost]; a plain one (a file's) its kind's icon.
  double _fullWidth(String label, TextStyle face, {required bool chip}) {
    final style = DefaultTextStyle.of(context).style.merge(face);
    final text = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = text.width.ceilToDouble();
    text.dispose();
    if (!chip) {
      return previewKindIcon +
          previewKindGap +
          width +
          previewNameInset +
          _closeRoom;
    }
    return _chipStart +
        _chipIcon +
        _chipIconGap +
        min(width, _chipNameMost) +
        _chipCloseRoom +
        _chipEnd +
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
    final chips = widget.chips;
    // A provisional file's name in italics, measured so too.
    final provisional = widget.chat.files.provisional.value;
    TextStyle face(PreviewEntry e, Color color) => chips
        ? theme.ui(color, size: 14)
        : theme
              .code(color, size: 12)
              .copyWith(fontStyle: e == provisional ? FontStyle.italic : null);
    final widths = fitTabs(
      [
        for (final (i, e) in tabs.indexed)
          _fullWidth(labels[i], face(e, theme.t.text), chip: chips),
      ],
      box.maxWidth,
      least: chips ? previewChipLeast : previewFileTabLeast,
    );
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
                      clicks: _clicks,
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

/// A tab: a file's kind's icon, its name, which shows it, and a ✕ always on
/// the one showing, on the others under the pointer. Neither a box nor a
/// tint: the one showing is the primary text with a line under it (its icon
/// secondary, as the one file's is), the rest muted. A [chip] is Claude
/// desktop's browser's tab instead ([_Chip]): a [PaneTabs.browser] tab.
class _Tab extends StatelessWidget {
  const new({
    required this.chat,
    required this.tab,
    required this.label,
    required this.tooltip,
    required this.face,
    required this.showing,
    this.chip = false,
    this.clicks,
  });

  final ChatState chat;
  final PreviewEntry tab;
  final String label;
  final String tooltip;
  final TextStyle Function(Color color) face;
  final bool showing;
  final bool chip;

  /// Tells a file's tab clicked twice, which keeps it.
  final DoubleClicks? clicks;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    if (chip) return _Chip(this);
    // Not a chip: a [PaneTabs.files] tab.
    final tab = this.tab as PreviewFile;
    return Hover(
      builder: (context, {required hover}) => TabFace(
        showing: showing,
        id: tab,
        child: Row(
          children: [
            Expanded(
              child: Listener(
                onPointerDown: (e) {
                  if (clicks?.down(tab, e.position) ?? false) {
                    chat.files.keep(tab);
                  }
                },
                child: Pressable(
                  onTap: () => chat.showTab(tab),
                  tooltip: tooltip,
                  builder: (context, look) {
                    final ink = tabText(t, showing: showing, hover: hover);
                    return Container(
                      alignment: Alignment.centerLeft,
                      foregroundDecoration: focusRing(t, look),
                      child: Row(
                        children: [
                          Icon(
                            (previewKind(tab.path) ?? PreviewKind.code).icon,
                            size: previewKindIcon,
                            color: showing ? t.textSecondary : ink,
                          ),
                          const SizedBox(width: previewKindGap),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: previewNameInset,
                              ),
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: face(ink),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              width: _closeRoom,
              child: EditedMark(
                chat: chat,
                path: tab.path,
                shown: hover || showing,
                hover: hover,
                close: IconTap.line(
                  LineIcon.close,
                  size: 12,
                  padding: 3,
                  tooltip: 'Close tab',
                  onTap: () => unawaited(closeTabSaving(context, chat, tab)),
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
/// the one showing and tinted under the pointer, a globe, its page's name,
/// and a ✕, always on the one showing, on the others under the pointer.
class _Chip extends StatelessWidget {
  const new(this.tab);

  final _Tab tab;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final showing = tab.showing;
    final round = BorderRadius.circular(NushiTheme.control);
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
                      onTap: () => tab.chat.showTab(tab.tab),
                      tooltip: tab.tooltip,
                      builder: (context, look) => Container(
                        padding: const EdgeInsets.only(left: _chipStart),
                        foregroundDecoration: focusRing(t, look, radius: round),
                        child: Row(
                          spacing: _chipIconGap,
                          children: [
                            LineIcon.globe.view(size: _chipIcon, color: ink),
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
                    padding: const EdgeInsets.only(right: _chipEnd),
                    child: SizedBox(
                      width: _chipCloseRoom,
                      child: Opacity(
                        opacity: hover || showing ? 1 : 0,
                        child: Center(
                          child: IconTap.line(
                            // IconTap's 16: an ✕ as tall as the name's caps.
                            LineIcon.close,
                            padding: 2,
                            color: ink,
                            tooltip: 'Close tab',
                            onTap: () => unawaited(
                              closeTabSaving(context, tab.chat, tab.tab),
                            ),
                          ),
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
