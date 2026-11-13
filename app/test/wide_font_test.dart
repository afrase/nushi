// A wider App font than the bundled one (ADR 0114): JetBrains Mono, the
// widest family a test can load, set as the app's font over the README's
// demo data. The main window, a chat with code and a card, Changes with a
// diff and every section of Settings, each wide and narrow: nothing
// overflows its box (Flutter's striped edge), and no text runs past the
// window. Renders to look at (`make renders TEST=test/wide_font_test.dart`).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'screenshots/demo.dart';
import 'settings_harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const _code = '''
The cursor, as the store reads it:

```go
// Cursor is where a page of the feed starts.
type Cursor struct {
	Published time.Time `json:"published"`
	ID        int64     `json:"id"`
}
```
''';

/// The hero's transcript, then a code block and a command waiting to be
/// allowed.
final List<Item> _withCode = [
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

Object? _demo(Object input) => switch (input) {
  GetChatRequest(:final chatId) when chatId == heroChat.id => GetChatResponse(
    chat: heroChat,
    items: _withCode,
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
  _ => null,
};

/// Every layout overflow reported while [body] runs, not only the first
/// (`takeException`'s): how far, the widget that overflowed, and [where]
/// the test was.
Future<List<String>> _overflows(
  Future<void> Function() body, {
  String Function()? where,
}) async {
  final found = <String>[];
  final before = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (!text.contains('overflowed')) return before?.call(details);
    final at = RegExp(r'debugCreator: ([^\n]*(\n[^\n]*)?)')
        .firstMatch(details.informationCollector?.call().join('\n') ?? '')
        ?.group(1)
        ?.replaceAll('\n', ' ');
    found.add('${where?.call() ?? ''} ${text.split('\n').first} $at');
  };
  try {
    await body();
  } finally {
    FlutterError.onError = before;
  }
  return found;
}

/// What's known to overflow in a wide font and isn't fixed: at 720, a
/// server's row in Settings › MCP servers, whose name, transport, state
/// and switch leave its address no room in the bundled font, and take
/// ten points more than there is in this one.
const _known = ['MCP servers, 720:'];

Future<void> _pump(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The Mac app at [size] on the demo's chats, the hero's open, its text in
/// [font]: JetBrains Mono unless given, null for the bundled one.
Future<Daemon> _window(
  WidgetTester tester,
  Size size, {
  String? font = NushiTheme.codeFont,
}) async {
  viewport(tester, size, brightness: Brightness.dark);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>['Menlo', 'SF Mono'],
      );
  clock = () => demoNow;
  appFont.value = font;
  final d = await (FakeDaemon(demoChats())..answer = _demo).connect(tester)
    ..select(heroChat.id);
  await tester.pumpWidget(NushiApp(daemon: d));
  await _pump(tester);
  return d;
}

void main() {
  setUpAll(loadFonts);

  for (final (size, w) in [
    (const Size(1700, 1000), 1700),
    (const Size(720, 900), 720),
  ]) {
    testWidgets('the main window in a wide app font, $w', (tester) async {
      late Daemon d;
      final over = await _overflows(() async {
        d = await _window(tester, size);
      });
      expect(
        NushiTheme.of(tester.element(find.byType(Scaffold).first)).uiFamily,
        NushiTheme.codeFont,
      );
      await render(tester, find.byType(NushiApp), 'wide_font_window_$w');
      expect(over, isEmpty);
      expectTextInside(tester, size.width);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('a chat in a wide app font, $w', (tester) async {
      showDetails.value = false;
      sidebarHidden.value = w == 720;
      Collapsible.opened.add('e2');
      addTearDown(Collapsible.opened.clear);
      late Daemon d;
      final over = await _overflows(() async {
        d = await _window(tester, Size(size.width, 1500));
      });
      await render(tester, find.byType(NushiApp), 'wide_font_chat_$w');
      expect(over, isEmpty);
      expectTextInside(tester, size.width);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('Changes in a wide app font, $w', (tester) async {
      showDetails.value = false;
      late Daemon d;
      final over = await _overflows(() async {
        d = await _window(tester, size);
        d.chats[heroChat.id]!.tab.value = ChatTab.changes;
        await _pump(tester, 10);
      });
      await render(tester, find.byType(NushiApp), 'wide_font_changes_$w');
      expect(over, isEmpty);
      expectTextInside(tester, size.width);
      await closeView(tester, d);
    }, variant: _mac);

    testWidgets('every section of Settings in a wide app font, $w', (
      tester,
    ) async {
      appFont.value = NushiTheme.codeFont;
      var where = '';
      final over = await _overflows(() async {
        final d = await pumpSettingsApp(
          tester,
          settingsFake(),
          SettingsSection.appearance,
          size: size,
        );
        for (final section in SettingsSection.values) {
          where = '${section.title}, $w:';
          d.openSettings(section: section);
          await tester.pumpAndSettle();
          expectTextInside(tester, size.width);
          await render(
            tester,
            find.byType(NushiApp),
            'wide_font_settings_${section.name}_$w',
          );
        }
        d.dispose();
      }, where: () => where);
      expect(over.where((o) => !_known.any(o.startsWith)), isEmpty);
    }, variant: _mac);
  }

  // The chat's header folds its parts by what its words take, measured in
  // the bundled font: in a wider one it folds sooner, and at no width does
  // the row run past its end, for any of the demo's chats (a Jira key, a
  // pull request, each agent's name and state), the sidebar shown or not.
  // Down to 600: under about 560 with the sidebar showing, what never
  // folds is wider than the pane in the bundled font too.
  testWidgets('the chat header fits at every width in a wide app font', (
    tester,
  ) async {
    var where = '';
    final over = await _overflows(() async {
      final d = await _window(tester, const Size(1700, 900));
      for (final hidden in [false, true]) {
        sidebarHidden.value = hidden;
        for (final c in demoChats()) {
          d.select(c.id);
          for (var w = 1700.0; w >= 600; w -= 20) {
            where = '${c.title}, $w${hidden ? ', no sidebar' : ''}:';
            tester.view.physicalSize = Size(w, 900);
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
      }
      await closeView(tester, d);
    }, where: () => where);
    expect(over.join('\n'), isEmpty);
  }, variant: _mac);

  // What the pictures above compare with: the same window in the bundled
  // font. A render only.
  testWidgets('the main window in the bundled font, for comparison', (
    tester,
  ) async {
    final d = await _window(tester, const Size(1700, 1000), font: null);
    await render(tester, find.byType(NushiApp), 'wide_font_window_bundled');
    await closeView(tester, d);
  }, variant: _mac);
}
