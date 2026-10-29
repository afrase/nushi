import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/tool_calls.dart';

import 'fake_daemon.dart';

const _report = '''
# CI and releases, week of Oct 26

_Steps 344–348 · written by Claude_

## What changed

- CI runs as parallel jobs: four on macOS, three on Linux.
- The app's tests run in two shards, three files at once.
- A release builds the app, relays and web app side by side.

## Timings

| Run          | Before | After |
|--------------|-------:|------:|
| CI on a push |  12:57 |  3:13 |
| Release      |  19:30 |  5:21 |

![the timings](img/timings.png)

![a remote one](https://example.com/logo.png)

## Still slow

Go isn't on the macOS runner image, so each job installs it (about 22 s).

```
make test-app SHARD=1/2
```
''';

const _plan = '# The plan\n\nShip it.\n';

Item _call(String id, String kind, String title, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: kind,
  title: title,
  status: 'completed',
  paths: [path],
);

final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text:
        'Write up what changed in CI and releases this week as '
        'docs/history/release-report.md, with the before/after timings.',
  ),
  _call('r', 'read', 'Read', 'docs/history/notes.md'),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'I read the step notes; writing the report.',
  ),
  _call('w', 'edit', 'Write', 'docs/history/release-report.md')
    ..diffs.add(
      FileChange(path: 'docs/history/release-report.md', newText: _report),
    ),
  Item(
    id: 'm1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'The report is written. Now the plan, and the chart.',
  ),
  _call('g', 'edit', 'Edit', 'internal/api/api.go')
    ..diffs.add(
      FileChange(path: 'internal/api/api.go', oldText: 'a\n', newText: 'b\n'),
    ),
  _call('p', 'edit', 'Write', 'docs/plan.md'),
  _call('i', 'edit', 'Write', 'docs/history/img/timings.png'),
  Item(
    id: 'm2',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'The report is written.',
  ),
];

final Chat _chat = chat('c', 'claude', 'Write the release report');

/// A daemon at [api] with that chat; the files asked for go in [asked],
/// each answered once and left open (the daemon keeps watching).
FakeDaemon _fake({int api = apiVersion, List<String>? asked}) {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  return FakeDaemon([_chat])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(chat: _chat, items: _items),
      PingRequest() => PingResponse(apiVersion: api),
      _ => null,
    })
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      asked?.add(input.path);
      final path = input.path.startsWith('/')
          ? input.path
          : '/Users/me/nushi/${input.path}';
      final text = switch (input.path) {
        'docs/history/release-report.md' => _report,
        'docs/plan.md' => _plan,
        _ => null,
      };
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        text == null
            ? WatchChatFileResponse(path: path, missing: true)
            : WatchChatFileResponse(
                path: path,
                data: utf8.encode(text),
                size: Int64(text.length),
              ),
      );
      return s.stream;
    };
}

