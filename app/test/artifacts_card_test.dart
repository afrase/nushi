import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/artifacts_card.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';

Item _write(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'edit',
  title: 'Write',
  status: 'completed',
  paths: [path],
);

Item _say(String id, String text) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: text);

Item get _user => _say('u', 'Write the report and a chart for it.');

/// Two turns: six files in the first, two in the last.
final List<Item> _turns = [
  _say('u1', 'Sketch the whole design.'),
  for (final f in [
    'docs/brief.md',
    'docs/flows.md',
    'mock/home.html',
    'mock/list.html',
    'docs/img/map.svg',
    'docs/notes.md',
  ])
    _write('w-$f', f),
  _say('u2', 'Now the report and its chart.'),
  _write('w-r', 'docs/report.md'),
  _write('w-c', 'docs/img/chart.png'),
];

/// Three files: the report, its chart and a note (the note last).
final List<Item> _three = [
  _user,
  _write('w1', 'docs/report.md'),
  _write('w2', 'docs/img/chart.png'),
  _write('w3', 'notes.md'),
];

/// Each file changed this many minutes ago (by name).
const _minutes = {
  'report.md': 40,
  'chart.png': 15,
  'notes.md': 2,
  'brief.md': 190,
  'flows.md': 180,
  'home.html': 170,
  'list.html': 160,
  'map.svg': 150,
};

/// The app on a chat with [items], the details panel shown, and the fake
/// daemon behind it.
Future<(Daemon, FakeDaemon)> _app(WidgetTester tester, List<Item> items) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1700, 900);
  addTearDown(tester.view.reset);
  showDetails.value = true;
  paneWidths.value = {};
  subagentWide.value = false;
  collapsedCards.value = {};
  cardOrder.value = [];
  pinnedFiles.value = {};
  final was = fileChanged;
  fileChanged = (p) => switch (_minutes[p.split('/').last]) {
    final m? => DateTime.now().subtract(Duration(minutes: m, seconds: 5)),
    null => null,
  };
  addTearDown(() => fileChanged = was);
  final c = chat('c', 'claude', 'Write the report');
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final fake = FakeDaemon([c])
    ..answer = ((input) =>
        input is GetChatRequest ? GetChatResponse(chat: c, items: items) : null)
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      final text = '# ${input.path}\n';
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        WatchChatFileResponse(
          path: '/Users/me/nushi/${input.path}',
          data: utf8.encode(text),
          size: Int64(text.length),
        ),
      );
      return s.stream;
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

Finder get _card => find.byType(FileRows);

Finder _inCard(Finder f) => find.descendant(of: _card, matching: f);

