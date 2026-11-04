// The composer's + menu, in the form of Claude's app (the owner's
// screenshot, 2026-11-04): Add files or photos (⌘U), Mention a file, Slash
// commands, each with a drawn icon; no Connectors. Files of any kind become
// file cards and go to the agent as links (ADR 0089).

import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/attached_files.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_plus.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The last box's daemon, which [_end] lets go of.
Daemon? _daemon;

/// Ends a test on a box: its daemon's timers stop.
void _end() => _daemon?.dispose();

/// A box on a chat whose folder is a new temp folder, [images] whether its
/// agent takes images, [api] the daemon's.
Future<(FakeDaemon, Daemon, ChatState)> _box(
  WidgetTester tester, {
  bool images = true,
  int? api,
  bool dark = true,
  Size size = const Size(640, 260),
}) async {
  viewport(tester, size);
  final folder = Directory.systemTemp.createTempSync('plus').path;
  addTearDown(() => Directory(folder).deleteSync(recursive: true));
  final fake = FakeDaemon([])
    ..answer = (input) => input is PingRequest && api != null
        ? PingResponse(apiVersion: api)
        : null;
  final d = await fake.connect(tester);
  final chat = ChatState('c', folder)
    ..agent = 'claude'
    ..loaded = true
    ..canImages = images
    ..commands = [Command(name: 'review', description: 'Review the diff')];
  d.chats['c'] = chat;
  final tokens = dark ? Tokens.dark : Tokens.light;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        backgroundColor: tokens.base,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ListenableBuilder(
              listenable: chat,
              builder: (context, _) => Composer(chat: chat, daemon: d),
            ),
          ],
        ),
      ),
    ),
  );
  _daemon = d;
  await tester.pump();
  return (fake, d, chat);
}

/// Writes [name] in [dir] with [bytes] bytes, and returns its path.
String _file(String dir, String name, {int bytes = 12}) {
  return (File('$dir/$name')
        ..createSync(recursive: true)
        ..writeAsBytesSync(Uint8List(bytes)))
      .path;
}

/// [pickFiles], [clipboardFiles] and [sendWhole] as they were, after the test.
void _restoreFakes() {
  final (pick, files, whole) = (pickFiles, clipboardFiles, sendWhole);
  addTearDown(() {
    pickFiles = pick;
    clipboardFiles = files;
    sendWhole = whole;
  });
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip(plusTooltip));
  await tester.pump();
}

