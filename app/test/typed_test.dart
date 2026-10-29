import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/typed.dart';

import 'fake_daemon.dart';

Item _call(String id, String title, {String kind = 'execute'}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: kind,
  title: title,
  status: 'in_progress',
);

Widget _app(Widget child, {bool still = false}) => MaterialApp(
  theme: const NushiTheme(Tokens.dark).toThemeData(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: child),
  ),
);

/// The visible part of [title]'s row: its text up to the first character
/// painted clear.
String _shown(WidgetTester tester, String title) {
  final rich = tester
      .widgetList<RichText>(find.byType(RichText))
      .where((r) => r.text.toPlainText().replaceAll('￼', '').contains(title))
      .single;
  final out = StringBuffer();
  var clear = false;
  rich.text.visitChildren((s) {
    if (s is TextSpan && s.text != null && !clear) {
      if (s.style?.color == Colors.transparent) {
        clear = true;
      } else {
        out.write(s.text);
      }
    }
    return !clear;
  });
  return out.toString();
}

void main() {
  setUpAll(loadFonts);

  Future<(ChatState, void Function())> open(
    WidgetTester tester, {
    bool still = false,
    List<Item> items = const [],
  }) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')
      ..loaded = true
      ..busy = true
      ..items.addAll([
        Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Hi'),
        ...items,
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

  testWidgets('a call that comes types its command out, a caret at its '
      'end, then shines; within 260 ms', (tester) async {
    final (chat, done) = await open(tester);
    chat
      ..items.add(_call('a', 'make test-app SHARD=1/2'))
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    final part = _shown(tester, 'SHARD');
    expect(part.length, inExclusiveRange(1, 25));
    expect(r'$ make test-app SHARD=1/2'.startsWith(part), isTrue);
    expect(find.byType(ShaderMask), findsNothing); // no shine while typing

    // 25 characters at 90 a second would take 278 ms: the cap is 260.
    await tester.pump(const Duration(milliseconds: 140));
    expect(_shown(tester, 'SHARD'), isNot(r'$ make test-app SHARD=1/2'));
    await tester.pump(const Duration(milliseconds: 62));
    expect(_shown(tester, 'SHARD'), r'$ make test-app SHARD=1/2');
    await tester.pumpAndSettle();
    expect(find.text(r'$ make test-app SHARD=1/2'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    done();
  });

  testWidgets("a read's verb stays and its path types; a group's running "
      'part types as the next call joins', (tester) async {
    final (chat, done) = await open(tester);
    chat
      ..items.add(_call('a', 'Read', kind: 'read')..paths.add('lib/a.dart'))
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 20));
    expect(_shown(tester, 'a.dart'), startsWith('Read '));
    expect(_shown(tester, 'a.dart'), isNot('Read lib/a.dart'));
    await tester.pumpAndSettle();

    chat
      ..items[1].status = 'completed'
      ..items.add(_call('b', 'Search', kind: 'search'))
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Read 1 file, '), findsOneWidget);
    expect('searching'.startsWith(_shown(tester, 'searching')), isTrue);
    expect(_shown(tester, 'searching'), isNot('searching'));
    await tester.pumpAndSettle();
    expect(find.text('searching'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    done();
  });

  testWidgets('a title that grows types only what was added', (tester) async {
    final (chat, done) = await open(tester);
    chat
      ..items.add(_call('a', 'Terminal', kind: 'other'))
      ..notifyListeners();
    await tester.pumpAndSettle();
    chat
      ..items[1] = _call('a', 'Terminal: make lint', kind: 'other')
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 30));
    expect(_shown(tester, 'Terminal'), startsWith('Terminal'));
    expect(_shown(tester, 'Terminal'), isNot('Terminal: make lint'));
    await tester.pumpAndSettle();
    expect(find.text('Terminal: make lint'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    done();
  });

  // A run's line as shown: what's done, the running part's whole text and
  // its visible part.
  (String, String, String) line(WidgetTester tester) {
    final texts = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(RunLine),
            matching: find.byType(RichText),
          ),
        )
        .toList();
    expect(texts, hasLength(2));
    final now = texts.last.text;
    final shown = StringBuffer();
    var clear = false;
    now.visitChildren((s) {
      if (s is TextSpan && s.text != null) {
        if (s.style?.color == Colors.transparent) clear = true;
        if (!clear) shown.write(s.text);
      }
      return !clear;
    });
    return (
      texts.first.text.toPlainText(),
      now.toPlainText().replaceAll('￼', ''),
      shown.toString(),
    );
  }

  Item read(String id, String path, {bool done = false}) =>
      _call(id, 'Read', kind: 'read')
        ..paths.add(path)
        ..status = done ? 'completed' : 'in_progress';

  testWidgets("a run's next call waits for the one typing to finish (the "
      'hold), and only its words type, the rest changed in place', (
    tester,
  ) async {
    final (chat, done) = await open(
      tester,
      items: [read('a', 'lib/a.dart', done: true), read('b', 'lib/b.dart')],
    );
    expect(line(tester), (
      'Read 1 file, ',
      'reading lib/b.dart',
      'reading lib/b.dart',
    ));

    chat
      ..items[2].status = 'completed'
      ..items.add(read('c', 'lib/c.dart'))
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 30));
    var (d, all, shown) = line(tester);
    expect((d, all), ('Read 2 files, ', 'reading lib/c.dart'));
    // The done part changed in place; the new call's words type.
    expect(shown, isNot(all));
    expect(all, startsWith(shown));

    // The next comes 50 ms in: lib/c.dart stays until typed and held.
    chat
      ..items[3].status = 'completed'
      ..items.add(_call('d', 'make lint'))
      ..notifyListeners();
    // Its typing's clock started on the first frame after the change.
    await tester.pump(const Duration(milliseconds: 4));
    await tester.pump(const Duration(milliseconds: 100)); // 134 ms on
    (d, all, shown) = line(tester);
    expect((d, all), ('Read 2 files, ', 'reading lib/c.dart'));
    expect(shown, isNot(all)); // 18 characters take 200 ms
    await tester.pump(const Duration(milliseconds: 76)); // 210: typed
    expect(line(tester), (
      'Read 2 files, ',
      'reading lib/c.dart',
      'reading lib/c.dart',
    ));
    await tester.pump(const Duration(milliseconds: 30)); // 240: held
    expect(line(tester).$2, 'reading lib/c.dart');
    await tester.pump(const Duration(milliseconds: 20)); // 260: the next
    (d, all, shown) = line(tester);
    expect((d, all), ('Read 3 files, ', 'running make lint'));
    expect(shown, isNot(all));
    await tester.pumpAndSettle();
    expect(line(tester), (
      'Read 3 files, ',
      'running make lint',
      'running make lint',
    ));

    await tester.pumpWidget(const SizedBox());
    done();
  });

  testWidgets('a run whose calls change every 50 ms never types again what '
      'it typed, skips to the latest and ends on it', (tester) async {
    final (chat, done) = await open(
      tester,
      items: [read('a', 'lib/a.dart', done: true), read('b', 'lib/b.dart')],
    );
    final frames = <(String, String, String)>[];
    for (var i = 0; i < 8; i++) {
      chat
        ..items.last.status = 'completed'
        ..items.add(
          i.isEven ? read('c$i', 'src/f$i.go') : _call('c$i', 'go test ./$i'),
        )
        ..notifyListeners();
      for (var f = 0; f < 5; f++) {
        await tester.pump(const Duration(milliseconds: 10));
        frames.add(line(tester));
      }
    }
    await tester.pumpAndSettle();
    expect(line(tester), (
      'Read 6 files, ran 3 commands, ',
      'running go test ./7',
      'running go test ./7',
    ));

    final typed = <String>[];
    for (final (i, (_, all, shown)) in frames.indexed) {
      expect(all.startsWith(shown), isTrue);
      if (i > 0 && frames[i - 1].$2 == all) {
        // The same words: never typed again from the start.
        expect(shown.length, greaterThanOrEqualTo(frames[i - 1].$3.length));
      } else if (i > 0) {
        // Replaced only once typed whole.
        expect(frames[i - 1].$3, frames[i - 1].$2);
      }
      if (typed.lastOrNull != all) typed.add(all);
    }
    // 400 ms of eight calls show at most three of them, each held.
    expect(typed.length, lessThanOrEqualTo(3));

    await tester.pumpWidget(const SizedBox());
    done();
  });

  testWidgets('what the chat opened with, and Reduce Motion, show titles '
      'whole', (tester) async {
    var (_, done) = await open(tester, items: [_call('a', 'make lint')]);
    expect(find.text(r'$ make lint'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    done();

    final ChatState chat;
    (chat, done) = await open(tester, still: true);
    chat
      ..items.add(_call('a', 'make lint'))
      ..notifyListeners();
    await tester.pump();
    expect(find.text(r'$ make lint'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    done();
  });

  test('typing keeps the text whole, the rest painted clear', () {
    const span = TextSpan(
      children: [
        TextSpan(text: 'Read '),
        TextSpan(text: 'lib/a.dart', style: TextStyle(fontSize: 12)),
      ],
    );
    final cut = typedSpan(span, 8, Colors.teal, 1);
    expect(cut.toPlainText().replaceAll('￼', ''), 'Read lib/a.dart');
    final texts = <TextSpan>[];
    cut.visitChildren((s) {
      if (s is TextSpan && s.text != null) texts.add(s);
      return true;
    });
    expect([for (final s in texts) s.text], ['Read ', 'lib', '/a.dart']);
    expect(texts.last.style?.color, Colors.transparent);
    expect(texts.last.style?.fontSize, 12);
  });
}
