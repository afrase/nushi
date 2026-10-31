import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/tool_calls.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _doc = '# The release report\n\nCI runs as parallel jobs now.\n';

Item _show(
  String id,
  String path, {
  String status = 'completed',
  bool codex = false,
  String text = '',
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: codex ? 'execute' : 'other',
  title: codex ? 'mcp.nushi.show' : 'mcp__nushi__show',
  status: status,
  text: text,
  input: codex
      ? jsonEncode({
          'server': 'nushi',
          'tool': 'show',
          'arguments': {'path': path},
        })
      : '{\n  "path": ${jsonEncode(path)}\n}',
);

Item _say(String id, String text) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);

Item _ask(String title, String input) => Item(
  id: 'ask',
  kind: ItemKind.ITEM_KIND_PERMISSION,
  title: title,
  input: input,
  status: 'pending',
  options: [
    Option(id: 'yes', name: 'Yes', kind: 'allow_once'),
    Option(id: 'no', name: 'No', kind: 'reject_once'),
  ],
);

final Chat _c = chat('c', 'claude', 'Write the release report');
final Chat _other = chat('o', 'claude', 'Something else');

/// A daemon with chats c and o; the files asked for go in [asked].
FakeDaemon _fake({List<Item>? items, List<String>? asked}) {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  return FakeDaemon([_c, _other])
    ..answer = ((input) => switch (input) {
      GetChatRequest(:final chatId) => GetChatResponse(
        chat: _c,
        items: chatId == 'c' ? items ?? [] : [],
      ),
      _ => null,
    })
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      asked?.add(input.path);
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        WatchChatFileResponse(
          path: '/Users/me/nushi/${input.path}',
          data: utf8.encode(_doc),
          size: Int64(_doc.length),
        ),
      );
      return s.stream;
    };
}

Future<(FakeDaemon, Daemon)> _app(
  WidgetTester tester, {
  List<Item>? items,
  List<String>? asked,
  Size size = const Size(1700, 900),
  String chat = 'c',
}) async {
  viewport(tester, size);
  showDetails.value = false;
  paneWidths.value = {};
  subagentWide.value = false;
  Collapsible.opened.clear();
  final fake = _fake(items: items, asked: asked);
  final d = await fake.connect(tester);
  d.select(chat);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (fake, d);
}

Future<void> _shows(
  WidgetTester tester,
  FakeDaemon fake,
  String path, {
  String chat = 'c',
}) async {
  fake.emit(EventsResponse(chatId: chat, show: path));
  await tester.pumpAndSettle();
}

