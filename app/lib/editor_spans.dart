import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:nushi/editor_ink.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/settings.dart' show tabSize;
import 'package:nushi/source_spans.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';
import 'package:re_editor/re_editor.dart';

/// The spans the file editor lays each line out from (`FileEdit`'s span
/// builder): the syntax's colours, as the preview's source has them
/// (SourceView), tab stops, and what [ink] draws on the editor's fills.
class EditorSpans {
  new(this.path);

  /// The file, as its tab names it: its name picks the syntax.
  final String path;

  /// The editor's text, from [start].
  late final CodeLineEditingController controller;

  /// Draws [controller]'s lines, its text highlighted now.
  void start(CodeLineEditingController controller) {
    this.controller = controller;
    _highlight();
  }

  // The syntax's spans: the whole text highlighted off the UI thread a
  // moment after it changes; until then a line keeps its spans while its
  // text is as it was, at its index or as far from the end.
  Timer? _soon;
  int _reads = 0;
  List<String> _hlLines = const [];
  List<Uint32List?> _hlSpans = const [];
  bool _disposed = false;

  /// The text changed: it's highlighted again once typing pauses.
  void changed() {
    _soon?.cancel();
    _soon = Timer(Waits.typing, _highlight);
  }

  void _highlight() {
    final text = controller.codeLines.asString(TextLineBreak.lf);
    final language = sourceLanguage(path, text);
    if (language == null) return;
    final read = ++_reads;
    highlightSides(language, '', text).then((s) {
      if (read != _reads || _disposed || s[1] == null) return;
      _hlLines = text.split('\n');
      _hlSpans = s[1]!;
      controller.forceRepaint();
    }).ignore();
  }

  /// Whether the syntax's spans came (tests wait for them).
  bool get highlighted => _hlLines.isNotEmpty;

  Uint32List? _spansAt(int i, String line) {
    if (i < _hlLines.length && _hlLines[i] == line) {
      return _hlSpans.elementAtOrNull(i);
    }
    final j = i + _hlLines.length - controller.codeLines.length;
    if (j >= 0 && j < _hlLines.length && _hlLines[j] == line) {
      return _hlSpans.elementAtOrNull(j);
    }
    return null;
  }

  /// What the open editor paints under its lines (its selection, a
  /// find's hits): set while one shows this file, so its code keeps its
  /// contrast there ([EditorInk]).
  EditorInk? ink;

  // Each line's spans as last built, and what they were built from: a
  // line laid out again (each frame of a scroll) keeps them, so its runs
  // aren't split again for its syntax, tabs and fills.
  final _built = <int, _Built>{};

  /// Line [index]'s spans, for re_editor's `spanBuilder`.
  TextSpan line({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    final t = NushiTheme.of(context).t;
    final line = codeLine.text;
    final spans = _spansAt(index, line);
    final size = tabSize.value;
    final marks = ink?.key(context, index);
    final was = _built[index];
    final same =
        was != null &&
        identical(was.spans, spans) &&
        was.size == size &&
        identical(was.tokens, t) &&
        was.style == style &&
        was.line == line;
    if (same && was.marks == marks) return was.span;
    final runs = same ? was.runs : spansOf(t, line, spans);
    final inked = ink?.line(context, index, runs) ?? runs;
    // Only what's on the fills changed, and it's drawn as it was.
    if (same && (identical(inked, was.inked) || listEquals(inked, was.inked))) {
      was.marks = marks;
      return was.span;
    }
    final span = _LineSpan(
      style: style.copyWith(fontFeatures: _noLigatures),
      // re_editor draws with no text scaling.
      children: tabStops(
        inked,
        fontSize: style.fontSize!,
        column: columnWidth(style, TextScaler.noScaling),
        tabSize: size,
        spacing: style.letterSpacing ?? 0,
      ),
    );
    if (_built.length > 1024) _built.clear();
    _built[index] = _Built(
      line,
      spans,
      size,
      style,
      t,
      marks,
      runs,
      inked,
      span,
    );
    return span;
  }

  /// No more highlighting for an editor that's gone.
  void dispose() {
    _disposed = true;
    _soon?.cancel();
  }
}

/// A line's spans as last built, and what from: its text, the syntax's
/// spans, the tab size, the style and colours, what the ink drew it for
/// ([marks]), the runs and what the ink made of them.
class _Built {
  new(
    this.line,
    this.spans,
    this.size,
    this.style,
    this.tokens,
    this.marks,
    this.runs,
    this.inked,
    this.span,
  );

  final String line;
  final Uint32List? spans;
  final int size;
  final TextStyle style;
  final Tokens tokens;
  Object? marks;
  final List<TextSpan> runs;
  final List<TextSpan> inked;
  final TextSpan span;
}

/// A line's spans with their hash worked out once: re_editor finds the
/// paragraph it laid out for a line by its spans, each time it lays the
/// line out (each frame of a scroll), and a long line's hash walks every
/// run of it.
class _LineSpan extends TextSpan {
  new({super.style, super.children});

  @override
  // TextSpan's own hash, kept: it's immutable, so it agrees with its
  // equality, which stays TextSpan's.
  // ignore: hash_and_equals
  late final int hashCode = super.hashCode;
}

const _noLigatures = [FontFeature.disable('liga'), FontFeature.disable('calt')];
