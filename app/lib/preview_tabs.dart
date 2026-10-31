import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// The preview pane's tabs (ADR 0070), in its title row in place of the file
// name when more than one file is open: what each says, how wide it is, and
// the row.

/// What the tab of [file] says: its name, with as much of its folder as
/// tells it from the others of that name in [files] ("plan.md · docs").
String tabLabel(String file, List<String> files) {
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

/// The text's inset in a tab, the same as the file name's in [FilesMenu], so
/// the first name stays where the one file's name was.
const double _nameInset = 5;

/// The room a tab keeps for its ✕, shown or not, so its name doesn't move.
const double _closeRoom = 18;

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

/// The tabs of [files], [current] the one showing: plain names that fill the
/// slot the file name had, so the title row keeps its height and its
/// controls. Past the room they shrink, then scroll, the showing one brought
/// into view. Its state outlives the file's view (`PreviewPane.tabsKey`), so
/// picking a tab doesn't lose the row's place.
class PreviewTabs extends StatefulWidget {
  const new({
    required this.chat,
    required this.files,
    required this.current,
    super.key,
  });

  final ChatState chat;
  final List<String> files;
  final String current;

  @override
  State<PreviewTabs> createState() => _PreviewTabsState();
}

class _PreviewTabsState extends State<PreviewTabs> {
  final _scroll = ScrollController();

  /// What the row last brought into view for: the tab, how many, the room.
  (String, int, double)? _revealed;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A tab's width with all its name showing: measured as a [Text] draws it,
  /// over the [DefaultTextStyle] (its letter spacing widens a name).
  double _fullWidth(String label) {
    final theme = NushiTheme.of(context);
    final style = DefaultTextStyle.of(context).style
        .merge(theme.code(theme.t.text, size: 12));
    final text = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = text.width.ceilToDouble();
    text.dispose();
    return width + _nameInset + _closeRoom;
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final files = widget.files;
      final labels = [for (final f in files) tabLabel(f, files)];
      final widths = fitTabs([
        for (final l in labels) _fullWidth(l),
      ], box.maxWidth);
      final at = files.indexOf(widget.current);
      final seen = (widget.current, files.length, box.maxWidth);
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, f) in files.indexed)
                  SizedBox(
                    key: ValueKey(f),
                    width: widths[i],
                    child: _Tab(
                      chat: widget.chat,
                      file: f,
                      label: labels[i],
                      showing: f == widget.current,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// A tab: its name, which shows it, and a ✕ always on the one showing, on the
/// others under the pointer. Neither a box nor a tint: the one showing is the
/// primary text with a line under it, the rest muted.
class _Tab extends StatelessWidget {
  const new({
    required this.chat,
    required this.file,
    required this.label,
    required this.showing,
  });

  final ChatState chat;
  final String file;
  final String label;
  final bool showing;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Hover(
      builder: (context, {required hover}) => TabFace(
        showing: showing,
        child: Row(
          children: [
            Expanded(
              child: Pressable(
                onTap: () => chat.openPreview(file),
                tooltip: file,
                builder: (context, look) => Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: _nameInset),
                  foregroundDecoration: focusRing(t, look),
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.code(
                      tabText(t, showing: showing, hover: hover),
                      size: 12,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _closeRoom,
              child: Opacity(
                opacity: hover || showing ? 1 : 0,
                child: IconTap(
                  Icons.close,
                  size: 12,
                  padding: 3,
                  tooltip: 'Close tab',
                  onTap: () => chat.closePreviewFile(file),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
