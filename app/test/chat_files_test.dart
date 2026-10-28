import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/open_file.dart';
import 'package:nushi/phone/files_screen.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/tool_calls.dart';

import 'fake_daemon.dart';

Item _call(
  String id,
  String path, {
  String kind = 'edit',
  String status = 'completed',
  String parent = '',
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: kind,
  title: kind == 'edit' ? 'Write' : 'Delete',
  status: status,
  paths: [path],
  parent: parent,
);

final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Write the report, a chart for it, and have a subagent take notes.',
  ),
  _call('w1', 'docs/report.md')
    ..diffs.add(FileChange(path: 'docs/report.md', newText: '# Report\n')),
  Item(
    id: 's',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'think',
    title: 'Take notes',
    status: 'completed',
    agent: 'general-purpose',
  ),
  _call('sw', 'notes/sub.md', parent: 's'),
  _call('i', 'docs/img/chart.png'),
  _call('f', 'bad.md', status: 'failed'),
  _call('r', 'README.md', kind: 'read'),
  _call('t', 'tmp.md'),
  _call('d', 'tmp.md', kind: 'delete'),
  _call('g', 'internal/api/api.go'),
  _call('w2', 'docs/report.md'),
  Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Done.'),
];

final Chat _chat = chat('c', 'claude', 'Write the report');

FakeDaemon _fake() {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  return FakeDaemon([_chat])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: _chat, items: _items),
      ListFilesRequest() => ListFilesResponse(
        paths: ['go.mod', 'docs/plan.md', 'docs/report.md', 'logo.png'],
      ),
      _ => null,
    })
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
}

/// Each file changed this many minutes ago (by name).
const _minutes = {'report.md': 2, 'chart.png': 15, 'sub.md': 125};

Future<Daemon> _app(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1700, 900);
  addTearDown(tester.view.reset);
  showDetails.value = false;
  paneWidths.value = {};
  subagentWide.value = false;
  Collapsible.opened.clear();
  final was = fileChanged;
  fileChanged = (p) => switch (_minutes[p.split('/').last]) {
    final m? => DateTime.now().subtract(Duration(minutes: m, seconds: 5)),
    null => null,
  };
  addTearDown(() => fileChanged = was);
  final d = await _fake().connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Finder get _pane => find.byType(PreviewPane);

Finder _inPane(Finder f) => find.descendant(of: _pane, matching: f);

void main() {
  setUpAll(loadFonts);

  test('the files a chat wrote: previewable, once, newest first', () {
    // Not the Go file, the one read, the failed write or the deleted one;
    // the subagent's note; the report once, where it changed last.
    expect(chatFiles(_items), [
      'docs/report.md',
      'docs/img/chart.png',
      'notes/sub.md',
    ]);
    expect(chatFiles(const []), isEmpty);
    expect(folderOf('docs/img/chart.png'), 'docs/img');
    expect(folderOf('report.md'), '');
  });

  testWidgets('Files in the header opens a file in the pane, from Changes '
      'too', (tester) async {
    final d = await _app(tester);
    expect(find.text('Files 3', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files 3', findRichText: true));
    await tester.pumpAndSettle();
    // Each row: the name, its folder and when it changed.
    for (final (name, detail) in [
      ('report.md', 'docs · 2m ago'),
      ('chart.png', 'docs/img · 15m ago'),
      ('sub.md', 'notes · 2h ago'),
    ]) {
      expect(
        find.textContaining(RegExp('^$name   $detail\$'), findRichText: true),
        findsOneWidget,
      );
    }
    final rows = [
      for (final n in ['report.md', 'chart.png', 'sub.md'])
        tester.getTopLeft(find.textContaining(n, findRichText: true)).dy,
    ];
    expect(rows, orderedEquals([...rows]..sort()));
    await tester.tap(find.textContaining('sub.md', findRichText: true));
    await tester.pumpAndSettle();
    expect(_pane, findsOneWidget); // back in the chat, beside it
    expect(_inPane(find.text('sub.md')), findsOneWidget);
    expect(d.chats['c']!.preview.value, 'notes/sub.md');
    d.dispose();
  }, variant: _mac);

  testWidgets('the pane’s name switches files, the open one checked', (
    tester,
  ) async {
    final d = await _app(tester);
    d.chats['c']!.openPreview('docs/report.md');
    await tester.pumpAndSettle();
    await tester.tap(_inPane(find.text('report.md')));
    await tester.pumpAndSettle();
    final checked = find.byIcon(Icons.check);
    expect(checked, findsOneWidget);
    expect(
      tester.getCenter(checked).dy,
      closeTo(
        tester
            .getCenter(find.textContaining('docs · 2m', findRichText: true))
            .dy,
        4,
      ),
    );
    await tester.tap(find.textContaining('chart.png', findRichText: true));
    await tester.pumpAndSettle();
    expect(_inPane(find.text('chart.png')), findsOneWidget);
    expect(d.chats['c']!.preview.value, 'docs/img/chart.png');
    d.dispose();
  }, variant: _mac);

  testWidgets('⌘P: Open file matches what’s typed and opens it', (
    tester,
  ) async {
    final d = await _app(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    final box = find.byType(OpenFileBox);
    expect(box, findsOneWidget);
    Finder inBox(Finder f) => find.descendant(of: box, matching: f);
    // Empty: the chat's files first, then the folder's that preview.
    expect(
      inBox(find.textContaining('go.mod', findRichText: true)),
      findsNothing,
    );
    expect(
      tester
          .getTopLeft(
            inBox(find.textContaining('report.md', findRichText: true)),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(
              inBox(find.textContaining('plan.md', findRichText: true)),
            )
            .dy,
      ),
    );
    await tester.enterText(inBox(find.byType(TextField)), 'pla');
    await tester.pumpAndSettle();
    expect(
      inBox(find.textContaining('plan.md', findRichText: true)),
      findsOneWidget,
    );
    expect(
      inBox(find.textContaining('report.md', findRichText: true)),
      findsNothing,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(box, findsNothing);
    expect(_inPane(find.text('plan.md')), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets('the phone: Files in the bar, then a file full screen', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(390, 844) * 3;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final platform = PhonePlatform()
      ..saved = {
        'key': Uint8List(32)..[0] = 7,
        'name': 'iPhone',
        'relay': 'wss://nushi.aaronfrase.com',
        'daemon': 'ArJKFXeGeF5z4WCydMz-dOXinj4sE99eMxmb-oJ3qLE',
        'daemonKey': Uint8List(32)..[0] = 9,
      };
    final fake = _fake();
    final phone = Phone(
      platform,
      connectTo: (_) => Daemon(transport: fake, remote: true),
    );
    await tester.pumpWidget(PhoneApp(phone));
    await phone.start();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('Write the report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files 3'));
    await tester.pumpAndSettle();
    final screen = find.byType(FilesScreen);
    expect(screen, findsOneWidget);
    final names = find.descendant(of: screen, matching: find.byType(Text));
    expect(
      [for (final e in names.evaluate()) (e.widget as Text).data],
      [
        'Files',
        'report.md',
        'docs',
        'chart.png',
        'docs/img',
        'sub.md',
        'notes',
      ],
    );
    await tester.tap(find.text('chart.png'));
    await tester.pumpAndSettle();
    expect(find.byType(PreviewScreen), findsOneWidget);
    await phone.close();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('golden: the Files menu over a chat, dark', (tester) async {
    final d = await _app(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files 3', findRichText: true));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/chat_files_dark.png'),
    );
    d.dispose();
  }, variant: _mac);
}
