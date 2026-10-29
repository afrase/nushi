import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/settings_general.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xterm2/xterm.dart';

/// Characters that end a path or URL in a terminal's text.
final _stop = RegExp(r'''[\s"'`()<>\[\]{}|]''');

/// What a ⌘-click at [at] opens: an OSC 8 link's real target (never the
/// text it shows), else the word under it.
String clickTarget(Terminal terminal, CellOffset at) =>
    terminal.hyperlinkAt(at) ?? wordAt(terminal, at);

/// The word under [at] on its line.
String wordAt(Terminal terminal, CellOffset at) {
  if (at.y < 0 || at.y >= terminal.buffer.lines.length) return '';
  final line = terminal.buffer.lines[at.y];
  final left = line.getText(0, at.x);
  final right = line.getText(at.x);
  final start = left.lastIndexOf(_stop) + 1;
  final end = right.indexOf(_stop);
  return left.substring(start) + (end < 0 ? right : right.substring(0, end));
}

/// What a ⌘-click on [clicked] opens: an http(s) URL, or an existing file or
/// folder (absolute, `~/`, or relative to [folder]), with the line after
/// it, if any (`main.dart:12:5`).
({Uri? url, String? path, int? line}) linkOf(String clicked, String folder) {
  final word = clicked.replaceFirst(RegExp(r'[.,;:!?]+$'), '');
  if (RegExp('^https?://').hasMatch(word)) {
    return (url: Uri.tryParse(word), path: null, line: null);
  }
  final m = RegExp(r'^(.+?)(?::(\d+))?(?::\d+)?$').firstMatch(word);
  if (m == null) return (url: null, path: null, line: null);
  var path = m[1]!;
  if (path.startsWith('file://')) path = Uri.parse(path).toFilePath();
  if (path.startsWith('~/')) {
    path = '${Platform.environment['HOME']}${path.substring(1)}';
  } else if (!path.startsWith('/')) {
    path = '$folder/$path';
  }
  path = File(path).absolute.uri.normalizePath().toFilePath();
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
    return (url: null, path: null, line: null);
  }
  return (url: null, path: path, line: int.tryParse(m[2] ?? ''));
}

/// Opens a URL in the browser, or shows a file: in the Changes view when
/// [showChange] takes it (it's changed), else in Finder.
Future<void> openLink(
  String word,
  String folder,
  Future<bool> Function(String path) showChange,
) async {
  final link = linkOf(word, folder);
  if (link.url case final url?) {
    await launchUrl(url);
  } else if (link.path case final path?) {
    if (!await showChange(path)) await Process.run('open', ['-R', path]);
  }
}

/// ⌘F over a terminal: finds in its scrollback, highlights every match,
/// and scrolls to the current one, starting from the latest. Enter goes to
/// the next one down, Shift-Enter up, as every find bar does (round from
/// the latest to the first); Escape closes it.
class TerminalFindBar extends StatefulWidget {
  const new({required this.session, super.key});

  final TermSession session;

  @override
  State<TerminalFindBar> createState() => _TerminalFindBarState();
}

class _TerminalFindBarState extends State<TerminalFindBar> {
  List<TerminalSearchMatch> _matches = [];
  int _current = 0;

  TermSession get _s => widget.session;

  void _find(String query) {
    _matches = _s.terminal.search(query);
    _current = max(0, _matches.length - 1); // the latest first
    _s.controller.setSearchHighlights(_s.terminal.buffer, [
      for (final m in _matches) m.range,
    ], currentIndex: _current);
    _show();
  }

  void _step(int by) {
    if (_matches.isEmpty) return;
    _current = (_current + by + _matches.length) % _matches.length;
    _s.controller.setCurrentSearchHighlight(_current);
    _show();
  }

  // Scrolls the current match to the middle of the screen.
  void _show() {
    setState(() {});
    final scroll = _s.scroll;
    if (_matches.isEmpty || !scroll.hasClients) return;
    final style = terminalStyle();
    final lineHeight = style.fontSize * style.height;
    final y = _matches[_current].range.begin.y - _s.terminal.viewHeight / 2;
    final p = scroll.position;
    scroll.jumpTo((y * lineHeight).clamp(0, p.maxScrollExtent));
  }

  void _close() {
    _s.controller.clearSearchHighlights();
    _s.finding.value = false;
    _s.focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: t.raised,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(NushiTheme.card),
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _close,
          const SingleActivator(LogicalKeyboardKey.enter, shift: true): () =>
              _step(-1),
        },
        child: Row(
          children: [
            Expanded(
              child: TextField(
                autofocus: true,
                style: theme.ui(t.text, size: 12),
                decoration: const InputDecoration.collapsed(hintText: 'Find'),
                onChanged: _find,
                onSubmitted: (_) => _step(1),
                onEditingComplete: () {}, // Enter keeps the focus here
              ),
            ),
            Text(
              _matches.isEmpty ? '' : '${_current + 1}/${_matches.length}',
              style: theme.ui(t.textMuted, size: 11.5),
            ),
            IconTap(
              Icons.close,
              size: 13,
              tooltip: 'Close  Esc',
              onTap: _close,
            ),
          ],
        ),
      ),
    );
  }
}