/// The Mac app on that chat.
Future<Daemon> _app(
  WidgetTester tester, {
  double width = 1700,
  List<String>? asked,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  showDetails.value = false;
  paneWidths.value = {};
  subagentWide.value = false;
  Collapsible.opened.clear();
  final d = await _fake(asked: asked).connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

/// The phone in that chat, its Mac's daemon at [api].
Future<(Phone, PhonePlatform)> _phone(
  WidgetTester tester, {
  int api = apiVersion,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = const Size(390, 844) * 3;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  Collapsible.opened.clear();
  final platform = PhonePlatform()
    ..saved = {
      'key': Uint8List(32)..[0] = 7,
      'name': 'iPhone',
      'relay': 'wss://nushi.aaronfrase.com',
      'daemon': 'ArJKFXeGeF5z4WCydMz-dOXinj4sE99eMxmb-oJ3qLE',
      'daemonKey': Uint8List(32)..[0] = 9,
    };
  final fake = _fake(api: api);
  final phone = Phone(
    platform,
    connectTo: (_) => Daemon(transport: fake, remote: true),
  );
  await tester.pumpWidget(PhoneApp(phone));
  await phone.start();
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
  await tester.tap(find.text('Write the release report'));
  await tester.pumpAndSettle();
  return (phone, platform);
}

Future<void> _end(WidgetTester tester, Phone phone) async {
  await phone.close();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Finder _previewOf(String id) => find.descendant(
  of: find.byWidgetPredicate((w) => w is ToolCallView && w.item.id == id),
  matching: find.byType(PreviewButton),
);

Finder get _groupPreview => find.descendant(
  of: find.byType(ToolGroupView),
  matching: find.byWidgetPredicate(
    (w) => w is PreviewButton && w.path == 'docs/history/img/timings.png',
  ),
);

Finder get _buttons => find.descendant(
  of: find.byType(PreviewButton),
  matching: find.text('Preview'),
);

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('Preview on rows that wrote Markdown or an image', (
    tester,
  ) async {
    final d = await _app(tester);
    // The report's row, and the folded run of three (its last: the image).
    expect(_buttons, findsNWidgets(2));
    expect(
      find.descendant(of: _previewOf('w'), matching: find.text('Preview')),
      findsOneWidget,
    );
    expect(_groupPreview, findsOneWidget);
    // Opened, the run's rows: the plan and the image; not the Go file.
    await tester.tap(find.text('Edited 3 files'));
    await tester.pumpAndSettle();
    expect(_buttons, findsNWidgets(4));
    expect(_previewOf('p'), findsOneWidget);
    expect(_previewOf('i'), findsOneWidget);
    expect(_previewOf('g'), findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('the phone: the preview full screen, Back to the chat', (
    tester,
  ) async {
    final (phone, platform) = await _phone(tester);
    final rows = platform.entries.length;
    await tester.tap(
      find.descendant(of: _previewOf('w'), matching: find.text('Preview')),
    );
    await tester.pumpAndSettle();
    final screen = find.byType(PreviewScreen);
    expect(screen, findsOneWidget);
    expect(platform.entries.length, rows + 1); // its own history entry
    Finder inScreen(Finder f) => find.descendant(of: screen, matching: f);
    expect(inScreen(find.text('release-report.md')), findsOneWidget);
    expect(inScreen(find.text('Live')), findsOneWidget);
    expect(
      inScreen(
        find.text('CI and releases, week of Oct 26', findRichText: true),
      ),
      findsOneWidget,
    );
    await tester.tap(inScreen(find.text('Source')));
    await tester.pumpAndSettle();
    expect(inScreen(find.textContaining('| CI on a push |')), findsOneWidget);
    expect(inScreen(find.text('Show in Finder')), findsNothing);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(screen, findsNothing);
    expect(find.text('Write the release report'), findsOneWidget);
    await _end(tester, phone);
  }, variant: _ios);

  testWidgets('no Preview with an older daemon (the phone)', (tester) async {
    final (phone, _) = await _phone(tester, api: 74);
    expect(
      find.textContaining('release-report.md', findRichText: true),
      findsWidgets,
    );
    expect(_buttons, findsNothing);
    await _end(tester, phone);
  }, variant: _ios);

  testWidgets('the pane: rendered, its source, another file, closed', (
    tester,
  ) async {
    final asked = <String>[];
    final d = await _app(tester, asked: asked);
    final pane = find.byType(PreviewPane);
    expect(pane, findsNothing);

    await tester.tap(
      find.descendant(of: _previewOf('w'), matching: find.text('Preview')),
    );
    await tester.pumpAndSettle();
    expect(pane, findsOneWidget);
    Finder inPane(Finder f) => find.descendant(of: pane, matching: f);
    expect(inPane(find.text('release-report.md')), findsOneWidget);
    expect(inPane(find.text('Live')), findsOneWidget);
    // Rendered: the heading's text without its #, the table's cells.
    expect(
      inPane(find.text('CI and releases, week of Oct 26', findRichText: true)),
      findsOneWidget,
    );
    expect(
      inPane(find.textContaining('# CI and releases', findRichText: true)),
      findsNothing,
    );
    // The relative image through the daemon, beside the file (missing
    // here: its alt text); the remote one as text.
    expect(asked, [
      'docs/history/release-report.md',
      '/Users/me/nushi/docs/history/img/timings.png',
    ]);
    expect(inPane(find.text('[image: the timings]')), findsOneWidget);
    expect(
      inPane(find.textContaining('[image: a remote one]', findRichText: true)),
      findsOneWidget,
    );

    // Source: the text as written.
    await tester.tap(inPane(find.text('Source')));
    await tester.pumpAndSettle();
    expect(
      inPane(find.textContaining('# CI and releases, week of Oct 26')),
      findsOneWidget,
    );
    expect(inPane(find.textContaining('| CI on a push |')), findsOneWidget);

    // Another row's Preview switches the pane to its file.
    await tester.tap(find.text('Edited 3 files'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: _previewOf('p'), matching: find.text('Preview')),
    );
    await tester.pumpAndSettle();
    expect(pane, findsOneWidget);
    expect(inPane(find.text('plan.md')), findsOneWidget);
    expect(inPane(find.text('Ship it.', findRichText: true)), findsOneWidget);
    expect(asked.last, 'docs/plan.md');

    await tester.tap(inPane(find.byTooltip('Close')));
    await tester.pumpAndSettle();
    expect(pane, findsNothing);
    d.dispose();
  }, variant: _mac);

  test('a preview and a subagent take one place', () {
    final c = ChatState('c', '/Users/me/nushi')..openPreview('a.md');
    expect(c.preview.value, 'a.md');
    c.pane.value = 'agent';
    expect(c.preview.value, isNull);
    c.openPreview('b.md');
    expect((c.pane.value, c.preview.value), (null, 'b.md'));
  });

  testWidgets('golden: the pane with a Markdown file, dark, wide', (
    tester,
  ) async {
    final d = await _app(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.tap(
      find.descendant(of: _previewOf('w'), matching: find.text('Preview')),
    );
    await tester.pumpAndSettle();
    // Its header's buttons at its right edge.
    expect(tester.getTopRight(find.byTooltip('Close')).dx, greaterThan(1660));
    await expectLater(
      find.byType(NushiApp),
      matchesGoldenFile('goldens/preview_markdown_dark.png'),
    );
    d.dispose();
  }, variant: _mac);
}
