import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/review.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/sent_comments.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _old = '''
package main

import (
	"fmt"
	"os"
)

func main() {
	name := os.Getenv("NAME")
	if name == "" {
		name = "world"
	}
	fmt.Println("hello", name)
}

func greet(name string) string {
	return "hello " + name
}
''';

const _new = '''
package main

import (
	"flag"
	"fmt"
)

func main() {
	name := flag.String("name", "world", "who to greet")
	flag.Parse()
	fmt.Println(greet(*name))
}

func greet(name string) string {
	return "hello " + name
}

func shout(name string) string {
	return greet(name) + "!"
}
''';

/// A first line long enough to reach the pill's corner at any width.
const _long =
    '// Package main greets whoever it is given on the command line, '
    'by name, and says hello to the world when it is given nobody at all.\n';

ReviewComment _comment(
  String id,
  int start,
  int end,
  String quote,
  String text, {
  bool sent = false,
}) => ReviewComment(
  id: id,
  where: 'uncommitted',
  path: 'main.go',
  old: false,
  start: start,
  end: end,
  quote: quote,
  text: text,
  sent: sent,
  seen: sent ? 1 : null,
);

/// Sent, and the agent has since rewritten their lines.
final _sentGone = <ReviewComment Function()>[
  () => _comment(
    '1',
    10,
    11,
    '\tif name == "" {\n\t\tname = "world"',
    'Should this be a setting?',
    sent: true,
  ),
  () => _comment(
    '2',
    13,
    13,
    '\tfmt.Println("hello", name)',
    'Use greet here, so the two stay the same.',
    sent: true,
  ),
];

/// Not sent, on lines the file still has.
ReviewComment _onLines() => _comment(
  '3',
  18,
  20,
  'func shout(name string) string {\n\treturn greet(name) + "!"\n}',
  'Nothing calls this yet. Is it needed?',
);

