import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/artifacts_widget.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Item _write(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'edit',
  title: 'Write',
  status: 'completed',
  paths: [path],
);

/// A show call that ran, naming [path] as the agent did.
Item _show(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'other',
  title: 'mcp__nushi__show',
  status: 'completed',
  input: jsonEncode({'path': path}),
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
  viewport(tester, const Size(1700, 900));
  showDetails.value = true;
  paneWidths.value = {};
  collapsedWidgets.value = {};
  widgetOrder.value = [];
  pinnedFiles.value = {};
  final was = fileChanged;
  fileChanged = (p) => switch (_minutes[p.split('/').last]) {
    final m? => clock().subtract(Duration(minutes: m, seconds: 5)),
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

Finder get _rows => find.byType(FileRows);

Finder _inRows(Finder f) => find.descendant(of: _rows, matching: f);

/// The names the widget lists, top to bottom.
List<String> _names(WidgetTester tester) => [
  for (final e in _inRows(find.byType(Text)).evaluate())
    if ((e.widget as Text).data case final s? when s.contains('.')) s,
];

/// The tooltip of [name]'s row.
String _tip(WidgetTester tester, String name) => tester
    .widget<Tap>(
      find
          .ancestor(of: _inRows(find.text(name)), matching: find.byType(Tap))
          .first,
    )
    .tooltip;

Future<void> _more(WidgetTester tester) async {
  await tester.tap(_inRows(find.text('Show more')));
  await tester.pumpAndSettle();
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('the Artifacts widget lists files, newest first, each its kind '
      'on the right; a click opens the preview and marks its row; a new '
      'file joins it', (tester) async {
    final (d, fake) = await _app(tester, _three);
    final panel = find.byType(DetailsPanel);
    expect(
      find.descendant(of: panel, matching: find.text('Artifacts')),
      findsOneWidget,
    );
    expect(_names(tester), ['notes.md', 'chart.png', 'report.md']);
    expect(_inRows(find.text('Markdown')), findsNWidgets(2));
    expect(_inRows(find.text('Image')), findsOneWidget);
    // Its folder and when it changed, in its tooltip.
    expect(_tip(tester, 'chart.png'), 'docs/img/chart.png · 15m ago');
    expect(_inRows(find.text('Show more')), findsNothing);
    await tester.tap(_inRows(find.text('chart.png')));
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
                of: _inRows(find.text(name)),
                matching: find.byType(Tap),
              )
              .first, // its row's, not the widget's
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

  testWidgets('a file written, then shown by its absolute path, is one '
      'row, marked when the show opens it, its old pin kept', (tester) async {
    // The daemon names the written file relative to the chat's folder; the
    // show call's path is the agent's own (a page as the owner saw it, but
    // Markdown: a test has no web view).
    const page = '/Users/me/nushi/mock/page.md';
    pinnedFiles.value = {};
    final (d, fake) = await _app(tester, [
      ..._three,
      _write('w4', 'mock/page.md'),
      _show('s', page),
      _show('s2', './notes.md'),
    ]);
    expect(_names(tester), ['notes.md', 'page.md', 'chart.png', 'report.md']);
    fake.emit(EventsResponse(chatId: 'c', show: page));
    await tester.pumpAndSettle();
    final c = d.chats['c']!;
    expect(c.preview.value, page);
    expect(
      tester
          .widget<Tap>(
            find
                .ancestor(
                  of: _inRows(find.text('page.md')),
                  matching: find.byType(Tap),
                )
                .first,
          )
          .selected,
      isTrue,
    );
    expect(c.opened.value.keys, ['mock/page.md']);
    // A pin made by the absolute name, when the file was listed twice.
    pinnedFiles.value = {
      'c': [page],
    };
    await tester.pumpAndSettle();
    expect(chatArtifacts(c).pinned, ['mock/page.md']);
    expect(pinned(c, 'mock/page.md'), isTrue);
    togglePin(c, 'mock/page.md');
    expect(pinnedFiles.value, isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets('no files, no widget', (tester) async {
    final (d, _) = await _app(tester, [_user]);
    expect(find.byType(DetailsPanel), findsOneWidget);
    expect(_rows, findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets("five, the last turn's first, then Show more for the rest, "
      'newest first; Show less folds them again', (tester) async {
    final (d, _) = await _app(tester, _turns);
    expect(_names(tester), [
      'chart.png',
      'report.md',
      'notes.md',
      'map.svg',
      'list.html',
    ]);
    await _more(tester);
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
    await tester.tap(_inRows(find.text('Show less')));
    await tester.pumpAndSettle();
    expect(_names(tester), hasLength(5));
    d.dispose();
  }, variant: _mac);

  testWidgets("pinned first, in the order pinned, the pin in the icon's "
      'place on hover; kept in app.json', (tester) async {
    Directory(dataDir).createSync(recursive: true); // the tests' own
    final (d, _) = await _app(tester, _turns);
    await _more(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    // No pin shows until the pointer is over a row.
    expect(_inRows(find.byIcon(Icons.push_pin_outlined)), findsNothing);
    for (final name in ['home.html', 'brief.md']) {
      await mouse.moveTo(tester.getCenter(_inRows(find.text(name))));
      await tester.pumpAndSettle();
      await tester.tap(_inRows(find.byIcon(Icons.push_pin_outlined)));
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
    expect(_inRows(find.byIcon(Icons.push_pin)), findsNWidgets(2));
    expect(pinnedFiles.value, {
      'c': ['mock/home.html', 'docs/brief.md'],
    });
    expect(savedPins(readSaved()), pinnedFiles.value);
    // Unpinned, it goes back among the older.
    await tester.tap(_inRows(find.byIcon(Icons.push_pin)).first);
    await tester.pumpAndSettle();
    expect(_names(tester).first, 'brief.md');
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
    expect(_names(tester).take(3), ['flows.md', 'chart.png', 'report.md']);
    d.dispose();
  }, variant: _mac);

  testWidgets('a file opened stays among the first for an hour', (
    tester,
  ) async {
    final start = DateTime(2026, 10, 28, 9);
    clock = () => start;
    final (d, _) = await _app(tester, _turns);
    final c = d.chats['c']!;
    await _more(tester);
    await tester.tap(_inRows(find.text('flows.md')));
    await tester.pumpAndSettle();
    await tester.tap(_inRows(find.text('Show less')));
    await tester.pumpAndSettle();
    expect(_names(tester).take(3), ['chart.png', 'report.md', 'flows.md']);
    // Closed, it stays recent for the hour.
    c.preview.value = null;
    clock = () => start.add(const Duration(minutes: 59));
    await tester.pump(const Duration(minutes: 1)); // the widget's tick
    expect(_names(tester).take(3), ['chart.png', 'report.md', 'flows.md']);
    clock = () => start.add(const Duration(minutes: 61));
    await tester.pump(const Duration(minutes: 1));
    expect(_names(tester), isNot(contains('flows.md')));
    d.dispose();
  }, variant: _mac);

  for (final (name, mode) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('golden: the widget with a pin and Show more, $name', (
      tester,
    ) async {
      final (d, _) = await _app(tester, _turns);
      tester.platformDispatcher.platformBrightnessTestValue = mode;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      togglePin(d.chats['c']!, 'mock/home.html');
      d.chats['c']!.openPreview('docs/report.md');
      await tester.pumpAndSettle();
      expect(_inRows(find.text('Show more')), findsOneWidget);
      // The widget on its own is its golden; the window a render.
      await expectLater(
        find.ancestor(of: _rows, matching: find.byType(PanelWidget)),
        matchesGoldenFile('goldens/artifacts_widget_$name.png'),
      );
      await render(tester, find.byType(NushiApp), 'artifacts_widget_$name');
      d.dispose();
    }, variant: _mac);
  }
}
