// ChatFind on its own (ADR 0144): the daemon's counts of the matches
// above what's loaded, the transcript's matches as laid out, and where a
// step lands once a far match's part is in.
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_find.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// A chat whose loaded part is items l1 and l2, with 100 items above, and
/// its find, whose daemon answers [far], and the entries laid out (an
/// item's id to its entry's key), which go with what's found.
(ChatFind, Map<String, String>) _find(List<ChatMatch> far) {
  final chat = ChatState('c', '/x')
    ..older = 100
    ..items.addAll([Item(id: 'l1'), Item(id: 'l2')]);
  final laid = <String, String>{'l1': 'l1', 'l2': 'l2'};
  final f = chat.find
    ..ask = (r, signal) async => FindInChatResponse(matches: far);
  return (f, laid);
}

/// Types [q] and lets the daemon answer.
Future<void> _type(WidgetTester tester, ChatFind f, String q) async {
  f
    ..open()
    ..query = q;
  await tester.pump(ChatFind.pause);
  await tester.pump();
}

void main() {
  testWidgets('a step to the second of a run of calls above lands on that '
      'call’s match, not the run’s first', (tester) async {
    final (f, laid) = _find([
      ChatMatch(itemId: 'c1', count: 1),
      ChatMatch(itemId: 'c2', count: 1),
    ]);
    await _type(tester, f, 'needle');
    f.found(['l1 0'], laid: {...laid});
    expect(f.hits, ['far c1 0', 'far c2 0', 'l1 0']);
    expect(f.current, 'l1 0');
    f.step(-1);
    expect(f.pending, 'far c2 0');
    // Its page comes: c1 and c2 are one run of calls, keyed by c1, its
    // marks c1's then c2's.
    laid.addAll({'c1': 'c1', 'c2': 'c1'});
    f.found(['c1 0', 'c1 1', 'l1 0'], laid: {...laid});
    expect(f.current, 'c1 1');
    f.step(-1);
    expect(f.current, 'c1 0', reason: 'c1’s match, not skipped');
  });

  testWidgets('a step to a subagent’s step lands past the call’s own '
      'matches', (tester) async {
    final (f, laid) = _find([
      ChatMatch(itemId: 'call', count: 2),
      ChatMatch(itemId: 'step', count: 1),
    ]);
    await _type(tester, f, 'needle');
    f
      ..found(['l1 0'], laid: {...laid})
      ..step(-1);
    expect(f.pending, 'far step 0');
    laid.addAll({'call': 'agent call', 'step': 'agent call'});
    f.found(
      ['agent call 0', 'agent call 1', 'agent call 2', 'l1 0'],
      laid: {...laid},
    );
    expect(f.current, 'agent call 2');
  });

  testWidgets('it keeps the entries laid out as they were given, and '
      'forgets them once closed', (tester) async {
    final (f, laid) = _find([ChatMatch(itemId: 'c1', count: 1)]);
    laid['c1'] = 'c1';
    await _type(tester, f, 'needle');
    f.found(['c1 0', 'l1 0'], laid: {...laid});
    expect(f.hits, ['c1 0', 'l1 0'], reason: 'c1 is laid out: not far');
    // What the transcript lays out next isn't read until it's given.
    laid.remove('c1');
    f.reloaded();
    await tester.pump(ChatFind.pause);
    await tester.pump();
    expect(f.hits, ['c1 0', 'l1 0']);
    f.close();
    await _type(tester, f, 'needle');
    expect(f.hits, ['far c1 0'], reason: 'nothing laid out since it closed');
  });

  for (final by in [1, -1]) {
    testWidgets('with nothing loaded to go to, the first step '
        '(${by > 0 ? '⏎' : '⇧⏎'}) shows the nearest match above, which '
        'typing made current', (tester) async {
      final (f, _) = _find([
        ChatMatch(itemId: 'a', count: 1),
        ChatMatch(itemId: 'b', count: 1),
        ChatMatch(itemId: 'c', count: 1),
      ]);
      await _type(tester, f, 'needle');
      f.found(const []);
      expect(f.count, '3 of 3');
      expect(f.current, 'far c 0');
      f.step(by);
      expect(f.current, 'far c 0', reason: 'not moved off unseen');
      expect(f.pending, 'far c 0', reason: 'its part loads');
      expect(f.stepped, isTrue);
      f.step(by);
      expect(f.current, by > 0 ? 'far a 0' : 'far b 0');
    });
  }

  testWidgets('a common query’s millions of matches above are counted and '
      'stepped through without a key for each, frame after frame', (
    tester,
  ) async {
    // The daemon's 5000 items, 2000 matches each. A key made for each hit
    // took about a second a frame; counted by item, it's a few
    // milliseconds for all the frames, far inside the bound.
    final (f, _) = _find([
      for (var i = 0; i < 5000; i++) ChatMatch(itemId: 'i$i', count: 2000),
    ]);
    await _type(tester, f, 'e');
    final took = Stopwatch()..start();
    for (var frame = 0; frame < 10; frame++) {
      // A streaming reply: its entry laid out again, its marks found anew.
      f.found(['l2 0', for (var k = 0; k <= frame % 3; k++) 'l2 ${k + 1}']);
    }
    f.found(['l2 0', 'l2 1', 'l2 2']);
    took.stop();
    expect(took.elapsed, lessThan(const Duration(seconds: 3)));
    expect(f.hits, hasLength(10000003));
    expect(f.count, '10000001 of 10000003');
    f.step(-1);
    expect(f.current, 'far i4999 1999');
    expect(f.pending, 'far i4999 1999');
  });

  testWidgets('letters typed one after another are looked for once, after '
      'a pause; ⏎ looks at once, and so does clearing the field', (
    tester,
  ) async {
    final asked = <String>[];
    final (f, _) = _find(const []);
    f
      ..ask = (r, signal) async {
        asked.add(r.text);
        return FindInChatResponse();
      }
      ..open();
    var looks = 0;
    var was = f.query;
    f.addListener(() {
      if (f.query != was) looks++;
      was = f.query;
    });
    for (final q in ['f', 'fo', 'foo']) {
      f.query = q;
      await tester.pump(ChatFind.pause ~/ 2);
      expect(f.query, '', reason: 'nothing marked, nowhere gone to');
      expect(f.looking, isTrue, reason: 'the chat keeps what it loaded');
    }
    await tester.pump(ChatFind.pause);
    expect(f.query, 'foo');
    expect(looks, 1);
    expect(asked, ['foo']);

    f
      ..query = 'food'
      ..step(1); // ⏎ before the pause is over
    await tester.pump();
    expect(f.query, 'food');
    expect(asked, ['foo', 'food']);

    f
      ..query = 'foods'
      ..query = '';
    expect(f.query, '');
    expect(f.looking, isFalse);
    await tester.pump(ChatFind.pause * 2);
    expect(asked, ['foo', 'food'], reason: 'what was typed and cleared');

    f
      ..query = 'x'
      ..close();
    await tester.pump(ChatFind.pause * 2);
    expect(f.query, isNull);
    expect(asked, ['foo', 'food']);
  });

  testWidgets('a letter typed and taken back within the pause looks for '
      'nothing again: the current match and the count stay', (tester) async {
    final asked = <String>[];
    final (f, _) = _find(const []);
    f.ask = (r, signal) async {
      asked.add(r.text);
      return FindInChatResponse();
    };
    await _type(tester, f, 'e');
    f
      ..found(['l1 0', 'l1 1', 'l2 0', 'l2 1'])
      ..step(1)
      ..step(1);
    final (current, count, ask) = (f.current, f.count, f.asked);
    f.query = 'ex';
    await tester.pump(ChatFind.pause ~/ 2);
    f.query = 'e';
    expect(f.searching, isFalse, reason: 'nothing waits to be asked');
    await tester.pump(ChatFind.pause * 2);
    expect(f.current, current);
    expect(f.count, count);
    expect(f.asked, ask);
    expect(asked, ['e']);
  });
}
