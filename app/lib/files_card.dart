import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The panel's Files card: the files the chat wrote ([chatFiles], newest
/// first), each its name and, muted, its folder and when it changed; a
/// click opens its preview, the open one's row marked. Null (no card) when
/// there are none.
PanelCard? filesCard(ChatState chat) {
  final files = chatFiles(chat.items);
  if (files.isEmpty) return null;
  return PanelCard(
    title: 'Files',
    summary: Builder(
      builder: (context) {
        final theme = NushiTheme.of(context);
        return Text(
          '${files.length}',
          style: theme.ui(theme.t.textMuted, size: 12),
        );
      },
    ),
    rows: [(null, FileRows(chat, files, key: ValueKey(chat.id)))],
  );
}

/// The card's rows: the first [shown] of [files], then "Show all (n)",
/// which opens the rest in place.
class FileRows extends StatefulWidget {
  const new(this.chat, this.files, {super.key});

  /// How many rows show before "Show all".
  static const shown = 8;

  final ChatState chat;
  final List<String> files;

  @override
  State<FileRows> createState() => _FileRowsState();
}

/// How far a row's text sits in from its mark's edge.
const _inset = 6.0;

class _FileRowsState extends State<FileRows> {
  bool _all = false;

  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // "2m ago" goes on aging while nothing else changes.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final cut = !_all && widget.files.length > FileRows.shown;
    // The rows' names line up with the other cards' text, their marks
    // reaching past it into the card's padding.
    return LayoutBuilder(
      builder: (context, box) => OverflowBox(
        minWidth: box.maxWidth + 2 * _inset,
        maxWidth: box.maxWidth + 2 * _inset,
        fit: OverflowBoxFit.deferToChild,
        child: _rows(theme, cut),
      ),
    );
  }

  Widget _rows(NushiTheme theme, bool cut) {
    final t = theme.t;
    final files = widget.files;
    return ValueListenableBuilder(
      valueListenable: widget.chat.preview,
      builder: (context, open, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in cut ? files.take(FileRows.shown) : files)
            _row(theme, f, open: f == open),
          if (cut)
            Tap(
              onTap: () => setState(() => _all = true),
              padding: const EdgeInsets.symmetric(
                horizontal: _inset,
                vertical: 3,
              ),
              child: Text(
                'Show all (${files.length})',
                style: theme.ui(t.textMuted, size: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(NushiTheme theme, String f, {required bool open}) {
    final t = theme.t;
    final detail = fileDetail(
      f,
      fileChanged(absoluteIn(widget.chat.folder, f)),
    );
    return Tap(
      onTap: () => widget.chat.openPreview(f),
      selected: open,
      tooltip: f,
      padding: const EdgeInsets.symmetric(horizontal: _inset, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baseName(f),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.text, size: 12),
          ),
          if (detail.isNotEmpty)
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.textMuted, size: 11.5),
            ),
        ],
      ),
    );
  }
}
