import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/skills_list.dart' show revealInFinder;
import 'package:nushi/terminals.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/web_page.dart' show openLinkOrSay;
import 'package:xterm2/xterm.dart';

/// The terminal's text: the picked font, then the bundled Nerd Font
/// symbols, so file and prompt icons show whatever font is picked.
TerminalStyle terminalStyle() => TerminalStyle(
  fontFamily: terminalFont.value ?? NushiTheme.codeFont,
  fontFamilyFallback: const ['Symbols Nerd Font Mono', NushiTheme.codeFont],
  fontSize: terminalFontSize.value,
  height: 1.25,
);

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

/// Opens a URL in the browser, saying under [context] why when it doesn't
/// open, or shows a file: in the Changes view when [showChange] takes it
/// (it's changed), else in Finder.
Future<void> openLink(
  BuildContext context,
  String word,
  String folder,
  Future<bool> Function(String path) showChange,
) async {
  final link = linkOf(word, folder);
  if (link.url case final url?) {
    await openLinkOrSay(context, url);
  } else if (link.path case final path?) {
    if (!await showChange(path)) await revealInFinder(path);
  }
}

/// ⌘F over a terminal, in a [FindBar]: finds in its scrollback,
/// highlights every match and scrolls to the current one, starting from
/// the latest. ⏎ goes to the next one down (round from the latest to the
/// first), ⇧⏎ up. A match is keyed by where it starts.
class TerminalFind extends TranscriptFind {
  new(this.session);

  /// The session it finds in (its emulator is a new one after each attach).
  final TermSession session;
  List<TerminalSearchMatch> _matches = const [];

  @override
  set query(String? q) {
    if (q == query) return;
    super.query = q;
    final terminal = session.terminal;
    _matches = q == null || q.isEmpty ? const [] : terminal.search(q);
    foundFromLast([
      for (final m in _matches) '${m.range.begin.y}:${m.range.begin.x}',
    ]);
    session.controller.setSearchHighlights(terminal.buffer, [
      for (final m in _matches) m.range,
    ], currentIndex: at);
    _show();
  }

  @override
  void step(int by) {
    super.step(by);
    if (_matches.isEmpty) return;
    session.controller.setCurrentSearchHighlight(at);
    _show();
  }

  @override
  void close() {
    session.controller.clearSearchHighlights();
    _matches = const [];
    super.close();
    session.focus.requestFocus();
  }

  // Scrolls the current match to the middle of the screen.
  void _show() {
    final scroll = session.scroll;
    if (_matches.isEmpty || !scroll.hasClients) return;
    final style = terminalStyle();
    final lineHeight = style.fontSize * style.height;
    final y = _matches[at].range.begin.y - session.terminal.viewHeight / 2;
    scroll.jumpTo((y * lineHeight).clamp(0, scroll.position.maxScrollExtent));
  }
}
