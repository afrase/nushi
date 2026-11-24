import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat_files.dart';
import 'package:nushi/completions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/picker.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';

/// ⌘P: Open file… in the chat shown.
const openFileKey = Cmd(LogicalKeyboardKey.keyP, id: 'openFile');

/// Opens a file of the chat shown in its preview, picked in a small box
/// that matches as you type ([OpenFileBox], a [PickBox]); nothing when no
/// chat shows.
Future<void> openFile(BuildContext context, Daemon daemon) async {
  final chat = daemon.selected;
  if (chat == null || !daemon.chatShows) return;
  final path = await showDialog<String>(
    context: context,
    routeSettings: Picker.openFile.settings,
    builder: (_) => OpenFileBox(
      daemon: daemon,
      folder: chat.folder,
      chat: chatFilesOf(chat),
    ),
  );
  if (path != null) chat.openInFiles(path);
}

/// The quick-open box, a [PickBox] of the files of [folder] a preview
/// shows (as `@` lists them: git's, not ignored) that match what's typed
/// ([rankChoices]), the chat's own ([chat]) first while it's empty; the
/// dialog pops with the path picked.
class OpenFileBox extends StatefulWidget {
  const new({
    required this.daemon,
    required this.folder,
    required this.chat,
    super.key,
  });

  final Daemon daemon;
  final String folder;
  final List<String> chat;

  /// A row's height: a line of 12-point text and its padding.
  static const rowHeight = 25.0;

  @override
  State<OpenFileBox> createState() => _OpenFileBoxState();
}

class _OpenFileBoxState extends State<OpenFileBox> {
  // The folder's files, as last listed: shown at once, and listed again.
  late final GitFiles _git = gitFilesOf(widget.daemon, widget.folder);

  /// The rows as last listed: the same list while the listing is, so the
  /// box ranks once a query.
  List<String> _rows = const [];

  @override
  void initState() {
    super.initState();
    _rows = _all;
    _git
      ..addListener(_listed)
      ..ask();
  }

  void _listed() {
    if (mounted) setState(() => _rows = _all);
  }

  @override
  void dispose() {
    _git.removeListener(_listed);
    super.dispose();
  }

  /// The chat's files, then the folder's that a preview shows: once each.
  List<String> get _all => {
    ...widget.chat,
    for (final p in _git.paths)
      if (opensInPreview(p)) p,
  }.toList();

  /// What shows for what's typed, eight at most.
  static List<String> _rank(List<String> rows, String query) {
    final q = query.trim();
    return q.isEmpty ? rows.take(8).toList() : rankChoices(rows, q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return PickBox<String>(
      rows: _rows,
      rank: _rank,
      hint: 'Open file…',
      rowHeight: OpenFileBox.rowHeight,
      rowPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      empty: switch (_git) {
        GitFiles(listed: false) => 'Listing…',
        GitFiles(:final error) when error.isNotEmpty =>
          'Couldn’t list the folder: $error',
        _ => 'No file to preview matches',
      },
      row: (context, f) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: baseName(f), style: theme.code(t.text, size: 12)),
            TextSpan(
              text: '   ${folderOf(f)}',
              style: theme.ui(t.textMuted, size: 12),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
