import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_views.dart';

/// What draws a Mermaid file in the preview pane: on the Mac a WKWebView
/// of the app's mermaid.html (`diagram_page_macos.dart`);
/// [WebViews.diagram] makes one.
abstract interface class DiagramHost {
  /// The view; built once and kept.
  Widget view(BuildContext context);

  /// Draws [source] in place of what showed (or its source and the error,
  /// when it doesn't parse).
  Future<void> show(
    String source, {
    required bool dark,
    required Color background,
    required Color foreground,
  });

  void dispose();
}

/// A Mermaid file in [host] (made once), following [watch]: drawn again
/// each time the file or the app's theme changes. Until the first answer,
/// a note in its place.
class DiagramView extends StatefulWidget {
  const new({required this.host, required this.watch, super.key});

  final DiagramHost host;
  final FileWatch watch;

  @override
  State<DiagramView> createState() => _DiagramViewState();
}

class _DiagramViewState extends State<DiagramView> {
  Object? _shown; // (the file as sent, dark)

  @override
  void initState() {
    super.initState();
    widget.watch.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _changed();
  }

  @override
  void dispose() {
    widget.watch.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final f = widget.watch.file;
    if (!mounted || f == null || f.missing || f.tooLarge) return;
    final t = NushiTheme.of(context).t;
    final dark = t.brightness == Brightness.dark;
    final shown = (f, dark);
    if (shown == _shown) return;
    final first = _shown == null;
    _shown = shown;
    unawaited(
      widget.host.show(
        utf8.decode(f.data, allowMalformed: true),
        dark: dark,
        background: t.base,
        foreground: t.text,
      ),
    );
    if (first) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_shown == null) {
      return ListenableBuilder(
        listenable: widget.watch,
        builder: (context, _) =>
            previewStatus(context, widget.watch) ?? const SizedBox.shrink(),
      );
    }
    return ClearOfEdge(child: widget.host.view(context));
  }
}
