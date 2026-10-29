import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A Mermaid diagram as the Mac drew it: a PNG of [width] by [height]
/// points, or the [error] that stopped it; with [retry] when that was the
/// drawing's, not the diagram's (its web view stopped, the snapshot or the
/// channel failed), so it's drawn again next time it's asked for.
@immutable
class DrawnDiagram {
  const new({
    this.png,
    this.width = 0,
    this.height = 0,
    this.error = '',
    this.retry = false,
  });

  final Uint8List? png;
  final double width;
  final double height;
  final String error;
  final bool retry;
}

/// Draws a diagram as a picture: on the Mac, mermaid.js in one hidden web
/// view (`nushi/mermaid`, MainFlutterWindow.swift), `width` points wide at
/// most, in the colors given. Tests set their own.
Future<DrawnDiagram> Function(
  String source, {
  required bool dark,
  required double width,
  required Color background,
  required Color foreground,
})
drawDiagram = _drawOnMac;

const _channel = MethodChannel('nushi/mermaid');

Future<DrawnDiagram> _drawOnMac(
  String source, {
  required bool dark,
  required double width,
  required Color background,
  required Color foreground,
}) async {
  try {
    final r = await _channel.invokeMapMethod<String, Object?>('draw', {
      'source': source,
      'dark': dark,
      'width': width,
      'background': cssColor(background),
      'foreground': cssColor(foreground),
    });
    if (r?['png'] case final Uint8List png) {
      return DrawnDiagram(
        png: png,
        width: (r!['width']! as num).toDouble(),
        height: (r['height']! as num).toDouble(),
      );
    }
    return DrawnDiagram(
      error: '${r?['error'] ?? 'Not drawn'}',
      retry: r?['retry'] == true,
    );
  } on Object catch (e) {
    return DrawnDiagram(
      error: e is PlatformException ? '${e.message}' : '$e',
      retry: true,
    );
  }
}

/// The path of the app's mermaid.html (its assets), for the preview pane's
/// web view; tests set their own.
Future<String> Function() diagramPage = () async =>
    await _channel.invokeMethod<String>('page') ?? '';

/// [c] as CSS's #rrggbb.
String cssColor(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Diagrams drawn, by their text and colors: each once, at the width of
/// the block that asked first (narrower blocks scale it down); one whose
/// drawing failed for a passing reason ([DrawnDiagram.retry]) is let go.
final _drawn = <(String, bool, Color), Future<DrawnDiagram>>{};

Future<DrawnDiagram> _drawnOnce(
  String source, {
  required bool dark,
  required double width,
  required Color background,
  required Color foreground,
}) {
  final key = (source, dark, background);
  if (_drawn.remove(key) case final f?) return _drawn[key] = f; // newest
  if (_drawn.length >= 100) _drawn.remove(_drawn.keys.first)?.ignore();
  final drawn = drawDiagram(
    source,
    dark: dark,
    width: width,
    background: background,
    foreground: foreground,
  );
  _drawn[key] = drawn;
  drawn.then((d) {
    if (d.retry && _drawn[key] == drawn) unawaited(_drawn.remove(key));
  }).ignore();
  return drawn;
}

/// Forgets the diagrams drawn (tests).
@visibleForTesting
void forgetDiagrams() => _drawn.clear();

/// What the phone does with a block's Show diagram: opens it full screen.
/// The phone's app sets it while it runs; null on the Mac, which draws
/// diagrams in place.
void Function(BuildContext context, String source)? showDiagram;

/// A ```` ```mermaid ```` block in Markdown (an agent's message, a Markdown
/// preview). Still streaming in ([open]), its source only: never half a
/// diagram. Once whole, on the Mac, the diagram as a picture
/// ([drawDiagram]) with Diagram and Source in its bar, and its source with
/// the error under it when it doesn't parse; on the phone, its source and
/// Show diagram ([showDiagram]), full screen in a frame.
class MermaidBlock extends StatefulWidget {
  const new(this.code, {required this.style, required this.open, super.key});

  final String code;
  final MarkdownStyle style;
  final bool open;

  @override
  State<MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends State<MermaidBlock> {
  bool _source = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final style = widget.style;
    final code = widget.code;
    if (widget.open) {
      return CodeBlockView(language: 'mermaid', code: code, style: style);
    }
    if (showDiagram case final show?) {
      return CodeBlockView(
        language: 'mermaid',
        code: code,
        style: style,
        actions: [
          TextButton(
            onPressed: () => show(context, code),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: theme.ui(t.link, size: 12),
            ),
            child: const Text('Show diagram'),
          ),
        ],
      );
    }
    return CodeBlockView(
      language: 'mermaid',
      code: code,
      style: style,
      actions: [
        Segmented(
          value: _source,
          segments: const [(false, 'Diagram'), (true, 'Source')],
          onChanged: (v) => setState(() => _source = v),
        ),
        const SizedBox(width: 2),
      ],
      body: _source ? null : _diagram(context),
    );
  }

  Widget _diagram(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final style = widget.style;
    final muted = theme.ui(style.muted, size: 12);
    return LayoutBuilder(
      builder: (context, box) => FutureBuilder(
        future: _drawnOnce(
          widget.code,
          dark: t.brightness == Brightness.dark,
          width: box.maxWidth.isFinite ? box.maxWidth.floorToDouble() : 800,
          background: style.codeBackground,
          foreground: style.body.color ?? t.text,
        ),
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) {
            return Padding(
              padding: const EdgeInsets.all(10),
              child: Text('Drawing the diagram…', style: muted),
            );
          }
          if (d.png case final png?) {
            final scale = math.min(1, box.maxWidth / d.width);
            return Align(
              alignment: Alignment.topLeft,
              child: Image.memory(
                png,
                width: d.width * scale,
                height: d.height * scale,
                fit: BoxFit.contain,
                semanticLabel: 'Diagram',
              ),
            );
          }
          // The source, as the bar's Source shows it, and why it isn't drawn.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CodeBlockView(
                language: 'mermaid',
                code: widget.code,
                style: style,
              ).codeText(widget.code),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Text(
                  d.error,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The page that draws [source] in the phone's sandboxed frame: the app's
/// mermaid.html, its script from the relay beside it (the frame's address
/// is the relay's frame.html; the web build keeps assets under
/// `assets/`), told to draw it at once in the app's colors.
Future<String> phoneDiagramPage(
  String source, {
  required bool dark,
  required Color background,
  required Color foreground,
}) async {
  final page = await rootBundle.loadString('assets/mermaid/mermaid.html');
  String js(Object o) => jsonEncode(o).replaceAll('<', r'\u003c');
  final opts = {
    'dark': dark,
    'background': cssColor(background),
    'foreground': cssColor(foreground),
    'center': true,
  };
  return page
      .replaceFirst('<head>', '<head>\n<base href="assets/assets/mermaid/">')
      .replaceFirst(
        '</body>',
        '<script>show(${js(source)}, ${js(opts)});</script>\n</body>',
      );
}
