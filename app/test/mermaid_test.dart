import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/mermaid.dart';
import 'package:nushi/theme/theme.dart';

const _flow = 'graph TD\n  A[Start] --> B[End]';

/// A 1×1 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGA'
  'WjR9awAAAABJRU5ErkJggg==',
);

/// What the Mac's renderer was asked, and its answers: a picture of each,
/// or an error for one that says "oops".
final _asked = <(String, bool, double)>[];
Completer<void>? _hold;

Future<DrawnDiagram> _draw(
  String source, {
  required bool dark,
  required double width,
  required Color background,
  required Color foreground,
}) async {
  _asked.add((source, dark, width));
  await _hold?.future;
  if (source.contains('oops')) {
    return const DrawnDiagram(
      error: 'Parse error on line 2: Expecting a node, got oops',
    );
  }
  return DrawnDiagram(png: Uint8List.fromList(_png), width: 300, height: 120);
}

Future<void> _show(WidgetTester tester, String text, {bool live = false}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: AgentMarkdown(text, live: live),
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    _asked.clear();
    _hold = null;
    forgetDiagrams();
    drawDiagram = _draw;
  });

  testWidgets('a mermaid block: drawing, then the diagram, and its Source', (
    tester,
  ) async {
    _hold = Completer();
    await _show(tester, 'Here:\n\n```mermaid\n$_flow\n```\n');
    expect(find.text('Drawing the diagram…'), findsOneWidget);
    expect(find.text('Mermaid'), findsOneWidget);
    expect(find.text('Diagram'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    // Asked once, dark, at the block's width (the page's 2 points of border
    // aside).
    expect(_asked.single.$1, _flow);
    expect(_asked.single.$2, isTrue);
    expect(_asked.single.$3, inInclusiveRange(590, 600));
    _hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Drawing the diagram…'), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.width, image.height), (300, 120));
    expect(find.textContaining('A[Start]', findRichText: true), findsNothing);
    // Source: the text, no picture.
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('A[Start]', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Diagram'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    // Built again (a message re-rendered): drawn once, kept.
    await _show(tester, 'Here, again:\n\n```mermaid\n$_flow\n```\n');
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(_asked, hasLength(1));
  });

  testWidgets('a diagram that fails to parse: its source, and the error in '
      'one muted line', (tester) async {
    await _show(tester, '```mermaid\ngraph TD\n  oops -->\n```');
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('oops -->', findRichText: true), findsOneWidget);
    final error = find.text(
      'Parse error on line 2: Expecting a node, got oops',
    );
    expect(error, findsOneWidget);
    final line = tester.widget<Text>(error);
    expect(line.maxLines, 1);
    expect(line.style?.color, Tokens.dark.textMuted);
  });

  testWidgets('a drawing that failed for a passing reason (the web view '
      "stopped) is drawn again; a diagram's own error isn't", (tester) async {
    var stopped = true;
    drawDiagram =
        (
          source, {
          required dark,
          required width,
          required background,
          required foreground,
        }) async {
          if (stopped && !source.contains('oops')) {
            stopped = false;
            _asked.add((source, dark, width));
            return const DrawnDiagram(
              error: "The diagram's web view stopped",
              retry: true,
            );
          }
          return await _draw(
            source,
            dark: dark,
            width: width,
            background: background,
            foreground: foreground,
          );
        };
    const text = '```mermaid\n$_flow\n```\n\n```mermaid\ngraph TD\n  oops\n```';
    await _show(tester, text);
    await tester.pumpAndSettle();
    expect(find.text("The diagram's web view stopped"), findsOneWidget);
    expect(_asked, hasLength(2));
    await _show(tester, '$text\n'); // built again: asked again, drawn
    await tester.pumpAndSettle();
    expect(find.text("The diagram's web view stopped"), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(
      [for (final a in _asked) a.$1.contains('oops')],
      [false, true, false],
    );
  });

  testWidgets('a block still streaming in isn’t drawn: its source shows', (
    tester,
  ) async {
    await _show(tester, 'Drawing it:\n\n```mermaid\n$_flow', live: true);
    await tester.pumpAndSettle();
    expect(_asked, isEmpty);
    expect(find.byType(Image), findsNothing);
    expect(find.text('Diagram'), findsNothing);
    expect(find.textContaining('A[Start]', findRichText: true), findsOneWidget);
    // Its fence closed, while the message still streams: drawn.
    await _show(
      tester,
      'Drawing it:\n\n```mermaid\n$_flow\n```\nNow',
      live: true,
    );
    await tester.pumpAndSettle();
    expect(_asked.single.$1, _flow);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('the phone: the source and Show diagram, which opens it', (
    tester,
  ) async {
    final shown = <String>[];
    showDiagram = (_, source) => shown.add(source);
    addTearDown(() => showDiagram = null);
    await _show(tester, '```mermaid\n$_flow\n```');
    await tester.pumpAndSettle();
    expect(_asked, isEmpty);
    expect(find.text('Source'), findsNothing);
    expect(find.textContaining('A[Start]', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Show diagram'));
    expect(shown, [_flow]);
  });

  testWidgets('the phone’s page: the app’s, its script beside it, the '
      'diagram’s text kept out of the markup', (tester) async {
    final page = await tester.runAsync(
      () => phoneDiagramPage(
        'graph TD\n  A["</script><b>"] --> B',
        dark: true,
        background: const Color(0xFF1E1F22),
        foreground: const Color(0xFFDFE1E5),
      ),
    );
    expect(page, startsWith('<!doctype html>'));
    expect(page, contains('<head>\n<base href="assets/assets/mermaid/">'));
    expect(page, contains('<script src="mermaid.min.js"></script>'));
    expect(
      page,
      contains(r'show("graph TD\n  A[\"\u003c/script>\u003cb>\"] --> B"'),
    );
    expect(page, contains('"background":"#1e1f22"'));
    expect('</script>'.allMatches(page!).length, 3);
  });
}
