import 'dart:async';

import 'package:flutter/services.dart';

import 'package:nushi/mermaid.dart';

const _channel = MethodChannel('nushi/mermaid');

/// How long a diagram waits on the Mac's web view, its queue included.
Duration diagramWait = const Duration(minutes: 1);

/// The Mac's diagrams: mermaid.js in one hidden web view (`nushi/mermaid`,
/// `macos/Runner/Diagrams.swift`). The web view gives each diagram 10 s, so
/// a slow one doesn't hold the rest; a call that waits past [diagramWait]
/// (the window's side never answered) fails, to be drawn again when next
/// asked for.
class MacDiagrams implements Diagrams {
  const new();

  @override
  Future<DrawnDiagram> draw(
    String source, {
    required bool dark,
    required double width,
    required Color background,
    required Color foreground,
  }) async {
    try {
      final r = await _channel
          .invokeMapMethod<String, Object?>('draw', {
            'source': source,
            'dark': dark,
            'width': width,
            'background': cssColor(background),
            'foreground': cssColor(foreground),
          })
          .timeout(diagramWait);
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
    } on TimeoutException {
      return const DrawnDiagram(
        error: 'The diagram took too long to draw',
        retry: true,
      );
    } on Object catch (e) {
      return DrawnDiagram(
        error: e is PlatformException ? '${e.message}' : '$e',
        retry: true,
      );
    }
  }
}

/// The path of the app's mermaid.html (its assets), for the preview pane's
/// web view.
Future<String> diagramPage() async =>
    await _channel.invokeMethod<String>('page') ?? '';
