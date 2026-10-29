import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/paced.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Widget _app(Widget child, {bool still = false}) => MaterialApp(
  theme: const NushiTheme(Tokens.dark).toThemeData(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: child),
  ),
);

const _words =
    'I split the app tests into two shards so the slowest job takes half '
    'the time and both shards start at once on the same runner. ';

/// The message's text as drawn, without the caret.
String _drawn(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText().replaceAll('￼', ''))
    .where((s) => s.startsWith('I split'))
    .join()
    .trimRight();

/// The least opacity a span of the message is drawn at.
double _faintest(WidgetTester tester) {
  var least = 1.0;
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    r.text.visitChildren((s) {
      final a = s.style?.color?.a;
      if (s is TextSpan && s.text != null && a != null && a < least) least = a;
      return true;
    });
  }
  return least;
}

void main() {
  setUpAll(loadFonts);

  Future<(ChatState, void Function())> open(
    WidgetTester tester, {
    bool still = false,
    String text = '',
  }) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')
      ..loaded = true
      ..busy = true
      ..items.addAll([
        Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Go'),
        if (text.isNotEmpty)
          Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text),
      ]);
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: chat,
          builder: (context, _) =>
              Transcript(chat: chat, daemon: d, onReply: null),
        ),
        still: still,
      ),
    );
    return (chat, d.dispose);
  }

  void stream(ChatState chat, String text) {
    final i = chat.items.indexWhere((it) => it.id == 'm');
    final it = Item(
      id: 'm',
      kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
      text: text,
    );
    if (i < 0) {
      chat.items.add(it);
    } else {
      chat.items[i] = it;
    }
    chat.notifyListeners();
  }

  testWidgets('a reply that streams shows whole words at a steady pace, a '
      'soft caret at its end, what is new fading in', (tester) async {
    final (chat, done) = await open(tester);
    stream(chat, _words);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    final part = _drawn(tester);
    expect(part.length, inExclusiveRange(0, _words.length));
    expect(_words.startsWith(part), isTrue);
    expect(
      part.endsWith(' ') || _words[part.length] == ' ',
      isTrue,
      reason: 'whole words: "$part"',
    );
    expect(find.byType(SoftCaret), findsOneWidget);
    expect(_faintest(tester), lessThan(0.95));

    // Never slower than the stream: within about 220 ms of it.
    await tester.pump(const Duration(milliseconds: 500));
    expect(_drawn(tester), _words.trimRight());
    expect(find.byType(SoftCaret), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_faintest(tester), 1);

    // The stream ends: the caret fades and the message is as written.
    chat
      ..busy = false
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(SoftCaret), findsNothing);
    await tester.pumpWidget(const SizedBox());
    done();
  });

  testWidgets('once the stream ends, the rest shows within 250 ms', (
    tester,
  ) async {
    final (chat, done) = await open(tester);
    stream(chat, 'I split ');
    await tester.pump();
    await tester.pumpAndSettle();
    stream(chat, 'I split $_words$_words$_words');
    chat
      ..busy = false
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_drawn(tester), 'I split $_words$_words$_words'.trimRight());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    done();
  });

  testWidgets('what the chat opened with, and Reduce Motion, show at once', (
    tester,
  ) async {
    var (chat, done) = await open(tester, text: _words);
    expect(_drawn(tester), _words.trimRight());
    await tester.pumpWidget(const SizedBox());
    done();

    (chat, done) = await open(tester, still: true);
    stream(chat, _words);
    await tester.pump();
    expect(_drawn(tester), _words.trimRight());
    expect(find.byType(SoftCaret), findsNothing);
    await tester.pumpWidget(const SizedBox());
    done();
  });

  testWidgets('a pointer down on the transcript shows it all, no fading', (
    tester,
  ) async {
    final (chat, done) = await open(tester);
    stream(chat, _words);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_drawn(tester).length, lessThan(_words.trimRight().length));
    final g = await tester.startGesture(
      tester.getCenter(find.byType(Transcript)),
    );
    await tester.pump();
    expect(_drawn(tester), _words.trimRight());
    expect(_faintest(tester), 1);
    await g.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    done();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, a reply streaming: its newest words fading in, '
        'the caret, 2×, $name', (tester) async {
      final d = await FakeDaemon([]).connect(tester);
      final chat = ChatState('c', '/x')
        ..loaded = true
        ..busy = true
        ..items.add(
          Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Go'),
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: NushiTheme(tokens).toThemeData(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: enlarged(
                const Size(420, 150),
                2,
                ColoredBox(
                  color: tokens.base,
                  child: ListenableBuilder(
                    listenable: chat,
                    builder: (context, _) =>
                        Transcript(chat: chat, daemon: d, onReply: null),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      stream(chat, _words);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      await expectLater(
        find.byType(FittedBox),
        matchesGoldenFile('goldens/paced_reply_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
