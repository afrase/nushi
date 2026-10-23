import 'dart:math';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
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
    _theme = Theme.of(context).brightness == Brightness.dark
        ? DiffThemeData.dark()
        : DiffThemeData.light();
    final diff = TextDiff.compute(d.oldText, d.newText, path: d.path);
    _controller?.dispose();
    _controller = DiffViewController(
      document: diff.document,
      lines: diff.lines,
      theme: _theme,
      devicePixelRatio: dpr,
    );
    final doc = diff.document;
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
