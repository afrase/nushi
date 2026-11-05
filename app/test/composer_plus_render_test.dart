// Renders of the composer's + menu and of attached files, in the whole
// window (wide and narrow, dark and light) and on the phone: to look at
// beside Claude's (`make renders TEST=test/composer_plus_render_test.dart`).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/attached_files.dart';
import 'package:nushi/composer_plus.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_cards.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A photo's stand-in for a thumbnail beside the file cards: a 96×64 PNG
/// of two colors.
Future<Uint8List> _photo(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      Canvas(rec)
        ..drawRect(
          const Rect.fromLTWH(0, 0, 96, 64),
          Paint()..color = const Color(0xFF4A7BB7),
        )
        ..drawCircle(
          const Offset(66, 24),
          12,
          Paint()..color = const Color(0xFFF2C14E),
        );
      final image = await rec.endRecording().toImage(96, 64);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return png!.buffer.asUint8List();
    }))!;

final Chat _chat = chat(
  'c',
  'claude',
  'Read the spec',
  status: ChatStatus(images: true),
);

final _items = [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'What does the spec say about retries? Compare with @lib/retry.go',
    files: ['lib/retry.go', 'docs/notes.md', '/Users/me/Downloads/spec.pdf'],
  ),
  Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'The spec asks for three retries with backoff; `retry.go` does two.',
  ),
];

FakeDaemon _fake() => FakeDaemon([_chat])
  ..answer = (input) => input is GetChatRequest
      ? GetChatResponse(chat: _chat, items: _items)
      : null;

/// Files and a photo in the chat's box.
Future<void> _attach(WidgetTester tester, Daemon d) async {
  final photo = await _photo(tester);
  final draft = d.chats['c']!.draft;
  draft.files.value = [
    const AttachedFile(
      name: 'spec.pdf',
      size: 1260000,
      path: '/Users/me/Downloads/spec.pdf',
    ),
    const AttachedFile(
      name: 'a-very-long-file-name-for-the-meeting-notes.md',
      size: 4200,
      path:
          '/Users/me/nushi/docs/a-very-long-file-name-for-the-meeting-notes.md',
    ),
  ];
  draft.images.value = [ImageData(mimeType: 'image/png', data: photo)];
  await tester.pump();
  // The thumbnail decodes on the real clock.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
}

void main() {
  setUpAll(loadFonts);

  for (final width in [1700.0, 720.0]) {
    for (final dark in [true, false]) {
      final name = '${width.round()}_${dark ? 'dark' : 'light'}';
      testWidgets('the window at $name: the menu open, then files attached', (
        tester,
      ) async {
        viewport(
          tester,
          Size(width, 900),
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        sidebarHidden.value = true;
        final d = await _fake().connect(tester);
        d.select('c');
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(plusTooltip));
        await tester.pump();
        expect(find.text('Add files or photos'), findsOne);
        expect(find.text('⌘U'), findsOne);
        await render(tester, find.byType(NushiApp), 'plus_menu_$name');
        await tester.tapAt(const Offset(5, 5)); // the menu shuts
        await tester.pump();

        await _attach(tester, d);
        await tester.pumpAndSettle();
        expect(find.byType(FileCard), findsNWidgets(2));
        expect(find.byType(FileChip), findsNWidgets(2)); // not the mention
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'plus_files_$name');
        await closeView(tester, d);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    final name = '${size.width.round()}x${size.height.round()}';
    testWidgets('the phone at $name: the menu, then files attached', (
      tester,
    ) async {
      viewport(tester, size, ratio: 3);
      final platform = PhonePlatform()..saved = pairedRecord();
      final fake = _fake();
      final phone = await startPhone(tester, fake, platform: platform);
      await tester.tap(find.text('Read the spec'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(plusTooltip));
      await tester.pumpAndSettle();
      expect(find.text('Add files or photos'), findsOne);
      expect(find.text('⌘U'), findsNothing); // no keys on the phone
      await render(tester, find.byType(PhoneApp), 'plus_menu_phone_$name');
      await tester.tap(find.text('Mention a file'));
      await tester.pumpAndSettle();
      await _attach(tester, phone.daemon!);
      await tester.pumpAndSettle();
      expect(find.byType(FileCard), findsNWidgets(2));
      await render(tester, find.byType(PhoneApp), 'plus_files_phone_$name');
      await endPhone(tester, phone);
    });
  }
}
