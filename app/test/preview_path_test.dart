import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _roadmap = '# Roadmap\n\n## Previews\n\nWhat a preview shows.\n';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The daemon: a chat whose folder holds `docs/roadmap.md`; any file is
/// its text.
FakeDaemon _fake() {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final c = chat('c', 'claude', 'Plan the work', folder: '/Users/me/kettle');
  return FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: [
          Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Plan.'),
        ],
      ),
      _ => null,
    })
    ..streams = (input) {
      if (input is! WatchChatFileRequest) return null;
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        WatchChatFileResponse(
          path: input.path.startsWith('/')
              ? input.path
              : '/Users/me/kettle/${input.path}',
          data: utf8.encode(_roadmap),
          size: Int64(_roadmap.length),
        ),
      );
      return s.stream;
    };
}

/// The app on the chat, [file] in the preview.
Future<Daemon> _app(
  WidgetTester tester, {
  String file = 'docs/roadmap.md',
}) async {
  viewport(tester, const Size(1700, 900));
  showDetails.value = false;
  paneWidths.value = {};
  final d = await _fake().connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  d.chats['c']!.openPreview(file);
  await tester.pumpAndSettle();
  return d;
}

Finder _inPane(Finder f) =>
    find.descendant(of: find.byType(PreviewPane), matching: f);

void main() {
  setUpAll(loadFonts);

  test('the path line: relative inside the folder, from ~ outside', () {
    expect(
      shownPath('/Users/me/kettle', 'docs/roadmap.md'),
      'docs / roadmap.md',
    );
    expect(
      copiedPath('/Users/me/kettle', 'docs/roadmap.md'),
      'docs/roadmap.md',
    );
    expect(
      copiedPath('/Users/me/kettle', '/Users/me/kettle/docs/a.md'),
      'docs/a.md',
    );
    expect(copiedPath('/Users/me/kettle', '/etc/hosts'), '/etc/hosts');
    expect(shownPath('/Users/me/kettle', '/etc/hosts'), '/ etc / hosts');
  });

  testWidgets('a click on the path copies it and says so', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    final d = await _app(tester);
    expect(_inPane(find.text('docs / roadmap.md')), findsOneWidget);
    await tester.tap(_inPane(find.text('docs / roadmap.md')));
    await tester.pump();
    expect(copied, ['docs/roadmap.md']);
    expect(find.text('Copied'), findsOneWidget);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the source button: View source, then lit, View preview', (
    tester,
  ) async {
    final d = await _app(tester);
    final button = _inPane(find.byType(SourceButton));
    expect(_inPane(find.byTooltip('View source')), findsOneWidget);
    final at = tester.getRect(button);
    // At the pane's right, under Close.
    expect(
      at.right,
      closeTo(tester.getRect(_inPane(find.byTooltip('Close'))).right, 0.5),
    );
    expect(
      tester
          .widget<IconTap>(
            find.descendant(of: button, matching: find.byType(IconTap)),
          )
          .lit,
      isFalse,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(_inPane(find.byTooltip('View preview')), findsOneWidget);
    expect(
      tester
          .widget<IconTap>(
            find.descendant(of: button, matching: find.byType(IconTap)),
          )
          .lit,
      isTrue,
    );
    expect(
      _inPane(find.textContaining('## Previews', findRichText: true)),
      findsOneWidget,
    );
    expect(tester.getRect(button), at);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(_inPane(find.byTooltip('View source')), findsOneWidget);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a file outside the folder shows its path from ~', (
    tester,
  ) async {
    final home = Platform.environment['HOME']!;
    final d = await _app(tester, file: '$home/elsewhere/todo.md');
    expect(_inPane(find.text('~ / elsewhere / todo.md')), findsOneWidget);
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('golden: the path line, its path pointed at, the source '
        'button off and on, $name', (tester) async {
      viewport(tester, const Size(520, 120), brightness: brightness);
      await tester.pumpWidget(
        themed(
          tokens: brightness == Brightness.dark ? Tokens.dark : Tokens.light,
          Center(
            child: RepaintBoundary(
              key: const ValueKey('lines'),
              child: Container(
                width: 480,
                color:
                    (brightness == Brightness.dark ? Tokens.dark : Tokens.light)
                        .base,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final source in [false, true])
                      PathLine(
                        folder: '/Users/me/kettle',
                        path: 'docs/roadmap.md',
                        trailing: SourceButton(
                          source: source,
                          onChanged: (_) {},
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(
        location: tester.getCenter(find.text('docs / roadmap.md').first),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('lines')),
        matchesGoldenFile('goldens/preview_path_line_$name.png'),
      );
    }, variant: _mac);
  }
}