Future<void> _cmd(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

SendPromptRequest _sent(FakeDaemon fake) =>
    fake.calls.whereType<SendPromptRequest>().single;

void main() {
  setUpAll(loadFonts);
  setUp(_restoreFakes);

  for (final dark in [true, false]) {
    testWidgets(
      'the menu: its rows, icons and key (${dark ? 'dark' : 'light'})',
      (tester) async {
        await _box(tester, dark: dark);
        await _openMenu(tester);
        for (final row in [
          'Add files or photos',
          'Mention a file',
          'Slash commands',
        ]) {
          expect(find.text(row), findsOne);
        }
        expect(find.text('Connectors'), findsNothing);
        // Above the box, as Claude's, each row with its drawn icon.
        final box = tester.getRect(find.byType(TextField));
        expect(
          tester.getRect(find.text('Slash commands')).bottom,
          lessThan(box.top),
        );
        expect(
          find.descendant(
            of: find.byType(MenuItemButton),
            matching: find.byType(CustomPaint),
          ),
          findsAtLeast(3),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/composer_plus_${dark ? 'dark' : 'light'}.png',
          ),
        );
        _end();
      },
      variant: _mac,
    );
  }

  testWidgets(
    'Slash commands offers the chat’s commands; Mention a file the files',
    (tester) async {
      final (_, _, chat) = await _box(tester);
      await tester.enterText(find.byType(TextField), 'the login page');
      await _openMenu(tester);
      await tester.tap(find.text('Slash commands'));
      await tester.pump();
      expect(chat.draft.text.text, '/the login page');
      await tester.pump(Motion.standard); // the list grows in
      final review = find.textContaining('/review', findRichText: true);
      expect(review, findsOne);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // picks it
      await tester.pump();
      expect(chat.draft.text.text, matches(r'^/\w+ the login page$'));

      await _openMenu(tester);
      await tester.tap(find.text('Mention a file'));
      await tester.pump();
      expect(chat.draft.text.text, contains(' @')); // at the cursor
      _end();
    },
    variant: _mac,
  );

  testWidgets(
    '⌘U picks files: a text file and a PDF are cards and go as links',
    (tester) async {
      final (fake, _, chat) = await _box(tester);
      final elsewhere = Directory.systemTemp.createTempSync('plus').path;
      addTearDown(() => Directory(elsewhere).deleteSync(recursive: true));
      final notes = _file(chat.folder, 'docs/notes.txt');
      final spec = _file(elsewhere, 'spec sheet.pdf', bytes: 3 << 20);
      var opened = 0;
      pickFiles = () async {
        opened++;
        return [XFile(notes), XFile(spec)];
      };
      await tester.tap(find.byType(TextField));
      await _cmd(tester, LogicalKeyboardKey.keyU);
      await tester.pump();
      expect(opened, 1);
      expect(find.byType(FileCard), findsNWidgets(2));
      expect(find.text('notes.txt'), findsOne);
      expect(find.text('PDF · 3.0 MB'), findsOne);
      await tester.pumpAndSettle(); // the cards' line grows in
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/composer_file_cards_dark.png'),
      );

      await tester.enterText(find.byType(TextField), 'Check these');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final sent = _sent(fake);
      expect(sent.files, ['docs/notes.txt', spec]);
      expect(sent.uploads, isEmpty);
      expect(chat.draft.files.value, isEmpty);
      _end();
    },
    variant: _mac,
  );

  testWidgets('an image to an agent without images is a file card', (
    tester,
  ) async {
    final (fake, _, chat) = await _box(tester, images: false);
    final shot = _file(chat.folder, 'shot.png');
    pickFiles = () async => [XFile(shot)];
    await _openMenu(tester);
    await tester.tap(find.text('Add files or photos'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FileCard), findsOne);
    expect(chat.draft.images.value, isEmpty);
    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_sent(fake).files, ['shot.png']);
    _end();
  }, variant: _mac);

  testWidgets('⌘V of Finder’s files attaches them; Enter waits for the read', (
    tester,
  ) async {
    final (fake, _, chat) = await _box(tester);
    final notes = _file(chat.folder, 'notes.md');
    final clipboard = Completer<List<String>>();
    clipboardFiles = () => clipboard.future;
    await tester.enterText(find.byType(TextField), 'This one');
    await _cmd(tester, LogicalKeyboardKey.keyV);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // before the read
    await tester.pump();
    expect(fake.calls.whereType<SendPromptRequest>(), isEmpty);
    clipboard.complete([notes]);
    await tester.pump();
    await tester.pump();
    expect(_sent(fake).files, ['notes.md']);
    expect(find.byType(FileCard), findsNothing); // sent with it, not left
    _end();
  }, variant: _mac);

  testWidgets('caps: ten files a message, no folders, nothing too large', (
    tester,
  ) async {
    final (_, _, chat) = await _box(tester);
    final eleven = [
      for (var i = 0; i < 11; i++) XFile(_file(chat.folder, 'f$i.txt')),
    ];
    Directory('${chat.folder}/src').createSync();
    expect(
      await attachFiles(chat, [XFile('${chat.folder}/src')], api: apiVersion),
      contains('src is a folder'),
    );
    final refused = await attachFiles(chat, eleven, api: apiVersion);
    expect(refused, contains('10 files at most'));
    expect(chat.draft.files.value, hasLength(maxAttachedFiles));

    chat.draft.files.value = const [];
    sendWhole = true; // the phone's: sent whole, 8 MB each at most
    final big = XFile.fromData(
      Uint8List(maxUploadBytes + 1),
      name: 'big.mov',
      path: 'big.mov',
    );
    final small = XFile.fromData(
      Uint8List(5),
      name: 'notes.txt',
      path: 'notes.txt',
    );
    expect(
      await attachFiles(chat, [big, small], api: apiVersion),
      'big.mov is over 8 MB',
    );
    expect([for (final f in chat.draft.files.value) f.name], ['notes.txt']);
    expect(
      await attachFiles(chat, [small], api: attachApi - 1),
      contains('photos only'),
    );
    final seven = [
      for (final n in ['a', 'b', 'c'])
        XFile.fromData(Uint8List(7 << 20), name: '$n.mov', path: '$n.mov'),
    ];
    expect(
      await attachFiles(chat, seven, api: apiVersion),
      'c.mov: a message sends 20 MB at most',
    );
    _end();
  }, variant: _mac);

  testWidgets('a file outside the folder waits for a daemon that takes it', (
    tester,
  ) async {
    final (_, _, chat) = await _box(tester, api: attachApi - 1);
    final elsewhere = Directory.systemTemp.createTempSync('plus').path;
    addTearDown(() => Directory(elsewhere).deleteSync(recursive: true));
    final refused = await attachFiles(chat, [
      XFile(_file(elsewhere, 'a.pdf')),
      XFile(_file(chat.folder, 'b.pdf')),
    ], api: attachApi - 1);
    expect(refused, contains('outside the chat’s folder'));
    expect([for (final f in chat.draft.files.value) f.name], ['b.pdf']);
    _end();
  }, variant: _mac);

  testWidgets('the phone’s files go whole, as uploads', (tester) async {
    final (fake, _, chat) = await _box(tester);
    sendWhole = true;
    pickFiles = () async => [
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'receipt.pdf',
        path: 'receipt.pdf',
      ),
    ];
    await _openMenu(tester);
    await tester.tap(find.text('Add files or photos'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FileCard), findsOne);
    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final sent = _sent(fake);
    expect(sent.files, isEmpty);
    expect(sent.uploads.single.name, 'receipt.pdf');
    expect(sent.uploads.single.data, [1, 2, 3]);
    _end();
  }, variant: _mac);

  testWidgets('a file’s name shows its bidi controls marked, never applied', (
    tester,
  ) async {
    final (_, _, chat) = await _box(tester);
    sendWhole = true;
    const spoof = 'report\u202efdp.sh'; // reads "reportsh.pdf" if applied
    expect(
      await attachFiles(chat, [
        XFile.fromData(Uint8List(3), name: spoof, path: spoof),
        XFile.fromData(
          Uint8List(maxUploadBytes + 1),
          name: 'x\u2066.mov',
          path: 'x\u2066.mov',
        ),
      ], api: apiVersion),
      'x\ufffd.mov is over 8 MB',
    );
    await tester.pump();
    expect(find.text('report\ufffdfdp.sh'), findsOne);
    expect(find.textContaining('\u202e'), findsNothing);
    _end();
  }, variant: _mac);

  testWidgets('on the phone against an older daemon: photos only, or none', (
    tester,
  ) async {
    sendWhole = true;
    final (_, _, chat) = await _box(tester, images: false, api: attachApi - 1);
    await _openMenu(tester);
    expect(find.text('Add photos'), findsOne);
    final row = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Add photos'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(row.onPressed, isNull);
    expect(find.byTooltip(RegExp('doesn’t take images')), findsOne);
    expect(chat.canImages, isFalse);
    _end();
  }, variant: _mac);

  testWidgets('a message taken back keeps its attached files as cards', (
    tester,
  ) async {
    final (_, d, chat) = await _box(tester);
    _file(chat.folder, 'a.go');
    chat.takeBack.value = QueuedMessage(
      text: 'look at @a.go and these',
      files: ['a.go', 'b.txt', '/Users/me/Downloads/spec.pdf'],
    );
    await tester.pump();
    expect(
      [for (final f in chat.draft.files.value) f.path],
      ['${chat.folder}/b.txt', '/Users/me/Downloads/spec.pdf'],
    );
    expect(chat.draft.mentions, {'a.go'});
    expect(d.chats['c'], chat);
    _end();
  }, variant: _mac);

  testWidgets('a sent message’s attached files are chips, its mentions not', (
    tester,
  ) async {
    viewport(tester, const Size(640, 200));
    final chat = ChatState('c', '/Users/me/nushi');
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                messageFiles(
                  context,
                  Item(
                    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
                    text: 'see @lib/a.dart',
                    files: [
                      'lib/a.dart',
                      'docs/b.md',
                      '/tmp/c.pdf',
                      '/tmp/d\u202efdp.sh',
                    ],
                  ),
                  chat,
                ) ??
                const SizedBox(),
          ),
        ),
      ),
    );
    expect(find.byType(FileChip), findsNWidgets(3));
    expect(find.text('d\ufffdfdp.sh'), findsOne);
    expect(find.text('b.md'), findsOne);
    expect(find.text('c.pdf'), findsOne);
    expect(find.text('a.dart'), findsNothing);
    expect(find.byTooltip('/Users/me/nushi/docs/b.md'), findsOne);
  }, variant: _mac);

  testWidgets('files dropped on the chat take the same way', (tester) async {
    viewport(tester, const Size(1200, 700));
    final folder = Directory.systemTemp.createTempSync('plus').path;
    addTearDown(() => Directory(folder).deleteSync(recursive: true));
    final c = chat('c', 'claude', 'Drop here', folder: folder);
    final fake = FakeDaemon([c]);
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    final drop = tester.widget<DropTarget>(find.byType(DropTarget).first);
    drop.onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile(_file(folder, 'a.txt')),
          DropItemFile(_file(folder, 'shot.png')), // no images: a card
          DropItemFile(folder), // a folder: refused, said
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FileCard), findsNWidgets(2));
    expect(find.textContaining('is a folder'), findsOne);
    await closeView(tester, d);
  }, variant: _mac);
}
