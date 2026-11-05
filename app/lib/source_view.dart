import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:nushi/preview_text.dart';
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
  int _reads = 0; // a highlight lands only for the latest read

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
    final read = ++_reads;
    _text = widget.path.toLowerCase().endsWith('.json')
        ? prettyJson(text)
        : text;
    _lines = _text.split('\n');
    if (_lines.length > 1 && _lines.last.isEmpty) _lines.removeLast();
    _spans = null;
    if (languageOf(widget.path) case final language?) {
      highlightSides(language, '', _text).then((s) {
        if (mounted && read == _reads && s[1] != null) {
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
