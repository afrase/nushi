import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
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
  toolKind: 'other',
  title: codex ? 'mcp.nushi.show' : 'mcp__nushi__show',
  mcpServer: 'nushi',
  mcpTool: 'show',
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

Item _ask(String title, String input) => Item(
  id: 'ask',
  kind: ItemKind.ITEM_KIND_PERMISSION,
  title: title,
  mcpServer: 'nushi',
  mcpTool: 'show',
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
      // Another tool's input isn't a show's, nor the call's of a daemon
      // below API 140, which says no server and tool: its title is never
      // read for them.
      expect(showPath(_show('a', 'r.html')..mcpTool = 'read'), isNull);
      expect(showPath(_show('a', 'r.html')..clearMcpServer()), isNull);
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
          agentSays('m', 'And now.'),
          _show('b', 'docs/report.html', codex: true),
          agentSays('n', 'And then.'),
          _show('f', 'main.go', status: 'failed', text: 'not a type'),
          agentSays('p', 'And last.'),
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
    }, variant: onMac);

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
    }, variant: onMac);

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
    }, variant: onMac);
  });

  group('the event', () {
    testWidgets('opens the file beside the chat that’s showing', (
      tester,
    ) async {
      final asked = <String>[];
      final (fake, d) = await _app(tester, asked: asked);
      // The keys stay where they were: opening Files takes no focus.
      final box = FocusManager.instance.primaryFocus;
      expect(box, isNotNull);
      await _shows(tester, fake, 'docs/report.md');
      expect(find.byType(FileView), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(box));
      expect(find.textContaining('The release report'), findsOneWidget);
      expect(asked, ['docs/report.md']);
      expect(_chat(d).showAsked.value, isNull);
      // Closed, it stays closed until the agent asks again.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(FileView), findsNothing);
      d.dispose();
    }, variant: onMac);

    testWidgets('a narrow window keeps the transcript; the row opens it', (
      tester,
    ) async {
      final (fake, d) = await _app(
        tester,
        size: const Size(720, 900),
        items: [_show('a', 'docs/report.md', text: 'Shown.')],
      );
      await _shows(tester, fake, 'docs/report.md');
      expect(find.byType(FileView), findsNothing);
      expect(_chat(d).showAsked.value, isNull);
      final box = FocusManager.instance.primaryFocus;
      expect(box, isNotNull);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(FileView), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(box));
      d.dispose();
    }, variant: onMac);

    // A laptop's chat area, 1460 wide, holds the preview beside the Files
    // pane, the details tucking away for it (ADR 0123), but not beside the
    // side chat too (ADR 0068: never over the box).
    testWidgets('with the Files pane open it opens there, the details '
        'tucking away; closed, it opens Files where it fits beside the '
        'transcript, else the row opens it', (tester) async {
      // 1100 for the chat: the Files pane fits beside the transcript from
      // 860, the side chat and Files from 1160 (ADR 0068, 0123).
      final (fake, d) = await _app(
        tester,
        size: const Size(1368, 1000),
        items: [_show('a', 'docs/report.md', text: 'Shown.')],
      );
      showDetails.value = true;
      await tester.pumpAndSettle();
      filesChats.value = {'c'};
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(find.byType(FileView), findsOneWidget);
      expect(find.byType(DetailsPanel), findsNothing);
      expect(showDetails.value, isTrue);
      // Files hidden: its tab stays, the details come back.
      await tester.tap(
        find.descendant(
          of: find.byType(FilesPane),
          matching: find.byTooltip('Close'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FileView), findsNothing);
      expect(find.byType(DetailsPanel), findsOneWidget);
      expect(_chat(d).shownFile, 'docs/report.md');
      // The side chat too, Files closed: no room.
      _chat(d).side.value = ChatState('s', '/Users/me')..title = 'Side';
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(find.byType(FilesPane), findsNothing);
      expect(_chat(d).showAsked.value, isNull);
      // The side chat hidden, it fits: Files opens on it.
      _chat(d).sideHidden.value = true;
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(find.byType(FileView), findsOneWidget);
      expect(filesChats.value, {'c'});
      await closeView(tester, d);
    }, variant: onMac);

    for (final (area, opens) in [(861.0, true), (859.0, false)]) {
      testWidgets('Files closed, a chat of ${area.toInt()}: '
          '${opens ? 'it opens' : 'it stays shut'}', (tester) async {
        final (fake, d) = await _app(
          tester,
          size: Size(area + 16, 1000),
          items: [_show('a', 'docs/report.md', text: 'Shown.')],
        );
        sidebarHidden.value = true;
        await tester.pumpAndSettle();
        await _shows(tester, fake, 'docs/report.md');
        expect(find.byType(FileView), opens ? findsOneWidget : findsNothing);
        expect(_chat(d).showAsked.value, isNull);
        await closeView(tester, d);
      }, variant: onMac);
    }

    testWidgets('Files open over the transcript (a narrow window): it still '
        'opens there', (tester) async {
      final (fake, d) = await _app(
        tester,
        size: const Size(720, 900),
        items: [_show('a', 'docs/report.md', text: 'Shown.')],
      );
      filesChats.value = {'c'};
      await tester.pumpAndSettle();
      final pane = tester.getRect(find.byType(FilesPane));
      await _shows(tester, fake, 'docs/report.md');
      expect(find.byType(FileView), findsOneWidget);
      expect(tester.getRect(find.byType(FilesPane)), pane);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('leaves another chat alone; the latest opens on coming back', (
      tester,
    ) async {
      final (fake, d) = await _app(tester, chat: 'o');
      await _shows(tester, fake, 'docs/first.md');
      await _shows(tester, fake, 'docs/report.md');
      expect(d.selectedId, 'o');
      expect(find.byType(FileView), findsNothing);
      expect(_chat(d).files.shown.value, isNull);
      d.select('c');
      await tester.pumpAndSettle();
      expect(_chat(d).shownFile, 'docs/report.md');
      expect(find.byType(FileView), findsOneWidget);
      // Once: going away and back doesn't open it again.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      d.select('o');
      await tester.pumpAndSettle();
      d.select('c');
      await tester.pumpAndSettle();
      expect(find.byType(FileView), findsNothing);
      d.dispose();
    }, variant: onMac);

    testWidgets('a rewind past the call forgets the ask', (tester) async {
      final (fake, d) = await _app(tester, chat: 'o');
      await _shows(tester, fake, 'docs/report.md');
      _chat(d).load(GetChatResponse(chat: _c, items: [_show('a', 'x.md')]));
      fake.emit(EventsResponse(chatId: 'c', seq: Int64(1), cut: 'a'));
      await tester.pumpAndSettle();
      d.select('c');
      await tester.pumpAndSettle();
      expect(find.byType(FileView), findsNothing);
      d.dispose();
    }, variant: onMac);

    testWidgets('leaves Settings open over the chat', (tester) async {
      final (fake, d) = await _app(tester);
      d.openSettings(section: SettingsSection.general);
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      // Settings stays open over it (ADR 0087).
      expect(d.settingsOpen, isNotNull);
      d.closeSettings();
      await tester.pumpAndSettle();
      expect(find.byType(FileView), findsOneWidget);
      d.dispose();
    }, variant: onMac);

    testWidgets('adds a tab to what’s open, or shows the one it has', (
      tester,
    ) async {
      final (fake, d) = await _app(tester);
      final c = _chat(d)..openInFiles('docs/first.md');
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(c.fileNames, ['docs/first.md', 'docs/report.md']);
      expect(c.shownFile, 'docs/report.md');
      await _shows(tester, fake, '/Users/me/nushi/docs/first.md');
      expect(c.fileNames, ['docs/first.md', 'docs/report.md']);
      expect(c.shownFile, 'docs/first.md');
      d.dispose();
    }, variant: onMac);

    testWidgets('waits on Changes with tabs open, and adds none in a narrow '
        'window', (tester) async {
      final (fake, d) = await _app(tester, size: const Size(720, 900));
      final c = _chat(d)..openInFiles('docs/first.md');
      // Files hidden, its tab kept: a narrow window has no room to open it.
      toggleFiles(c);
      c.tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(c.fileNames, ['docs/first.md']);
      c.tab.value = ChatTab.chat;
      await tester.pumpAndSettle();
      expect(c.filesFit(), isFalse);
      expect(c.showAsked.value, isNull, reason: 'the ask is spent');
      expect(c.fileNames, ['docs/first.md']);
      d.dispose();
    }, variant: onMac);

    testWidgets('leaves Changes alone, until the transcript shows again', (
      tester,
    ) async {
      final (fake, d) = await _app(tester);
      _chat(d).tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(_chat(d).tab.value, ChatTab.changes);
      expect(_chat(d).files.shown.value, isNull);
      _chat(d).tab.value = ChatTab.chat;
      await tester.pumpAndSettle();
      expect(find.byType(FileView), findsOneWidget);
      d.dispose();
    }, variant: onMac);

    testWidgets('its Preview is marked while its file shows, by either name', (
      tester,
    ) async {
      final (_, d) = await _app(
        tester,
        items: [_show('a', '/Users/me/nushi/docs/report.md', text: 'Shown.')],
      );
      final button = find.byType(PreviewButton);
      bool lit() {
        final t = NushiTheme.of(tester.element(button)).t;
        final box = tester.widget<Container>(
          find.descendant(of: button, matching: find.byType(Container)).first,
        );
        return (box.decoration! as BoxDecoration).color == t.accentSoft;
      }

      expect(lit(), isFalse);
      // As the Artifacts widget's row opens it: by the artifact's name.
      _chat(d).openInFiles(chatArtifacts(_chat(d)).recent.single);
      await tester.pumpAndSettle();
      expect(_chat(d).shownFile, 'docs/report.md');
      expect(lit(), isTrue);
      d.dispose();
    }, variant: onMac);

    testWidgets('a chat the app doesn’t know is nothing', (tester) async {
      final (fake, d) = await _app(tester);
      await _shows(tester, fake, 'docs/report.md', chat: 'nope');
      expect(find.byType(FileView), findsNothing);
      d.dispose();
    }, variant: onMac);

    testWidgets('the phone stays where it is; its row offers Preview', (
      tester,
    ) async {
      viewport(tester, const Size(390, 844), ratio: 3);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final fake = _fake(
        items: [
          agentSays('m', 'The report is written.'),
          _show('a', 'docs/report.md'),
          agentSays('n', 'And the page.'),
          _ask('mcp__nushi__show', '{\n  "path": "docs/report.html"\n}'),
        ],
      );
      final phone = await startPhone(tester, fake);
      await tester.tap(find.text('Write the release report'));
      await tester.pumpAndSettle();
      await _shows(tester, fake, 'docs/report.md');
      expect(find.byType(PreviewScreen), findsNothing);
      await render(tester, find.byType(PhoneApp), 'show_phone_light');
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewScreen), findsOneWidget);
      await endPhone(tester, phone);
    }, variant: onPhone);
  });

  for (final (name, width) in [('wide', 1700.0), ('narrow', 720.0)]) {
    for (final brightness in Brightness.values) {
      testWidgets('the window, $name, ${brightness.name}', (tester) async {
        final (fake, d) = await _app(
          tester,
          size: Size(width, 900),
          items: [
            Item(
              id: 'u',
              kind: ItemKind.ITEM_KIND_USER_MESSAGE,
              text: 'Write the release report and show it to me.',
            ),
            agentSays('m', 'The report is written.'),
            _show(
              'a',
              'docs/report.md',
              text: 'The preview pane beside the chat has the file.',
            ),
            agentSays('n', 'Now the numbers, as a page.'),
            _show(
              'f',
              'internal/api/api.go',
              status: 'failed',
              text: 'the preview doesn’t open this type of file',
            ),
            agentSays('o', 'That was the wrong file; the page is this one.'),
            _ask(
              'mcp__nushi__show',
              '{\n  "path": "docs/history/release-timings.html"\n}',
            ),
          ],
        );
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await _shows(tester, fake, 'docs/report.md');
        expect(tester.takeException(), isNull);
        expectTextInside(tester, width);
        // Header buttons at the pane's edge, nothing past the window.
        if (name == 'wide') {
          final close = tester.getTopRight(find.byTooltip('Close')).dx;
          expect(close, lessThan(width));
          expect(close, greaterThan(width - 40));
        }
        await render(
          tester,
          find.byType(NushiApp),
          'show_${name}_${brightness.name}',
        );
        d.dispose();
      }, variant: onMac);
    }
  }
}
