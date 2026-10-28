import 'package:flutter/material.dart';
import 'package:nushi/mermaid.dart';
import 'package:nushi/phone/page_frame.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/theme/theme.dart';

/// A Mermaid diagram on the phone: mermaid.js draws [source] in the
/// sandboxed frame pages show in ([PageFrame]), in the app's colors.
class DiagramFrame extends StatefulWidget {
  const new(this.source, {super.key});

  final String source;

  @override
  State<DiagramFrame> createState() => _DiagramFrameState();
}

class _DiagramFrameState extends State<DiagramFrame> {
  Future<String>? _page;
  Object? _for;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final dark = t.brightness == Brightness.dark;
    if (_for != (widget.source, dark)) {
      _for = (widget.source, dark);
      _page = phoneDiagramPage(
        widget.source,
        dark: dark,
        background: t.base,
        foreground: t.text,
      );
    }
    return FutureBuilder(
      future: _page,
      builder: (context, snap) => switch (snap.data) {
        final html? => PageFrame(html, key: ValueKey(html)),
        _ => const SizedBox.expand(),
      },
    );
  }
}

/// A transcript's diagram full screen, from its block's Show diagram.
class DiagramScreen extends StatelessWidget {
  const new(this.source, {super.key});

  final String source;

  /// Pushes it.
  static void open(BuildContext context, String source) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => DiagramScreen(source)))
          .ignore();

  @override
  Widget build(BuildContext context) =>
      PhoneScreen(title: 'Diagram', body: DiagramFrame(source));
}
