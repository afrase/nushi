import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/mermaid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Security review 2026-11-04, L8: a diagram the Mac's web view never
  // answers for (a slow one ahead of it) left its block waiting for good.
  test(
    'a diagram the web view never answers fails, to be drawn again',
    () async {
      const channel = MethodChannel('nushi/mermaid');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(
              channel,
              (_) => Completer<Object?>().future, // never answers
            );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final wait = diagramWait;
      diagramWait = const Duration(milliseconds: 50);
      addTearDown(() => diagramWait = wait);
      final d = await drawDiagram(
        'graph TD; a-->b',
        dark: false,
        width: 400,
        background: Colors.white,
        foreground: Colors.black,
      ).timeout(const Duration(seconds: 5));
      expect(
        (d.png, d.error, d.retry),
        (null, 'The diagram took too long to draw', true),
      );
    },
  );
}
