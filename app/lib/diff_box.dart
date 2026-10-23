import 'dart:math';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'syntax.dart';
import 'theme/theme.dart';

/// A file's change side by side. With [fit] it is only as tall as the
/// change (up to fifteen lines, then it scrolls), in a thin frame; else as
/// tall as its box.
class DiffBox extends StatefulWidget {
  const DiffBox(this.change, {super.key, this.fit = true});

  final FileChange change;
  final bool fit;

  @override
  State<DiffBox> createState() => _DiffBoxState();
}

class _DiffBoxState extends State<DiffBox> {
  DiffViewController? _controller;
  late DiffThemeData _theme;
  double _height = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _build();
  }

  @override
  void didUpdateWidget(DiffBox old) {
    super.didUpdateWidget(old);
    if (old.change != widget.change) _build();
  }

  void _build() {
    final d = widget.change;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    _theme = diffTheme(NushiTheme.of(context).t);
    final diff = TextDiff.compute(d.oldText, d.newText, path: d.path);
    final doc = diff.document;
    final lines = SyntaxLines(diff.lines, doc.oldLineCount, doc.newLineCount);
    _controller?.dispose();
    _controller = DiffViewController(
      document: doc,
      lines: lines,
      theme: _theme,
      captureNames: syntaxCaptures,
      devicePixelRatio: dpr,
    );
    // Plain until the colors are in (a moment, off the UI thread).
    final controller = _controller;
    if (languageOf(d.path) case final language?) {
      highlightSides(language, d.oldText, d.newText).then((spans) {
        if (mounted && _controller == controller) lines.highlight(spans);
      }).ignore();
    }
    final rows = max(doc.oldLineCount, doc.newLineCount).clamp(1, 15);
    _height = _theme.lineHeightFor(dpr) * rows + 6;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = SideBySideDiff(
      controller: _controller!,
      theme: _theme,
      inlayBuilder: (context, spec) => const SizedBox.shrink(),
    );
    if (!widget.fit) return diff;
    return Container(
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: box(
        NushiTheme.of(context).t.borderSubtle,
        radius: NushiTheme.control,
      ),
      child: diff,
    );
  }
}
