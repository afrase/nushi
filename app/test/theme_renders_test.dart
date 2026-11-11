// Each built-in theme (ADR 0086), dark and light, on the README's demo
// data: the main window mid-turn (the transcript with its diffs, a
// subagent's pane, the details panel), the chat alone on what a theme is
// known by (a code block and a permission card after the plan and the
// diffs), Changes with a diff, a narrow window with the terminal, the
// phone's chat, and Settings › Appearance. Renders to look at
// (`make renders TEST=test/theme_renders_test.dart`); here each must draw
// without an error or text past the window's edge.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'screenshots/demo.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// Code in a block, for its colors: keywords, a type, strings, numbers, a
/// comment.
const _code = '''
The cursor, as the store reads it:

```go
// Cursor is where a page of the feed starts.
type Cursor struct {
	Published time.Time `json:"published"`
	ID        int64     `json:"id"`
}

func (c Cursor) Encode() string {
	raw := c.Published.Format(time.RFC3339Nano) + "|" + strconv.FormatInt(c.ID, 10)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}
```
''';

/// The hero's transcript, then a code block and a command waiting to be
/// allowed.
final List<Item> _known = [
  ...heroItems,
  Item(id: 'code', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: _code),
  Item(
    id: 'ask',
    kind: ItemKind.ITEM_KIND_PERMISSION,
    status: 'pending',
    title: 'go test ./internal/feed/... -run TestFeed',
    options: [
      Option(id: 'y', name: 'Allow once'),
      Option(id: 'a', name: 'Always allow'),
      Option(id: 'n', name: 'Reject'),
    ],
  ),
];

/// Whether the hero's transcript ends with [_known]'s code and card.
bool _withCode = false;

Object? _demo(Object input) => switch (input) {
  GetChatRequest(:final chatId) when chatId == heroChat.id => GetChatResponse(
    chat: heroChat,
    items: _withCode ? _known : heroItems,
    status: heroChat.status,
  ),
  GetDiffRequest() => GetDiffResponse(files: demoChanges()),
  GetFolderStatusRequest() => GetFolderStatusResponse(
    git: true,
    branch: demoBranch,
    files: 9,
    added: 142,
    removed: 37,
    defaultBase: 'main',
    ahead: 3,
  ),
  ListTerminalsRequest() => ListTerminalsResponse(
    terminals: [
      Terminal(id: 't1', chatId: heroChat.id, folder: demoTree, shell: 'zsh'),
    ],
  ),
  _ => null,
};

Future<void> _pump(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The Mac app at [size] in [b], on the demo's chats, the hero's open.
Future<Daemon> _window(WidgetTester tester, Size size, Brightness b) async {
  viewport(tester, size, brightness: b);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  clock = () => demoNow;
  final open = <StreamController<Object>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final fake = FakeDaemon(demoChats())
    ..answer = _demo
    ..streams = (input) {
      if (input is! AttachTerminalRequest) return null;
      final s = StreamController<Object>()
        ..add(AttachTerminalResponse(data: utf8.encode(demoTerminal)));
      open.add(s);
      return s.stream;
    };
  final d = await fake.connect(tester)
    ..select(heroChat.id);
  await tester.pumpWidget(NushiApp(daemon: d));
  await _pump(tester);
  return d;
}

void main() {
  setUpAll(loadFonts);

  for (final theme in builtInThemes) {
    for (final b in Brightness.values) {
      final name = '${theme.id}_${b.name}';

      testWidgets('${theme.name}, ${b.name}: the window mid-turn', (
        tester,
      ) async {
        colorTheme.value = theme.id;
        Collapsible.opened.add('e2');
        addTearDown(Collapsible.opened.clear);
        final d = await _window(tester, const Size(1700, 1000), b);
        d.chats[heroChat.id]!.pane.value = 'x';
        await _pump(tester);
        expect(tester.takeException(), isNull);
        expect(
          NushiTheme.of(tester.element(find.byType(Scaffold).first)).t,
          same(theme.of(b)),
        );
        expectTextInside(tester, 1700);
        await render(tester, find.byType(NushiApp), 'theme_${name}_1700');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('${theme.name}, ${b.name}: the chat, code and a card', (
        tester,
      ) async {
        colorTheme.value = theme.id;
        showDetails.value = false;
        _withCode = true;
        addTearDown(() => _withCode = false);
        Collapsible.opened.add('e2');
        addTearDown(Collapsible.opened.clear);
        final d = await _window(tester, const Size(1100, 1500), b);
        expect(tester.takeException(), isNull);
        expectTextInside(tester, 1100);
        await render(tester, find.byType(NushiApp), 'theme_${name}_chat');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('${theme.name}, ${b.name}: Changes, a diff', (tester) async {
        colorTheme.value = theme.id;
        showDetails.value = false;
        final d = await _window(tester, const Size(1400, 900), b);
        d.chats[heroChat.id]!.tab.value = ChatTab.changes;
        await _pump(tester, 10);
        final file = find.textContaining('cursor.go', findRichText: true);
        if (file.evaluate().isNotEmpty) {
          await tester.tap(file.first);
          await _pump(tester, 10);
        }
        expect(tester.takeException(), isNull);
        await render(tester, find.byType(NushiApp), 'theme_${name}_changes');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('${theme.name}, ${b.name}: narrow, the terminal open', (
        tester,
      ) async {
        colorTheme.value = theme.id;
        terminalChats.value = {heroChat.id};
        showDetails.value = false;
        final d = await _window(tester, const Size(720, 900), b);
        expect(tester.takeException(), isNull);
        expectTextInside(tester, 720);
        await render(tester, find.byType(NushiApp), 'theme_${name}_720');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('${theme.name}, ${b.name}: Settings › Appearance', (
        tester,
      ) async {
        colorTheme.value = theme.id;
        final d = await _window(tester, const Size(1200, 900), b);
        d.openSettings(section: SettingsSection.appearance);
        await _pump(tester, 4);
        expect(tester.takeException(), isNull);
        await render(tester, find.byType(NushiApp), 'theme_${name}_settings');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('${theme.name}, ${b.name}: the phone’s chat', (tester) async {
        viewport(tester, const Size(390, 844), ratio: 2, brightness: b);
        clock = () => demoNow;
        final fake = FakeDaemon(demoChats())..answer = _demo;
        final phone = Phone(
          PhonePlatform()
            ..saved = pairedRecord()
            ..theme = theme.id,
          connectTo: (_) => Daemon(transport: fake, remote: true),
        );
        await tester.pumpWidget(PhoneApp(phone));
        await phone.start();
        await _pump(tester);
        await tester.tap(find.text(heroChat.title));
        await _pump(tester, 10);
        expect(tester.takeException(), isNull);
        await render(tester, find.byType(PhoneApp), 'theme_${name}_phone');
        await endPhone(tester, phone);
      });
    }
  }
}