ChatState _chat(Daemon d) => d.chats['c']!;

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  test('the artifacts are the same list as the daemon’s', () {
    final list = jsonDecode(
      File('../internal/filewatch/testdata/artifacts.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final artifacts = (list['artifacts'] as List<dynamic>).cast<String>();
    expect(artifactKinds.keys.toSet(), artifacts.toSet());
    expect(artifacts.every((e) => isArtifact('a/b.${e.toUpperCase()}')), true);
    final others = (list['others'] as List<dynamic>).cast<String>();
    expect(others.any((e) => isArtifact('a/b.$e')), false);
  });

  group('a show call', () {
    test('its path: Claude’s input and Codex’s', () {
      expect(showPath(_show('a', 'r.html')), 'r.html');
      expect(showPath(_show('a', 'r.html', codex: true)), 'r.html');
      // Input yet to come, cut short, or not what it should be.
      expect(showPath(_show('a', 'r.html')..input = ''), isNull);
      expect(showPath(_show('a', 'r.html')..input = '{"path": "r.h'), isNull);
      expect(showPath(_show('a', 'r.html')..input = '{"path": 3}'), isNull);
      // Another tool's input isn't a show's.
      expect(showPath(_show('a', 'r.html')..title = 'Read'), isNull);
    });

    test('what could make a name read as another is marked', () {
      expect(
        showPath(_show('a', 'safe.md\nreport.exe\u202Elmth.md')),
        'safe.md�report.exe�lmth.md',
      );
    });

    test('Preview only once it ran, and only for an artifact', () {
      expect(previewPath(_show('a', 'docs/r.html')), 'docs/r.html');
      expect(previewPath(_show('a', 'r.pdf', codex: true)), 'r.pdf');
      for (final status in ['pending', 'in_progress', 'failed']) {
        expect(previewPath(_show('a', 'r.html', status: status)), isNull);
      }
      expect(previewPath(_show('a', 'main.go')), isNull);
    });

    test('its file is among the chat’s, once it ran', () {
      expect(chatFiles([_show('a', 'r.html')]), ['r.html']);
      expect(chatFiles([_show('a', 'r.html', status: 'failed')]), isEmpty);
    });

    test('a run’s line says what it did', () {
      expect(groupLabel([_show('a', 'r.html')]), 'Showed 1 file');
      expect(doingOf(_show('a', 'd/r.html', codex: true)), 'Showing r.html');
    });

    testWidgets('its row reads as a preview, not an MCP call', (tester) async {
      final (_, d) = await _app(
        tester,
        items: [
          _show('a', 'docs/report.html'),
          _say('m', 'And now.'),
          _show('b', 'docs/report.html', codex: true),
          _say('n', 'And then.'),
          _show('f', 'main.go', status: 'failed', text: 'not a type'),
          _say('p', 'And last.'),
          _show('r', 'docs/live.html', status: 'in_progress'),
        ],
      );
      expect(find.textContaining('Showed report.html'), findsNWidgets(2));
      expect(find.textContaining('Show main.go'), findsOneWidget);
      expect(find.textContaining('Showing live.html'), findsOneWidget);
      expect(find.textContaining('nushi ·'), findsNothing);
      expect(find.textContaining(r'$ mcp'), findsNothing);
      expect(find.text('Preview'), findsNWidgets(2));
      d.dispose();
    }, variant: _mac);

    testWidgets('its card says which file, and that a page runs', (
      tester,
    ) async {
      final (_, d) = await _app(
        tester,
        items: [_ask('mcp__nushi__show', '{\n  "path": "docs/r.html"\n}')],
      );
      expect(find.text('Show docs/r.html'), findsOneWidget);
      expect(
        find.text('A page runs as it opens in the preview.'),
        findsOneWidget,
      );
      d.dispose();
    }, variant: _mac);

    testWidgets('Codex’s card too; Markdown runs nothing', (tester) async {
      final (_, d) = await _app(
        tester,
        items: [
          _ask(
            'mcp.nushi.show',
            '{"server": "nushi", "arguments": {"path": "r.md"}}',
          ),
        ],
      );
      expect(find.text('Show r.md'), findsOneWidget);
      expect(find.textContaining('A page runs'), findsNothing);
      d.dispose();
    }, variant: _mac);
  });

  group('the event', () {
    testWidgets('opens the file beside the chat that’s showing', (
      tester,
    ) async {
      final asked = <String>[];
      final (fake, d) = await _app(tester, asked: asked);
      await _shows(tester, fake, 'docs/report.md');
      expect(find.byType(PreviewPane), findsOneWidget);
      expect(find.text('The release report'), findsOneWidget);
      expect(asked, ['docs/report.md']);
      expect(_chat(d).showAsked.value, isNull);
      // Closed, it stays closed until the agent asks again.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPane), findsNothing);
      d.dispose();
    }, variant: _mac);

    testWidgets('leaves another chat alone; the latest opens on coming back', (
      tester,
    ) async {
      final (fake, d) = await _app(tester, chat: 'o');
      await _shows(tester, fake, 'docs/first.md');
      await _shows(tester, fake, 'docs/report.md');
      expect(d.selectedId, 'o');
      expect(find.byType(PreviewPane), findsNothing);
      expect(_chat(d).preview.value, isNull);
      d.select('c');
      await tester.pumpAndSettle();
      expect(_chat(d).preview.value, 'docs/report.md');
      expect(find.byType(PreviewPane), findsOneWidget);
      // Once: going away and back doesn't open it again.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      d.select('o');
      await tester.pumpAndSettle();
      d.select('c');
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPane), findsNothing);
      d.dispose();
    }, variant: _mac);

    testWidgets('a rewind past the call forgets the ask', (tester) async {
      final (fake, d) = await _app(tester, chat: 'o');
      await _shows(tester, fake, 'docs/report.md');
      _chat(d).load(GetChatResponse(chat: _c, items: [_show('a', 'x.md')]));
      fake.emit(EventsResponse(chatId: 'c', seq: Int64(1), cut: 'a'));
      await tester.pumpAndSettle();
      d.select('c');
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPane), findsNothing);
      d.dispose();
    }, variant: _mac);

    testWidgets('leaves Settings alone, until the chat shows again', (
      tester,
    ) async {
      final (fake, d) = await _app(tester);
      d.go(const SettingsPlace(SettingsSection.general));
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(d.place, isA<SettingsPlace>());
      expect(find.byType(PreviewPane), findsNothing);
      d.back();
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPane), findsOneWidget);
      d.dispose();
    }, variant: _mac);

    testWidgets('leaves Changes alone, until the transcript shows again', (
      tester,
    ) async {
      final (fake, d) = await _app(tester);
      _chat(d).tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(_chat(d).tab.value, ChatTab.changes);
      expect(_chat(d).preview.value, isNull);
      _chat(d).tab.value = ChatTab.chat;
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPane), findsOneWidget);
      d.dispose();
    }, variant: _mac);

    testWidgets('a chat the app doesn’t know is nothing', (tester) async {
      final (fake, d) = await _app(tester);
      await _shows(tester, fake, 'docs/report.md', chat: 'nope');
      expect(find.byType(PreviewPane), findsNothing);
      d.dispose();
    }, variant: _mac);

    testWidgets('the phone stays where it is; its row offers Preview', (
      tester,
    ) async {
      viewport(tester, const Size(390, 844), ratio: 3);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      Collapsible.opened.clear();
      final fake = _fake(
        items: [
          _say('m', 'The report is written.'),
          _show('a', 'docs/report.md'),
          _say('n', 'And the page.'),
          _ask('mcp__nushi__show', '{\n  "path": "docs/report.html"\n}'),
        ],
      );
      final phone = Phone(
        PhonePlatform()..saved = pairedRecord(),
        connectTo: (_) => Daemon(transport: fake, remote: true),
      );
      await tester.pumpWidget(PhoneApp(phone));
      await phone.start();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('Write the release report'));
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(find.byType(PreviewScreen), findsNothing);
      await expectLater(
        find.byType(PhoneApp),
        matchesGoldenFile('goldens/show_phone_light.png'),
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewScreen), findsOneWidget);
      await endPhone(tester, phone);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  for (final (name, width) in [('wide', 1700.0), ('narrow', 720.0)]) {
    for (final brightness in Brightness.values) {
      testWidgets('golden: $name, ${brightness.name}', (tester) async {
        final (fake, d) = await _app(
          tester,
          size: Size(width, 900),
          items: [
            Item(
              id: 'u',
              kind: ItemKind.ITEM_KIND_USER_MESSAGE,
              text: 'Write the release report and show it to me.',
            ),
            _say('m', 'The report is written.'),
            _show(
              'a',
              'docs/report.md',
              text: 'The preview pane beside the chat has the file.',
            ),
            _say('n', 'Now the numbers, as a page.'),
            _show(
              'f',
              'internal/api/api.go',
              status: 'failed',
              text: 'the preview doesn’t open this type of file',
            ),
            _say('o', 'That was the wrong file; the page is this one.'),
            _ask(
              'mcp__nushi__show',
              '{\n  "path": "docs/history/release-timings.html"\n}',
            ),
          ],
        );
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await _shows(tester, fake, 'docs/report.md');
        // Header buttons at the pane's edge, nothing past the window.
        expect(tester.getTopRight(find.byTooltip('Close')).dx, lessThan(width));
        expect(
          tester.getTopRight(find.byTooltip('Close')).dx,
          greaterThan(width - 40),
        );
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/show_${name}_${brightness.name}.png'),
        );
        d.dispose();
      }, variant: _mac);
    }
  }
}