/// The names the card lists, top to bottom.
List<String> _names(WidgetTester tester) => [
  for (final e in _inCard(find.byType(Text)).evaluate())
    if ((e.widget as Text).data case final s?
        when !s.contains('ago') && !s.startsWith('Older'))
      s,
];

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('the Artifacts card lists the files, newest first; a click opens '
      'the preview and marks its row; a new file joins it', (tester) async {
    final (d, fake) = await _app(tester, _three);
    final panel = find.byType(DetailsPanel);
    expect(
      find.descendant(of: panel, matching: find.text('Artifacts')),
      findsOneWidget,
    );
    expect(_names(tester), ['notes.md', 'chart.png', 'report.md']);
    expect(_inCard(find.text('docs/img · 15m ago')), findsOneWidget);
    expect(_inCard(find.text('2m ago')), findsOneWidget); // at the top
    await tester.tap(_inCard(find.text('chart.png')));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.preview.value, 'docs/img/chart.png');
    expect(
      find.descendant(
        of: find.byType(PreviewPane),
        matching: find.text('chart.png'),
      ),
      findsOneWidget,
    );
    // Only the open file's row is marked.
    bool marked(String name) => tester
        .widget<Tap>(
          find
              .ancestor(
                of: _inCard(find.text(name)),
                matching: find.byType(Tap),
              )
              .first, // its row's, not the card's
        )
        .selected;
    expect(marked('chart.png'), isTrue);
    expect(marked('report.md'), isFalse);
    // The agent writes another: it comes first.
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1),
        item: ItemEvent(item: _write('w4', 'plan.md'), index: 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(_names(tester), ['plan.md', 'notes.md', 'chart.png', 'report.md']);
    d.dispose();
  }, variant: _mac);

  testWidgets('no files, no card', (tester) async {
    final (d, _) = await _app(tester, [_user]);
    expect(find.byType(DetailsPanel), findsOneWidget);
    expect(_card, findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets("the last turn's files are recent, the others fold under "
      '"Older (n)", newest first; the header counts the recent', (
    tester,
  ) async {
    final (d, _) = await _app(tester, _turns);
    expect(_names(tester), ['chart.png', 'report.md']);
    expect(_inCard(find.text('Older (6)')), findsOneWidget);
    final header = find.text('Artifacts 2', findRichText: true);
    expect(header, findsOneWidget);
    expect(
      find.byTooltip(
        'Artifacts: the files this chat wrote, to preview '
        '(2 pinned or recent, 8 in all)',
      ),
      findsOneWidget,
    );
    await tester.tap(_inCard(find.text('Older (6)')));
    await tester.pumpAndSettle();
    expect(_names(tester), [
      'chart.png',
      'report.md',
      'notes.md',
      'map.svg',
      'list.html',
      'home.html',
      'flows.md',
      'brief.md',
    ]);
    // The header's menu: the recent, then Older opening the rest.
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(find.text('Older (6)'), findsNWidgets(2)); // the card's and it
    expect(
      find.textContaining('notes.md', findRichText: true),
      findsOneWidget, // the card's only
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SubmenuButton),
        matching: find.text('Older (6)'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('notes.md', findRichText: true),
      findsNWidgets(2),
    );
    d.dispose();
  }, variant: _mac);

  testWidgets('pinned first, in the order pinned, with a pin on hover; kept '
      'in app.json', (tester) async {
    Directory(dataDir).createSync(recursive: true); // the tests' own
    final (d, _) = await _app(tester, _turns);
    await tester.tap(_inCard(find.text('Older (6)')));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    // No pin shows until the pointer is over a row.
    expect(_inCard(find.byIcon(Icons.push_pin_outlined)), findsNothing);
    for (final name in ['home.html', 'brief.md']) {
      await mouse.moveTo(tester.getCenter(_inCard(find.text(name))));
      await tester.pumpAndSettle();
      await tester.tap(_inCard(find.byIcon(Icons.push_pin_outlined)));
      await tester.pumpAndSettle();
    }
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(_names(tester).take(4), [
      'home.html',
      'brief.md',
      'chart.png',
      'report.md',
    ]);
    expect(_inCard(find.byIcon(Icons.push_pin)), findsNWidgets(2));
    expect(_inCard(find.text('Older (4)')), findsOneWidget);
    expect(find.text('Artifacts 4', findRichText: true), findsOneWidget);
    expect(pinnedFiles.value, {
      'c': ['mock/home.html', 'docs/brief.md'],
    });
    expect(savedPins(readSaved()), pinnedFiles.value);
    // Unpinned, it goes back among the older.
    await tester.tap(_inCard(find.byIcon(Icons.push_pin)).first);
    await tester.pumpAndSettle();
    expect(_names(tester).first, 'brief.md');
    expect(_inCard(find.text('Older (5)')), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets('pins survive a restart', (tester) async {
    Directory(dataDir).createSync(recursive: true);
    var (d, _) = await _app(tester, _turns);
    togglePin(d.chats['c']!, 'docs/flows.md');
    await tester.pumpAndSettle();
    d.dispose();
    await tester.pumpWidget(const SizedBox());
    // As a new launch reads app.json.
    final saved = readSaved();
    pinnedFiles.value = {};
    (d, _) = await _app(tester, _turns);
    pinnedFiles.value = savedPins(saved);
    await tester.pumpAndSettle();
    expect(_names(tester), ['flows.md', 'chart.png', 'report.md']);
    d.dispose();
  }, variant: _mac);

  testWidgets('a file opened stays recent for an hour', (tester) async {
    final start = DateTime(2026, 10, 28, 9);
    clock = () => start;
    addTearDown(() => clock = DateTime.now);
    final (d, _) = await _app(tester, _turns);
    final c = d.chats['c']!;
    await tester.tap(_inCard(find.text('Older (6)')));
    await tester.pumpAndSettle();
    await tester.tap(_inCard(find.text('flows.md')));
    await tester.pumpAndSettle();
    await tester.tap(_inCard(find.text('Older (5)'))); // fold it again
    await tester.pumpAndSettle();
    expect(_names(tester), ['chart.png', 'report.md', 'flows.md']);
    // Closed, it stays recent for the hour.
    c.preview.value = null;
    clock = () => start.add(const Duration(minutes: 59));
    await tester.pump(const Duration(minutes: 1)); // the card's tick
    expect(_names(tester), ['chart.png', 'report.md', 'flows.md']);
    clock = () => start.add(const Duration(minutes: 61));
    await tester.pump(const Duration(minutes: 1));
    expect(_names(tester), ['chart.png', 'report.md']);
    expect(_inCard(find.text('Older (6)')), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets('nothing pinned or recent: the 3 newest', (tester) async {
    final (d, _) = await _app(tester, [
      ..._turns.take(7), // the first turn
      _say('u2', 'Thanks, that will do for now.'),
      Item(id: 'a', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Glad to.'),
    ]);
    expect(_names(tester), ['notes.md', 'map.svg', 'list.html']);
    expect(_inCard(find.text('Older (3)')), findsOneWidget);
    expect(find.text('Artifacts 3', findRichText: true), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets('golden: the card with a pin, two recent and Older (5), dark', (
    tester,
  ) async {
    final (d, _) = await _app(tester, _turns);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    togglePin(d.chats['c']!, 'mock/home.html');
    d.chats['c']!.openPreview('docs/report.md');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/artifacts_card_dark.png'),
    );
    d.dispose();
  }, variant: _mac);
}
