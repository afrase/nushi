import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/history_table.dart';
import 'package:nushi/settings_nav.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

const _words = [
  'Fix the login redirect',
  'Bump the API version',
  'Review the diff view',
  'Why does the build fail on CI?',
  'Rename the flag',
  'Refactor the session store into its own package',
  'Release notes',
  'Speed up the transcript',
];
const _folders = ['nushi', 'site', 'acp-go', 'notes', 'infra', 'web'];
const _agents = ['claude', 'codex', 'ante', 'omp', 'pig'];

/// [n] chats and their copies: every 17th archived, every 23rd one whose
/// agent no longer has it, every 41st a deleted chat's leftover (no chat,
/// no title). Sizes and ages vary; the first is the newest.
(List<Chat>, List<TranscriptCopy>) _many(int n) {
  final now = fixtureNow.millisecondsSinceEpoch;
  final chats = <Chat>[];
  final copies = <TranscriptCopy>[];
  for (var i = 0; i < n; i++) {
    final id = 'c$i';
    final title = '${_words[i % _words.length]} #$i';
    final leftover = i % 41 == 40;
    if (!leftover) {
      chats.add(
        chat(
          id,
          _agents[i % _agents.length],
          title,
          folder: '/Users/me/${_folders[i % _folders.length]}',
          status: ChatStatus(sessionGone: i % 23 == 22),
        )..archived = i % 17 == 16,
      );
    }
    copies.add(
      TranscriptCopy(
        chatId: id,
        title: leftover ? '' : title,
        agent: leftover ? '' : _agents[i % _agents.length],
        bytes: Int64(((i * 7919) % 4000 + 12) << 10),
        lastWrittenMs: Int64(now - i * 37 * 60000),
      ),
    );
  }
  return (chats, copies);
}

/// A daemon with [n] chats' copies, ListTranscripts answered through
/// `answer` when given.
FakeDaemon _fake(
  int n, {
  FutureOr<ListTranscriptsResponse> Function(ListTranscriptsResponse)? answer,
}) {
  final (chats, copies) = _many(n);
  final fake = settingsFake(copies: copies);
  final base = fake.answer!;
  final total = copies.fold(0, (s, c) => s + c.bytes.toInt());
  final list = ListTranscriptsResponse(
    totalBytes: Int64(total),
    copies: copies,
  );
  return FakeDaemon([...settingsChats, ...chats])
    ..settings = fake.settings
    ..answer = (input) => switch (input) {
      ListTranscriptsRequest() => answer?.call(list) ?? list,
      _ => base(input),
    };
}

/// The rows as built, top to bottom.
List<HistoryRowView> _rows(WidgetTester tester) =>
    tester.widgetList<HistoryRowView>(find.byType(HistoryRowView)).toList()
      ..sort(
        (a, b) => tester
            .getTopLeft(find.byWidget(a))
            .dy
            .compareTo(tester.getTopLeft(find.byWidget(b)).dy),
      );

List<String> _titles(WidgetTester tester) => [
  for (final r in _rows(tester).take(4)) r.row.title,
];

Future<void> _clickRow(
  WidgetTester tester,
  String id, {
  LogicalKeyboardKey? holding,
}) async {
  if (holding != null) await tester.sendKeyDownEvent(holding);
  // On its size, away from the title's link.
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey('history-$id')),
      matching: find.textContaining(RegExp(r' (KB|MB)$')),
    ),
  );
  if (holding != null) await tester.sendKeyUpEvent(holding);
  await tester.pumpAndSettle();
}

