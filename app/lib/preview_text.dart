import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';

/// A line shows this many characters at most (a minified file's one line).
const _maxLine = 5000;

/// A file's text, highlighted for its language (by [path]'s name, as diffs
/// are; off the UI thread, plain until then and past 200,000 characters),
/// its lines numbered and built as they scroll into view. JSON is
/// pretty-printed.
class SourceView extends StatefulWidget {
  const new(this.text, {required this.path, super.key, this.padding});

  final String text;
  final String path;
  final EdgeInsets? padding;

  @override
  State<SourceView> createState() => _SourceViewState();
}

class _SourceViewState extends State<SourceView> {
  String _text = '';
  List<String> _lines = const [];
  List<Uint32List?>? _spans;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(SourceView old) {
    super.didUpdateWidget(old);
    // The file changed: read again where it scrolled to.
    if (old.text != widget.text || old.path != widget.path) _read();
  }

  void _read() {
    final text = widget.text;
    _text = widget.path.toLowerCase().endsWith('.json')
        ? prettyJson(text)
        : text;
    _lines = _text.split('\n');
    if (_lines.length > 1 && _lines.last.isEmpty) _lines.removeLast();
    _spans = null;
    if (languageOf(widget.path) case final language?) {
      highlightSides(language, '', _text).then((s) {
        if (mounted && identical(text, widget.text) && s[1] != null) {
          setState(() => _spans = s[1]);
        }
      }).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final style = theme.code(t.text, size: 12);
    final gutter = theme.code(t.textMuted, size: 12);
    final digits = '${_lines.length}'.length;
    return SelectionArea(
      child: ListView.builder(
        padding: widget.padding,
        itemCount: _lines.length,
        itemBuilder: (context, i) {
          var line = _lines[i];
          final cut = line.length > _maxLine;
          if (cut) line = line.substring(0, _maxLine);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectionContainer.disabled(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text('${i + 1}'.padLeft(digits), style: gutter),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      ..._spansOf(t, line, _spans?.elementAtOrNull(i)),
                      if (cut)
                        TextSpan(
                          text: ' … (${line.length - _maxLine} more)',
                          style: gutter,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// [line] in runs of its syntax [spans] (`start, length, capture`
/// triples), plain where none.
List<TextSpan> _spansOf(Tokens t, String line, Uint32List? spans) {
  if (spans == null) return [TextSpan(text: line)];
  final out = <TextSpan>[];
  var at = 0;
  for (var k = 0; k + 2 < spans.length; k += 3) {
    final start = min(spans[k], line.length);
    final end = min(spans[k] + spans[k + 1], line.length);
    if (start > at) out.add(TextSpan(text: line.substring(at, start)));
    if (end <= start) continue;
    final ink = t.ink(Capture.values[spans[k + 2]]);
    out.add(
      TextSpan(
        text: line.substring(start, end),
        style: TextStyle(
          color: ink.color,
          fontStyle: ink.italic ? FontStyle.italic : null,
          fontWeight: ink.bold ? FontWeight.w700 : null,
        ),
      ),
    );
    at = end;
  }
  if (at < line.length) out.add(TextSpan(text: line.substring(at)));
  return out;
}

/// [text] indented two spaces a level, when it is JSON; else as it is.
String prettyJson(String text) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
  } on FormatException {
    return text;
  }
}

/// The first [keep] records of [text] read as CSV (RFC 4180: a quoted
/// field holds commas, line breaks and quotes doubled), and how many it has
/// in all.
(List<List<String>>, int) parseCsv(String text, {int keep = 1 << 30}) {
  final rows = <List<String>>[];
  var count = 0;
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var fresh = true; // nothing in the field yet, quotes or not
  void endField() {
    row.add(field.toString());
    field.clear();
    fresh = true;
  }

  void endRow() {
    endField();
    if (count < keep) rows.add(row);
    count++;
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (quoted) {
      if (c != 0x22) {
        field.writeCharCode(c);
      } else if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x22) {
        field.writeCharCode(0x22);
        i++;
      } else {
        quoted = false;
      }
      continue;
    }
    switch (c) {
      case 0x22 when fresh:
        quoted = true;
        fresh = false;
      case 0x2C:
        endField();
      case 0x0D when i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A:
        break; // the \n ends it
      case 0x0A || 0x0D:
        endRow();
      default:
        field.writeCharCode(c);
        fresh = false;
    }
  }
  if (!fresh || row.isNotEmpty) endRow();
  return (rows, count);
}

/// A CSV file as a table: its first row the header, then up to
/// [CsvTable.rows] rows (saying so when there are more), each column as
/// wide as its longest cell, up to 40 characters; wider than the pane, it
/// scrolls sideways.
class CsvTable extends StatefulWidget {
  const new(this.text, {super.key, this.padding});

  /// How many rows under the header show.
  static const rows = 500;

  final String text;
  final EdgeInsets? padding;

  @override
  State<CsvTable> createState() => _CsvTableState();
}

class _CsvTableState extends State<CsvTable> {
  late (List<List<String>>, int) _csv = _parse();
  (List<List<String>>, int) _parse() =>
      parseCsv(widget.text, keep: CsvTable.rows + 1);

  @override
  void didUpdateWidget(CsvTable old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _csv = _parse();
  }

  final _across = ScrollController();

  @override
  void dispose() {
    _across.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final (rows, total) = _csv;
    if (rows.isEmpty) {
      return Center(
        child: Text('An empty file.', style: theme.ui(t.textSecondary)),
      );
    }
    final style = theme.code(t.text, size: 12);
    final head = style.copyWith(fontWeight: FontWeight.w600);
    final columns = rows.map((r) => r.length).reduce(max);
    final zero = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final char = zero.width;
    zero.dispose();
    final widths = [
      for (var c = 0; c < columns; c++)
        rows
                    .map((r) => c < r.length ? r[c].length : 0)
                    .reduce(max)
                    .clamp(3, 40) *
                char +
            // The padding, and a character's slack (the header is bold).
            20 +
            char,
    ];
    final width = widths.fold(0.0, (a, w) => a + w);
    final pad = widget.padding ?? EdgeInsets.zero;
    Widget row(List<String> cells, TextStyle style, {bool header = false}) =>
        DecoratedBox(
          decoration: BoxDecoration(
            color: header ? t.raised : null,
            border: Border(
              bottom: BorderSide(
                color: header ? t.borderStrong : t.borderSubtle,
              ),
            ),
          ),
          child: Row(
            children: [
              for (var c = 0; c < columns; c++)
                SizedBox(
                  width: widths[c],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      c < cells.length ? cells[c] : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ),
            ],
          ),
        );
    final body = rows.length - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (total - 1 > body)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'The first $body rows of ${total - 1}.',
                style: theme.ui(t.textMuted, size: 12),
              ),
            ),
          Expanded(
            child: Scrollbar(
              controller: _across,
              child: SingleChildScrollView(
                controller: _across,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        row(rows.first, head, header: true),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.only(bottom: pad.bottom),
                            itemCount: body,
                            itemBuilder: (context, i) =>
                                row(rows[i + 1], style),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
