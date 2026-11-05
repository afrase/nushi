import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart' show ago;
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The panel's Artifacts widget, as Claude Code's rail lists what a
/// session made: the files the chat wrote in [chatArtifacts]' order (the
/// pinned, the recent, the older), five of them and "Show more" for the
/// rest; each its icon, its name and, on the right, its kind, with a pin on
/// hover (always on a pinned one) and its folder and when it changed in its
/// tooltip. A click opens its preview, the open one's row marked.
/// Collapsed, it counts them. Null (no widget) when there are none.
PanelWidget? artifactsWidget(ChatState chat) {
  if (chatFilesOf(chat).isEmpty) return null;
  return PanelWidget(
    title: 'Artifacts',
    summary: ListenableBuilder(
      listenable: artifactsOf(chat),
      builder: (context, _) {
        final theme = NushiTheme.of(context);
        final a = chatArtifacts(chat);
        return Text(
          '${a.pinned.length + a.recent.length + a.older.length}',
          style: theme.ui(theme.t.textMuted),
        );
      },
    ),
    rows: [(null, FileRows(chat, key: ValueKey(chat.id)))],
  );
}

/// How many rows show before "Show more", as Claude's rail has it.
const shownFiles = 5;

/// The widget's rows: the first [shownFiles], then "Show more", which
/// opens the rest in place (and "Show less" folds them again).
class FileRows extends StatefulWidget {
  const new(this.chat, {super.key});

  final ChatState chat;

  @override
  State<FileRows> createState() => _FileRowsState();
}

/// How far a row's text sits in from its mark's edge.
const _inset = 6.0;

class _FileRowsState extends State<FileRows> {
  bool _more = false;

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
    // The rows' names line up with the other widgets' text, their marks
    // reaching past it into the widget's padding.
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
    final all = [...a.pinned, ...a.recent, ...a.older];
    final more = all.length > shownFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in more && !_more ? all.take(shownFiles) : all)
          _FileRow(widget.chat, f, open: f == open, changed: _changedOf(f)),
        if (more)
          Align(
            alignment: Alignment.centerLeft,
            child: Tap(
              onTap: () => setState(() => _more = !_more),
              tint: false,
              padding: const EdgeInsets.symmetric(
                horizontal: _inset,
                vertical: PanelType.rowGap,
              ),
              child: Text(
                _more ? 'Show less' : 'Show more',
                style: theme.ui(t.textMuted),
              ),
            ),
          ),
      ],
    );
  }
}

/// A file's row: its kind's icon (its pin there on hover, or always when
/// pinned), its name, its kind on the right; its folder and when it
/// [changed] in its tooltip.
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
    final kind = previewKind(f);
    final when = changed;
    return Hover(
      builder: (context, {required hover}) => Tap(
        onTap: () => chat.openPreview(f),
        selected: open,
        tooltip: [
          f,
          if (when != null) ago(clock().difference(when), when),
        ].join(' · '),
        // A background task's room, as Claude's Outputs and its tasks share.
        padding: const EdgeInsets.symmetric(
          horizontal: _inset,
          vertical: 1 + PanelType.rowGap,
        ),
        child: SizedBox(
          height: 22,
          child: Row(
            spacing: 8,
            children: [
              pinMark(
                chat,
                f,
                hover: hover,
                icon: Icon(
                  kind?.icon ?? Icons.description_outlined,
                  size: 15,
                  color: t.textMuted,
                ),
              ),
              Expanded(
                child: Text(
                  baseName(f),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text),
                ),
              ),
              if (kind != null) Text(kind.label, style: theme.ui(t.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