List<T> _calls<T>(FakeDaemon fake) => fake.calls.whereType<T>().toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

  test('the view: filters, search in titles and folders, sorts', () {
    final (chats, copies) = _many(200);
    final byId = {
      for (final c in chats)
        c.id: ChatState(c.id, c.folder)
          ..agent = c.agent
          ..title = c.title
          ..archived = c.archived
          ..sessionGone = c.status.sessionGone,
    };
    final rows = [for (final c in copies) HistoryRow(c, byId[c.chatId])];
    List<HistoryRow> view(
      HistoryFilter f, {
      String q = '',
      HistorySort s = HistorySort.size,
      bool up = false,
    }) => historyView(rows, filter: f, query: q, sort: s, up: up);
    expect(view(HistoryFilter.all).length, 200);
    expect(view(HistoryFilter.archived).length, 11);
    expect(view(HistoryFilter.archived).every((r) => r.archived), isTrue);
    expect(view(HistoryFilter.gone).length, 8);
    expect(view(HistoryFilter.gone).every((r) => r.gone), isTrue);
    expect(view(HistoryFilter.leftover).map((r) => r.id).toSet(), {
      'c40',
      'c81',
      'c122',
      'c163',
    });
    final acp = view(HistoryFilter.all, q: 'ACP-GO');
    expect(acp.length, 32); // c122 is a leftover
    expect(acp.every((r) => r.folder.endsWith('/acp-go')), isTrue);
    expect(view(HistoryFilter.all, q: 'rename').length, 25);
    expect(view(HistoryFilter.archived, q: 'rename').length, 1); // c84

    final bySize = view(HistoryFilter.all);
    for (var i = 1; i < bySize.length; i++) {
      expect(bySize[i - 1].bytes >= bySize[i].bytes, isTrue);
    }
    final byTitle = view(HistoryFilter.all, s: HistorySort.title, up: true);
    expect(byTitle.take(4).every((r) => r.title.isEmpty), isTrue);
    expect(byTitle[4].title, startsWith('Bump the API version'));
    final newest = view(HistoryFilter.all, s: HistorySort.last);
    expect(newest.first.id, 'c0');
  });

  /// Settings › Chat history in the window over [fake].
  Future<Daemon> open(
    WidgetTester tester,
    FakeDaemon fake, {
    Size size = const Size(1700, 1000),
    Brightness brightness = Brightness.dark,
  }) => pumpSettingsApp(
    tester,
    fake,
    SettingsSection.history,
    size: size,
    brightness: brightness,
  );

  testWidgets('largest first; the headers sort by title, size and last '
      'used, again the other way', (tester) async {
    final d = await open(tester, _fake(200));
    final sizes = [for (final r in _rows(tester)) r.row.bytes];
    expect(sizes, orderedEquals(List<int>.of(sizes)..sort((a, b) => b - a)));
    await tester.tap(find.byKey(const ValueKey('history-sort-title')));
    await tester.pumpAndSettle();
    expect(_titles(tester).take(4), everyElement(''));
    await tester.tap(find.byKey(const ValueKey('history-sort-title')));
    await tester.pumpAndSettle();
    expect(_titles(tester).first, startsWith('Why does the build fail'));
    await tester.tap(find.byKey(const ValueKey('history-sort-last')));
    await tester.pumpAndSettle();
    expect(_rows(tester).first.row.id, 'c0'); // the newest
    d.dispose();
  }, variant: macOS);

  testWidgets('search finds titles and folders; filters with their counts', (
    tester,
  ) async {
    final d = await open(tester, _fake(200));
    await tester.enterText(find.byType(TextField), 'acp-go');
    await tester.pumpAndSettle();
    expect(
      _rows(tester).every((r) => r.row.folder == '/Users/me/acp-go'),
      isTrue,
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Archived  11'));
    await tester.pumpAndSettle();
    expect(_rows(tester).length, 11);
    expect(_rows(tester).every((r) => r.row.archived), isTrue);
    await tester.tap(find.text('Read-only  8'));
    await tester.pumpAndSettle();
    expect(_rows(tester).every((r) => r.row.gone), isTrue);
    expect(find.text('read-only'), findsNWidgets(8));
    await tester.tap(find.text('Deleted chats  4'));
    await tester.pumpAndSettle();
    expect(find.text('A deleted chat'), findsNWidgets(4));
    d.dispose();
  }, variant: macOS);

  testWidgets('no deleted chats: no filter for them', (tester) async {
    final d = await open(tester, _fake(30));
    expect(find.textContaining('Deleted chats'), findsNothing);
    expect(find.text('All  30'), findsOneWidget);
    d.dispose();
  }, variant: macOS);

  testWidgets('a click picks a row, ⌘ adds one, ⇧ a range; the bar clears '
      'them together once asked', (tester) async {
    final fake = _fake(200);
    final d = await open(tester, fake);
    await tester.tap(find.byKey(const ValueKey('history-sort-last')));
    await tester.pumpAndSettle(); // c0, c1, c2… from the top
    await _clickRow(tester, 'c1');
    expect(find.textContaining('1 selected'), findsOneWidget);
    await _clickRow(tester, 'c5', holding: LogicalKeyboardKey.metaLeft);
    expect(find.textContaining('2 selected'), findsOneWidget);
    await _clickRow(tester, 'c8', holding: LogicalKeyboardKey.shiftLeft);
    expect(find.textContaining('4 selected'), findsOneWidget); // c5–c8
    await _clickRow(tester, 'c2', holding: LogicalKeyboardKey.metaLeft);
    expect(find.textContaining('5 selected'), findsOneWidget);
    await tester.tap(find.text('Clear 5 copies…'));
    await tester.pumpAndSettle();
    expect(find.text('Clear 5 copies?'), findsOneWidget);
    await tester.tap(find.widgetWithText(Button, 'Clear').last);
    await tester.pumpAndSettle();
    expect(_calls<ClearTranscriptsRequest>(fake).single.chatIds.toSet(), {
      'c2',
      'c5',
      'c6',
      'c7',
      'c8',
    });
    expect(find.textContaining('selected'), findsNothing);
    d.dispose();
  }, variant: macOS);

  testWidgets('a row’s Clear shows under the pointer and asks nothing; its '
      'title opens the chat', (tester) async {
    final fake = _fake(30);
    final d = await open(tester, fake);
    final top = _rows(tester).first.row;
    expect(find.widgetWithText(Button, 'Clear'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(ValueKey('history-${top.id}'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Clear'));
    await tester.pumpAndSettle();
    expect(_calls<ClearTranscriptsRequest>(fake).single.chatIds, [top.id]);

    final next = _rows(tester).first.row;
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('history-${next.id}')),
        matching: find.text(next.title),
      ),
    );
    await tester.pumpAndSettle();
    expect(d.selectedId, next.id);
    expect(d.settings, isNull);
    d.dispose();
  }, variant: macOS);

  testWidgets("a read-only chat's Clear asks first: the chat goes with its "
      'copy', (tester) async {
    final fake = _fake(30);
    final d = await open(tester, fake);
    await tester.tap(find.text('Read-only  1'));
    await tester.pumpAndSettle();
    final gone = _rows(tester).single.row;
    expect(gone.gone, isTrue);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(ValueKey('history-${gone.id}'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear 1 copy?'), findsOneWidget);
    expect(find.textContaining("1 chat's transcripts"), findsOneWidget);
    expect(_calls<ClearTranscriptsRequest>(fake), isEmpty);
    await tester.tap(find.widgetWithText(Button, 'Clear').last);
    await tester.pumpAndSettle();
    expect(_calls<ClearTranscriptsRequest>(fake).single.chatIds, [gone.id]);
    d.dispose();
  }, variant: macOS);

  testWidgets('5,000 copies: only the rows that show are built', (
    tester,
  ) async {
    final watch = Stopwatch()..start();
    final d = await open(tester, _fake(5000));
    watch.stop();
    final built = find.byType(HistoryRowView).evaluate().length;
    expect(built, lessThan(40));
    expect(find.text('All  5000'), findsOneWidget);
    // To the end and back: still a screenful built.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150000));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryRowView).evaluate().length, lessThan(40));
    // The time it took, for the report; nothing to assert on a CI box.
    // ignore: avoid_print
    print('5,000 copies: opened in ${watch.elapsedMilliseconds} ms');
    d.dispose();
  }, variant: macOS);

  testWidgets('turning copies off asks; Delete copies clears them all', (
    tester,
  ) async {
    final fake = _fake(30);
    final d = await open(tester, fake);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Stop keeping transcripts?'), findsOneWidget);
    await tester.tap(find.text('Delete copies'));
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.keepTranscripts, isFalse);
    expect(_calls<ClearTranscriptsRequest>(fake).single.all, isTrue);
    d.dispose();
  }, variant: macOS);

  testWidgets('Clear all… asks; the age menu sets the setting', (tester) async {
    final fake = _fake(30);
    final d = await open(tester, fake);
    await tester.tap(find.text('90 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('365 days'));
    await tester.pumpAndSettle();
    expect(fake.setSettings.last.transcriptDays, 365);
    await tester.tap(find.text('Clear all…'));
    await tester.pumpAndSettle();
    expect(find.text('Clear every copy?'), findsOneWidget);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(_calls<ClearTranscriptsRequest>(fake).single.all, isTrue);
    d.dispose();
  }, variant: macOS);

  testWidgets('a slow answer shows rows that are coming after 150 ms; none '
      'says so', (tester) async {
    final answer = Completer<ListTranscriptsResponse>();
    final fake = _fake(0, answer: (_) => answer.future);
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.history);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('history-loading')), findsOneWidget);
    answer.complete(ListTranscriptsResponse());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-loading')), findsNothing);
    expect(find.text('No copies yet'), findsOneWidget);
    d.dispose();
  });

  testWidgets('a list that fails says why, not rows coming for good; Try '
      'again', (tester) async {
    var fail = true;
    final fake = _fake(
      0,
      answer: (list) => fail
          ? throw ConnectException(Code.unavailable, 'daemon unavailable')
          : list,
    );
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.history);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('history-loading')), findsNothing);
    expect(find.text('daemon unavailable'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No copies yet'), findsOneWidget);
    d.dispose();
  });

  testWidgets('the columns line up across rows and with the header', (
    tester,
  ) async {
    final d = await open(tester, _fake(200));
    final rows = _rows(tester).take(12).toList();
    Rect cell(HistoryRowView r, String text) => tester.getRect(
      find.descendant(of: find.byWidget(r), matching: find.text(text)),
    );
    final folders = {
      for (final r in rows) cell(r, r.row.folder.split('/').last).left,
    };
    final sizes = {for (final r in rows) cell(r, diskSize(r.row.bytes)).right};
    final ends = {for (final r in rows) tester.getRect(find.byWidget(r)).right};
    expect(folders, hasLength(1));
    expect(sizes, hasLength(1));
    expect(ends, hasLength(1));
    // Folder's heading starts where its cells do; Size's ends where they
    // do, less the room of the sort arrow it carries.
    expect(tester.getRect(find.text('Folder')).left, folders.single);
    expect(
      tester.getRect(find.text('Size')).right + 12,
      moreOrLessEquals(sizes.single, epsilon: 4.5),
    );
    d.dispose();
  }, variant: macOS);

  for (final (size, sizeName) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(900, 700), 'small'),
  ]) {
    for (final (brightness, theme) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      testWidgets('golden: 200 copies scrolled, some picked, $sizeName, '
          '$theme', (tester) async {
        final d = await open(
          tester,
          _fake(200),
          size: size,
          brightness: brightness,
        );
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
        final shown = _rows(tester)
            .where((r) => tester.getTopLeft(find.byWidget(r)).dy > 120)
            .toList();
        await _clickRow(tester, shown[2].row.id);
        await _clickRow(
          tester,
          shown[5].row.id,
          holding: LogicalKeyboardKey.shiftLeft,
        );
        await _clickRow(
          tester,
          shown[8].row.id,
          holding: LogicalKeyboardKey.metaLeft,
        );
        expect(find.textContaining('5 selected'), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/history_picked_${sizeName}_$theme.png'),
        );
        d.dispose();
      }, variant: macOS);

      testWidgets('golden: the search filtering, $sizeName, $theme', (
        tester,
      ) async {
        final d = await open(
          tester,
          _fake(200),
          size: size,
          brightness: brightness,
        );
        await tester.enterText(find.byType(TextField), 'review');
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/history_search_${sizeName}_$theme.png'),
        );
        d.dispose();
      }, variant: macOS);
    }
  }
}
