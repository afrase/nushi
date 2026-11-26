import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart' show ago;
import 'package:nushi/palette.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The panel's Artifacts widget, as Claude Code's rail lists what a
/// session made: the files the chat wrote in [chatArtifacts]' order (the
/// pinned, the recent, the older), five of them and "Show more" for the
/// rest; each its icon, its name and, on the right, its kind, with a pin on
/// hover (always on a pinned one) and its folder and when it changed in its
/// tooltip, and the run that changed it last when a workflow's agents did
/// (no mark: the workflow's glyph is the Diagram kind's and a worktree's,
/// and a row has no room to spare). A click opens its preview,
/// the open one's row marked.
/// Collapsed, it counts them. Null (no widget) when there are none.
PanelWidget? artifactsWidget(ChatState chat) {
  final a = chatArtifacts(chat);
  if (a.pinned.isEmpty && a.recent.isEmpty && a.older.isEmpty) return null;
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

/// How many rows "Show more" opens at most: a workflow can write a
/// thousand, and every row shown is built and its file's time read; past
/// these, "Show all in Artifacts…" lists every one in Artifacts…'s
/// palette, which builds only the rows in view.
const moreFiles = 50;

/// The widget's rows: the first [shownFiles], then "Show more", which
/// opens the rest in place up to [moreFiles] (and "Show less" folds them
/// again).
class FileRows extends StatefulWidget {
  const new(this.chat, {super.key});

  final ChatState chat;

  @override
  State<FileRows> createState() => _FileRowsState();
}

/// How far a row's text sits in from its mark's edge.
const _inset = 6.0;

/// How wide a row's tooltip grows before it wraps: a path is an agent's
/// choice, and one of a few hundred characters would cross the window.
const fileTipWidth = 420.0;

class _FileRowsState extends State<FileRows> {
  bool _more = false;

  /// While the pointer is over the rows the order they showed holds
  /// ([_held]), so a file a running workflow adds doesn't slide the row
  /// under the pointer away before a click; what came is applied once it
  /// leaves. Only the pointer: the keyboard's focus stays on a row opened
  /// with Enter, and would hold the list with nothing on screen saying so.
  List<String>? _held;
  List<String> _shown = const [];

  void _hold({required bool pointer}) {
    if (pointer) {
      _held ??= _shown;
    } else if (_held != null) {
      setState(() => _held = null);
    }
  }

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
    minuteClock.addListener(_aged);
  }

  void _aged() => setState(_changed.clear);

  @override
  void dispose() {
    minuteClock.removeListener(_aged);
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
        child: MouseRegion(
          onEnter: (_) => _hold(pointer: true),
          onExit: (_) => _hold(pointer: false),
          child: ListenableBuilder(
            listenable: artifactsOf(widget.chat),
            builder: (context, _) => _rows(theme, chatArtifacts(widget.chat)),
          ),
        ),
      ),
    );
  }

  Widget _rows(NushiTheme theme, Artifacts a) {
    final t = theme.t;
    final open = openArtifact(widget.chat);
    final all = _shown = _held ?? [...a.pinned, ...a.recent, ...a.older];
    final more = all.length > shownFiles;
    Widget link(String label, VoidCallback onTap) => Tap(
      onTap: onTap,
      tint: false,
      padding: const EdgeInsets.symmetric(
        horizontal: _inset,
        vertical: PanelType.rowGap,
      ),
      child: Text(label, style: theme.ui(t.textMuted)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in all.take(_more ? moreFiles : shownFiles))
          _FileRow(widget.chat, f, open: f == open, changed: _changedOf(f)),
        if (more)
          Row(
            children: [
              link(
                _more ? 'Show less' : 'Show more',
                () => setState(() => _more = !_more),
              ),
              if (_more && all.length > moreFiles)
                Flexible(
                  child: link(
                    'Show all in Artifacts…',
                    () => unawaited(showArtifacts(context, widget.chat)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A file's row: its kind's icon (its pin there on hover, or always when
/// pinned), its name, its kind on the right ("Gone", and no pin on hover,
/// once the file isn't there); its folder and when it
/// [changed] in its tooltip, and on a line of its own the workflow that
/// changed it last, if one did.
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
    final run = writtenByWorkflow(chat, f);
    // No time read: the file isn't there any more (the stat the row takes
    // anyway). It stays a row, so nothing moves under the pointer: its name
    // muted and italic, and "Gone" in its kind's place, since a muted name
    // alone reads as a quieter row; with nothing to keep, no pin.
    final gone = filesLooked && when == null;
    return Hover(
      builder: (context, {required hover}) => TooltipTheme(
        data: TooltipTheme.of(context).copyWith(
          // The least height a desktop tooltip has, and a widest.
          constraints: const BoxConstraints(
            minHeight: 24,
            maxWidth: fileTipWidth,
          ),
        ),
        child: Tap(
          onTap: () => chat.openInFiles(f),
          selected: open,
          tooltip: [
            // A path and a run's name are an agent's text: plain, so they
            // can't reorder or hide what's around them.
            [
              plainName(f),
              if (when != null) ago(clock().difference(when), when),
            ].join(' · '),
            if (gone) 'Not there any more',
            if (run != null) 'Written by the workflow ${plainName(run)}',
          ].join('\n'),
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
                  hover: hover && !gone,
                  icon: Icon(
                    kind?.icon ?? Icons.description_outlined,
                    size: 15,
                    color: t.textMuted,
                  ),
                ),
                Expanded(
                  child: Text(
                    plainName(baseName(f)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme
                        .ui(gone ? t.textMuted : t.text)
                        .copyWith(fontStyle: gone ? FontStyle.italic : null),
                  ),
                ),
                if (gone)
                  Text('Gone', style: theme.ui(t.textMuted))
                else if (kind != null)
                  Text(kind.label, style: theme.ui(t.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
