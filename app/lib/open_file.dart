import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat_files.dart';
import 'package:nushi/completions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// ⌘P: Open file… in the chat shown.
const openFileKey = SingleActivator(LogicalKeyboardKey.keyP, meta: true);

/// Opens a file of the chat shown in its preview, picked in a small box
/// that matches as you type ([OpenFileBox]); nothing when no chat shows
/// or its daemon has no preview.
Future<void> openFile(BuildContext context, Daemon daemon) async {
  final chat = daemon.selected;
  if (chat == null || !daemon.chatShows || daemon.daemonApi < previewApi) {
    return;
  }
  final path = await showDialog<String>(
    context: context,
    builder: (_) => OpenFileBox(
      daemon: daemon,
      folder: chat.folder,
      chat: chatFiles(chat.items),
    ),
  );
  if (path != null) chat.openPreview(path);
}

/// The quick-open box: a field, and under it the files of [folder] a
/// preview shows (as `@` lists them: git's, not ignored) that match it,
/// the chat's own ([chat]) first while it's empty. ↑↓ move, ⏎ or a click
/// picks (the dialog pops with the path), Esc closes.
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

  @override
  State<OpenFileBox> createState() => _OpenFileBoxState();
}

class _OpenFileBoxState extends State<OpenFileBox> {
  final _text = TextEditingController();
  // The chat's files, then the folder's once listed: once each.
  late List<String> _all = widget.chat.toSet().toList();
  List<String> _shown = const []; // as last built: what the keys move in
  bool _listed = false; // the daemon answered
  String _error = '';
  int _at = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_list());
  }

  Future<void> _list() async {
    try {
      final r = await widget.daemon.client.listFiles(
        ListFilesRequest(folder: widget.folder),
      );
      _all = {
        ...widget.chat,
        for (final p in r.paths)
          if (previewKind(p) != null) p,
      }.toList();
    } on Object catch (e) {
      _error = errorText(e);
    }
    if (mounted) setState(() => _listed = true);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// What shows for what's typed: ranked once a build.
  List<String> _rank() {
    final q = _text.text.trim();
    return q.isEmpty ? _all.take(8).toList() : rankChoices(_all, q);
  }

  void _pick(String path) => Navigator.pop(context, path);

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final shown = _shown;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp
          when shown.isNotEmpty:
        final step = e.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
        setState(() => _at = (_at + step) % shown.length);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when _at < shown.length:
        _pick(shown[_at]);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final shown = _shown = _rank();
    _at = _at.clamp(0, shown.isEmpty ? 0 : shown.length - 1);
    return Dialog(
      alignment: const Alignment(0, -0.6),
      child: SizedBox(
        width: 520,
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
                  onChanged: (_) => setState(() => _at = 0),
                  decoration: const InputDecoration(
                    hintText: 'Open file…',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, size: 15),
                    prefixIconConstraints: BoxConstraints(minWidth: 28),
                  ),
                ),
              ),
              const Divider(height: 9),
              for (final (i, f) in shown.indexed)
                Tap(
                  onTap: () => _pick(f),
                  selected: i == _at,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: baseName(f),
                          style: theme.code(t.text, size: 12.5),
                        ),
                        TextSpan(
                          text: '   ${folderOf(f)}',
                          style: theme.ui(t.textMuted, size: 12),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (shown.isEmpty && _listed)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _error.isNotEmpty
                        ? 'Couldn’t list the folder: $_error'
                        : 'No file to preview matches',
                    style: theme.ui(t.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