void main() {
  setUpAll(loadFonts);

  /// The app on chat c's Changes while its agent works (so sent comments
  /// stay, [filesRead]), main.go changed and [comments] on it.
  Future<Daemon> open(
    WidgetTester tester,
    List<ReviewComment> comments, {
    double width = 1700,
    Brightness brightness = Brightness.dark,
    String newText = _new,
  }) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
    showDetails.value = false;
    final files = [
      FileChange(path: 'main.go', oldText: _old, newText: newText, added: 9),
    ];
    final fake = FakeDaemon([chat('c', 'claude', 'Greeter')])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'greeter',
          defaultBase: 'main',
        ),
        GetDiffRequest() => GetDiffResponse(files: files),
        _ => null,
      };
    final d = await openApp(
      tester,
      fake,
      size: Size(width, 820),
      brightness: brightness,
    );
    setComments('c', comments);
    d.chats['c']!
      ..status(ChatStatus(busy: true))
      ..notifyListeners()
      ..tab.value = ChatTab.changes;
    await settle(tester);
    // From the file's top: the view may open at its first change.
    await tester.drag(find.byType(DiffBox), const Offset(0, 800));
    await settle(tester);
    return d;
  }

  Finder pill([int n = 2]) => find.text('$n sent');
  final heading = find.text('Sent to the agent. The lines changed since.');

  testWidgets('sent comments whose lines changed: one pill, not cards; '
      'the others stay cards', (tester) async {
    final d = await open(tester, [
      for (final c in _sentGone) c(),
      _onLines(),
      // Not sent, its lines gone: a card, to send or remove.
      _comment('4', 6, 6, '\t"os"', 'Is os still used?'),
    ]);
    expect(pill(), findsOne);
    expect(find.byType(SentComments), findsOne);
    expect(find.text('Should this be a setting?'), findsNothing);
    expect(
      find.text('Use greet here, so the two stay the same.'),
      findsNothing,
    );
    expect(find.byType(CommentCard), findsNWidgets(2));
    expect(find.text('Nothing calls this yet. Is it needed?'), findsOne);
    expect(find.text('Is os still used?'), findsOne);
    expect(find.text('Outdated'), findsOne); // the unsent one's
    d.dispose();
  }, variant: onMac);

  testWidgets('none sent and changed: no pill', (tester) async {
    final d = await open(tester, [
      _onLines(),
      // Sent, its lines still there: a card, dimmed.
      _comment(
        '5',
        14,
        14,
        'func greet(name string) string {',
        'Fine as it is.',
        sent: true,
      ),
    ]);
    expect(find.byType(SentComments), findsNothing);
    expect(find.textContaining(' sent'), findsNothing);
    expect(find.byType(CommentCard), findsNWidgets(2));
    expect(find.text('Sent'), findsOne);
    d.dispose();
  }, variant: onMac);

  testWidgets('the pill opens its list; a click on it, outside it or '
      'Escape closes it', (tester) async {
    final d = await open(tester, [for (final c in _sentGone) c()]);
    await tester.tap(pill());
    await settle(tester);
    expect(heading, findsOne);
    expect(find.text('Lines 10–11'), findsOne);
    expect(find.text('Line 13'), findsOne);
    expect(find.text('\tfmt.Println("hello", name)'), findsOne);
    expect(find.text('Should this be a setting?'), findsOne);

    await tester.tap(pill());
    await settle(tester);
    expect(heading, findsNothing);

    await tester.tap(pill());
    await settle(tester);
    expect(heading, findsOne);
    await tester.tapAt(const Offset(1000, 700));
    await settle(tester);
    expect(heading, findsNothing);

    await tester.tap(pill());
    await settle(tester);
    expect(heading, findsOne);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(heading, findsNothing);
    d.dispose();
  }, variant: onMac);

  testWidgets('Remove takes one out; the pill goes with the last', (
    tester,
  ) async {
    final d = await open(tester, [for (final c in _sentGone) c(), _onLines()]);
    await tester.tap(pill());
    await settle(tester);
    final inList = find.descendant(
      of: find.ancestor(of: heading, matching: find.byType(Material)).first,
      matching: find.byTooltip('Remove'),
    );
    expect(inList, findsNWidgets(2));
    await tester.tap(inList.first);
    await settle(tester);
    expect(commentsOf('c').map((c) => c.id), ['2', '3']);
    expect(pill(1), findsOne);
    expect(find.text('Should this be a setting?'), findsNothing);
    expect(find.text('Use greet here, so the two stay the same.'), findsOne);

    await tester.tap(inList.first);
    await settle(tester);
    expect(commentsOf('c').map((c) => c.id), ['3']);
    expect(find.byType(SentComments), findsNothing);
    expect(heading, findsNothing);
    expect(find.text('Nothing calls this yet. Is it needed?'), findsOne);
    d.dispose();
  }, variant: onMac);

  for (final width in [1700.0, 720.0]) {
    testWidgets('its own row above a long first line, ${width.round()}', (
      tester,
    ) async {
      final d = await open(
        tester,
        [for (final c in _sentGone) c()],
        width: width,
        newText: _long + _new,
      );
      // The pill's row is above the first line, never over it.
      final diff = tester.getRect(find.byType(DiffBox));
      final row = tester.getRect(find.byType(SentComments));
      expect(row.top, diff.top);
      expect(row.height, SentComments.height);
      final p = tester.getRect(pill());
      expect(p.bottom, lessThanOrEqualTo(row.bottom));
      expect(p.right, lessThanOrEqualTo(diff.right));
      d.dispose();
    }, variant: onMac);
  }

  // The pill and its open list on their own, as a diff's top shows them.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, the pill and its list, $name', (tester) async {
      viewport(tester, const Size(460, 280));
      await tester.pumpWidget(
        themed(
          tokens: tokens,
          banner: false,
          Builder(
            builder: (context) => Container(
              alignment: Alignment.topCenter,
              color: NushiTheme.of(context).t.codeBlock,
              child: SentComments([
                for (final c in _sentGone) c(),
              ], onRemove: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sent_comments_$name.png'),
      );
      await tester.tap(pill());
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sent_comments_open_$name.png'),
      );
    }, variant: onMac);
  }

  // At full size: the pill, closed and open, and over a long first line.
  for (final (width, brightness) in [
    (1700.0, Brightness.dark),
    if (rendering) (1700.0, Brightness.light),
    (720.0, Brightness.dark),
    if (rendering) (720.0, Brightness.light),
  ]) {
    final tag = '${width.round()}_${brightness.name}';
    renderTest('renders: $tag', (tester) async {
      final d = await open(
        tester,
        [for (final c in _sentGone) c(), _onLines()],
        width: width,
        brightness: brightness,
      );
      await colours(tester);
      await render(tester, find.byType(NushiApp), 'sent_$tag');
      await renderPane(tester, 'sent_${tag}_pane');
      await tester.tap(pill());
      await settle(tester);
      await render(tester, find.byType(NushiApp), 'sent_open_$tag');
      await renderPane(tester, 'sent_open_${tag}_pane');
      d.dispose();
    }, variant: onMac);

    renderTest('renders: a long first line, $tag', (tester) async {
      final d = await open(
        tester,
        [for (final c in _sentGone) c()],
        width: width,
        brightness: brightness,
        newText: _long + _new,
      );
      await colours(tester);
      await renderPane(tester, 'sent_long_${tag}_pane');
      d.dispose();
    }, variant: onMac);
  }
}

/// Lets the view take what changed.
Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

/// The code's colours, which come from an isolate (`highlightSides`), for
/// a render: a moment on the real clock, never a check's wait.
Future<void> colours(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await settle(tester);
}

/// [render] of the diff pane alone, with the open list where it shows.
Future<void> renderPane(WidgetTester tester, String name) async {
  final dir = rendersDir;
  if (dir == null) return;
  var rect = tester.getRect(find.byType(DiffBox)).inflate(4);
  final list = find.text('Sent to the agent. The lines changed since.');
  if (list.evaluate().isNotEmpty) {
    final panel = find.ancestor(of: list, matching: find.byType(Material));
    rect = rect.expandToInclude(tester.getRect(panel.first).inflate(8));
  }
  final app = find.byType(NushiApp);
  final width = tester.getSize(app).width;
  await withRealShadows(tester, () async {
    final capture = captureImage(app.evaluate().single);
    await tester.runAsync(() async {
      final image = await capture;
      final scale = image.width / width;
      final from = Rect.fromLTRB(
        rect.left * scale,
        rect.top * scale,
        rect.right * scale,
        rect.bottom * scale,
      ).intersect(Offset.zero & Size(image.width + 0.0, image.height + 0.0));
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
          .drawImageRect(image, from, Offset.zero & from.size, Paint());
      final out = await recorder.endRecording().toImage(
        from.width.round(),
        from.height.round(),
      );
      try {
        final png = await out.toByteData(format: ui.ImageByteFormat.png);
        Directory(dir).createSync(recursive: true);
        File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      } finally {
        image.dispose();
        out.dispose();
      }
    });
  });
}
