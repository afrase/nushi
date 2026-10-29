import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The panel's Artifacts card: the files the chat wrote as [chatArtifacts]
/// sorts them, the pinned and the recent, then "Older (n)" folding the
/// rest; each its name and, muted, its folder and when it changed, with a
/// pin on hover (always on a pinned one); a click opens its preview, the
/// open one's row marked. Collapsed, it counts the pinned and recent. Null
/// (no card) when there are none.
PanelCard? artifactsCard(ChatState chat) {
  if (chatFilesOf(chat).isEmpty) return null;
  return PanelCard(
    title: 'Artifacts',
    summary: ListenableBuilder(
      listenable: artifactsOf(chat),
      builder: (context, _) {
        final theme = NushiTheme.of(context);
        final a = chatArtifacts(chat);
        return Text(
          '${a.pinned.length + a.recent.length}',
          style: theme.ui(theme.t.textMuted, size: 12),
        );
      },
    ),
    rows: [(null, FileRows(chat, key: ValueKey(chat.id)))],
  );
}

/// The card's rows: the pinned and the recent, then "Older (n)", which
/// opens the rest in place.
class FileRows extends StatefulWidget {
  const new(this.chat, {super.key});

  final ChatState chat;

  @override
  State<FileRows> createState() => _FileRowsState();
}

/// How far a row's text sits in from its mark's edge.
const _inset = 6.0;

class _FileRowsState extends State<FileRows> {
  bool _older = false;

  late final Timer _tick;

  /// When each row's file last changed: read again on the minute's tick
  /// and when the chat's items or folder change, not as text streams in.
  final _changed = <String, DateTime?>{};
  (int, String)? _readAt;

  DateTime? _changedOf(String file) {
    final chat = widget.chat;
    final at = (chat.revision, chat.folder);
    if (at != _readAt) {
      _changed.clear();
      _readAt = at;
    }
    return _changed.putIfAbsent(
      file,
      () => fileChanged(absoluteIn(chat.folder, file)),
    );
  }

  @override
  void initState() {
    super.initState();
    // "2m ago" goes on aging while nothing else changes, and a file opened
    // an hour ago leaves the recent.
    _tick = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(_changed.clear),
    );
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    // The rows' names line up with the other cards' text, their marks
    // reaching past it into the card's padding.
    return LayoutBuilder(
      builder: (context, box) => OverflowBox(
        minWidth: box.maxWidth + 2 * _inset,
        maxWidth: box.maxWidth + 2 * _inset,
        fit: OverflowBoxFit.deferToChild,
        child: ListenableBuilder(
          listenable: artifactsOf(widget.chat),
          builder: (context, _) => _rows(theme, chatArtifacts(widget.chat)),
        ),
      ),
    );
  }

  Widget _rows(NushiTheme theme, Artifacts a) {
    final t = theme.t;
    final open = widget.chat.preview.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in [...a.pinned, ...a.recent])
          _FileRow(widget.chat, f, open: f == open, changed: _changedOf(f)),
        if (a.older.isNotEmpty) ...[
          Tap(
            onTap: () => setState(() => _older = !_older),
            padding: const EdgeInsets.symmetric(
              horizontal: _inset,
              vertical: 3,
            ),
            child: Row(
              spacing: 4,
              children: [
                Text(
                  'Older (${a.older.length})',
                  style: theme.ui(t.textMuted, size: 12),
                ),
                Chevron(open: _older),
              ],
            ),
          ),
          if (_older)
            for (final f in a.older)
              _FileRow(widget.chat, f, open: f == open, changed: _changedOf(f)),
        ],
      ],
    );
  }
}

/// A file's row: its name and, muted, its folder and when it [changed];
/// its pin at the right end on hover, or always when pinned.
class _FileRow extends StatelessWidget {
  const new(this.chat, this.file, {required this.open, required this.changed});

  final ChatState chat;
  final String file;
  final bool open;
  final DateTime? changed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final f = file;
    final detail = fileDetail(f, changed);
    return Hover(
      builder: (context, {required hover}) => Tap(
        onTap: () => chat.openPreview(f),
        selected: open,
        tooltip: f,
        padding: const EdgeInsets.fromLTRB(_inset, 3, 0, 3),
        child: Row(
          children: [
            Expanded(
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
            ),
            pinMark(chat, f, hover: hover),
          ],
        ),
      ),
    );
  }
}
