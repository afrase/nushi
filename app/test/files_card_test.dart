import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/files_card.dart';
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

Item get _user => Item(
  id: 'u',
  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
  text: 'Write the report and a chart for it.',
);

/// Three files: the report, its chart and a note (the note last).
final List<Item> _three = [
  _user,
  _write('w1', 'docs/report.md'),
  _write('w2', 'docs/img/chart.png'),
  _write('w3', 'notes.md'),
];

/// Each file changed this many minutes ago (by name).
const _minutes = {'report.md': 40, 'chart.png': 15, 'notes.md': 2};

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
        when !s.contains('ago') && !s.startsWith('Show'))
      s,
];

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('the Files card lists the files, newest first; a click opens '
      'the preview and marks its row; a new file joins it', (tester) async {
    final (d, fake) = await _app(tester, _three);
    final panel = find.byType(DetailsPanel);
    expect(
      find.descendant(of: panel, matching: find.text('Files')),
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

  testWidgets('past 8 files: 8 and "Show all", which shows the rest; '
      'collapsed, the count', (tester) async {
    final (d, _) = await _app(tester, [
      _user,
      for (var i = 1; i <= 11; i++) _write('w$i', 'f$i.md'),
    ]);
    expect(_names(tester), [for (var i = 11; i > 3; i--) 'f$i.md']);
    await tester.tap(_inCard(find.text('Show all (11)')));
    await tester.pumpAndSettle();
    expect(_names(tester), [for (var i = 11; i > 0; i--) 'f$i.md']);
    expect(find.text('Show all (11)'), findsNothing);
    final panel = find.byType(DetailsPanel);
    await tester.tap(find.descendant(of: panel, matching: find.text('Files')));
    await tester.pumpAndSettle();
    expect(collapsedCards.value, contains('Files'));
    expect(_card, findsNothing);
    expect(find.descendant(of: panel, matching: find.text('11')), findsOne);
    collapsedCards.value = {};
    d.dispose();
  }, variant: _mac);

  testWidgets('golden: the panel with the Files card, dark', (tester) async {
    final (d, _) = await _app(tester, _three);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    d.chats['c']!.openPreview('docs/report.md');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/files_card_dark.png'),
    );
    d.dispose();
  }, variant: _mac);
}
