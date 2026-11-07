import 'dart:math';

import 'package:re_editor/re_editor.dart';

/// Whether the file at [path], holding [text], indents with tabs (ADR
/// 0096): a Makefile or a Go file always, any other when more lines start
/// with a tab than with two spaces. re_editor's own indenting knows only
/// spaces, so the editor's Tab, ⇧Tab and Return go to [tabIndent],
/// [tabOutdent] and [tabNewLine] for these.
bool indentsWithTabs(String path, String text) {
  final name = path.split('/').last.toLowerCase();
  if (name == 'makefile' ||
      name == 'gnumakefile' ||
      name.endsWith('.mk') ||
      name.endsWith('.go')) {
    return true;
  }
  final tabs = _tabLine.allMatches(text).length;
  return tabs > 0 && tabs > _spaceLine.allMatches(text).length;
}

final _tabLine = RegExp(r'^\t', multiLine: true);
final _spaceLine = RegExp('^  ', multiLine: true);
final _spaces = RegExp('^ +');

/// Tab: a tab in place of the selection within a line, or one more at the
/// start of each selected line.
CodeLineEditingValue tabIndent(CodeLineEditingValue v) {
  final s = v.selection;
  final lines = CodeLines.from(v.codeLines);
  final whole = s.startOffset == 0 && s.endOffset == lines[s.endIndex].length;
  if (s.isSameLine && (s.isCollapsed || !whole)) {
    final t = lines[s.startIndex].text;
    lines[s.startIndex] = lines[s.startIndex].copyWith(
      text: '${t.substring(0, s.startOffset)}\t${t.substring(s.endOffset)}',
    );
    return v.copyWith(
      codeLines: lines,
      selection: CodeLineSelection.collapsed(
        index: s.startIndex,
        offset: s.startOffset + 1,
      ),
    );
  }
  final (first, last) = _rows(s);
  for (var i = first; i <= last; i++) {
    lines[i] = lines[i].copyWith(text: '\t${lines[i].text}');
  }
  return v.copyWith(
    codeLines: lines,
    selection: _moved(s, first, last, (i, o) => o + 1),
  );
}

/// ⇧Tab: one tab, or up to four spaces, off the start of each selected
/// line.
CodeLineEditingValue tabOutdent(CodeLineEditingValue v) {
  final s = v.selection;
  final lines = CodeLines.from(v.codeLines);
  final (first, last) = _rows(s);
  final cut = <int, int>{};
  for (var i = first; i <= last; i++) {
    final t = lines[i].text;
    final n = t.startsWith('\t')
        ? 1
        : min(4, t.length - t.replaceFirst(_spaces, '').length);
    cut[i] = n;
    lines[i] = lines[i].copyWith(text: t.substring(n));
  }
  return v.copyWith(
    codeLines: lines,
    selection: _moved(s, first, last, (i, o) => max(0, o - cut[i]!)),
  );
}

/// Return: a new line starting with the whitespace, tabs included, that
/// starts the line before it; between brackets (`{|}`), a line one tab
/// further in between them.
CodeLineEditingValue tabNewLine(CodeLineEditingValue v) {
  final s = v.selection;
  final before = v.codeLines[s.startIndex].text.substring(0, s.startOffset);
  final after = v.codeLines[s.endIndex].text.substring(s.endOffset);
  final indent = before.substring(
    0,
    before.length - before.replaceFirst(RegExp(r'^[ \t]+'), '').length,
  );
  final lines = v.codeLines.sublines(0, s.startIndex)..add(CodeLine(before));
  final between =
      before.isNotEmpty &&
      after.isNotEmpty &&
      _closers[before[before.length - 1]] == after[0];
  if (between) lines.add(CodeLine('$indent\t'));
  lines.add(CodeLine('$indent$after'));
  if (s.endIndex + 1 < v.codeLines.length) {
    lines.addFrom(v.codeLines, s.endIndex + 1);
  }
  return v.copyWith(
    codeLines: lines,
    selection: CodeLineSelection.collapsed(
      index: s.startIndex + 1,
      offset: indent.length + (between ? 1 : 0),
    ),
  );
}

const _closers = {'{': '}', '(': ')', '[': ']'};

/// The lines a selection covers, less a last one it only reaches the start
/// of.
(int, int) _rows(CodeLineSelection s) {
  final last = s.endOffset == 0 && s.endIndex > s.startIndex
      ? s.endIndex - 1
      : s.endIndex;
  return (s.startIndex, last);
}

/// [s] with the offsets on lines [first] to [last] moved by [to].
CodeLineSelection _moved(
  CodeLineSelection s,
  int first,
  int last,
  int Function(int index, int offset) to,
) {
  int at(int i, int o) => i >= first && i <= last ? to(i, o) : o;
  return s.copyWith(
    baseOffset: at(s.baseIndex, s.baseOffset),
    extentOffset: at(s.extentIndex, s.extentOffset),
  );
}
