import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The app on chat c at [size], its Files pane open when [open], the
/// folder a few entries the fake daemon lists once.
Future<Daemon> _app(
  WidgetTester tester, {
  Size size = const Size(1700, 900),
  Brightness? brightness,
  bool open = false,
}) async {
  viewport(tester, size, brightness: brightness);
  filesChats.value = open ? {'c'} : {};
  final c = chat('c', 'claude', 'Write the report');
  final d =
      await (FakeDaemon([c])
            ..answer = ((input) => input is GetChatRequest
                ? GetChatResponse(
                    chat: c,
                    items: [
                      Item(
                        id: 'u',
                        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
                        text: 'Write the report.',
                      ),
                    ],
                  )
                : null)
            ..streams = (input) {
              if (input is! WatchChatFolderRequest) return null;
              final s = StreamController<WatchChatFolderResponse>();
              addTearDown(s.close);
              s.add(
                WatchChatFolderResponse(
                  folders: [
                    FolderListing(
                      path: input.path,
                      entries: [
                        FolderEntry(name: 'docs', kind: 'folder'),
                        FolderEntry(name: 'README.md', kind: 'file'),
                      ],
                    ),
                  ],
                ),
              );
              return s.stream;
            })
          .connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Finder get _button => find.byType(FilesButton);

Color? _ink(WidgetTester tester) => tester
    .widget<IconTap>(
      find.descendant(of: _button, matching: find.byType(IconTap)),
    )
    .color;

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// ⇧⌘E, as pressed.
Future<void> _shiftCmdE(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

/// Picks View › Files in the menu bar.
Future<void> _viewFiles(WidgetTester tester) async {
  final view = tester
      .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
      .menus
      .whereType<PlatformMenu>()
      .firstWhere((m) => m.label == 'View');
  Iterable<PlatformMenuItem> items(PlatformMenuItem m) => switch (m) {
    PlatformMenuItemGroup(:final members) => members.expand(items),
    _ => [m],
  };
  view.menus.expand(items).firstWhere((m) => m.label == 'Files').onSelected!();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the header’s Files button shows and hides the pane, lit '
      'while it shows', (tester) async {
    final d = await _app(tester);
    final t = NushiTheme.of(tester.element(_button)).t;
    expect(find.byType(FilesPane), findsNothing);
    expect(find.byTooltip('Show files  ⇧⌘E'), findsOne);
    expect(_ink(tester), t.textSecondary);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(find.byType(FilesPane), findsOne);
    expect(filesChats.value, {'c'});
    expect(find.byTooltip('Hide files  ⇧⌘E'), findsOne);
    expect(_ink(tester), t.accentInk);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(find.byType(FilesPane), findsNothing);
    expect(filesChats.value, isEmpty);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('on the Changes tab it is unlit, and brings the chat back '
      'with the pane', (tester) async {
    final d = await _app(tester, open: true);
    final c = d.chats['c']!;
    c.tab.value = ChatTab.changes;
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show files  ⇧⌘E'), findsOne);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(c.tab.value, ChatTab.chat);
    expect(filesChats.value, {'c'});
    expect(find.byType(FilesPane), findsOne);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('⇧⌘E and View › Files light and unlight it as the button '
      'would', (tester) async {
    final d = await _app(tester);
    final t = NushiTheme.of(tester.element(_button)).t;
    await _shiftCmdE(tester);
    expect(find.byType(FilesPane), findsOne);
    expect(find.byTooltip('Hide files  ⇧⌘E'), findsOne);
    expect(_ink(tester), t.accentInk);
    await _viewFiles(tester);
    expect(find.byType(FilesPane), findsNothing);
    expect(find.byTooltip('Show files  ⇧⌘E'), findsOne);
    expect(_ink(tester), t.textSecondary);
    await _viewFiles(tester);
    expect(find.byType(FilesPane), findsOne);
    expect(_ink(tester), t.accentInk);
    await _shiftCmdE(tester);
    expect(find.byType(FilesPane), findsNothing);
    expect(_ink(tester), t.textSecondary);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('⇧⌘E and View › Files on the Changes tab bring the chat back '
      'with the pane, not close it', (tester) async {
    final d = await _app(tester, open: true);
    final c = d.chats['c']!;
    final t = NushiTheme.of(tester.element(_button)).t;
    for (final pick in [() => _shiftCmdE(tester), () => _viewFiles(tester)]) {
      c.tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      expect(_ink(tester), t.textSecondary);
      await pick();
      expect(c.tab.value, ChatTab.chat);
      expect(filesChats.value, {'c'});
      expect(find.byType(FilesPane), findsOne);
      expect(find.byTooltip('Hide files  ⇧⌘E'), findsOne);
      expect(_ink(tester), t.accentInk);
    }
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the button sits between the terminal’s and the details’; '
      '⋯ has no Show files', (tester) async {
    final d = await _app(tester);
    final terminal = tester.getRect(find.byType(TerminalButton));
    final files = tester.getRect(_button);
    final details = tester.getRect(find.byTooltip('Hide details'));
    expect(files.left - terminal.right, NushiTheme.iconGap);
    expect(details.left - files.right, NushiTheme.iconGap);
    expect(files.size, terminal.size);
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('files', findRichText: true), findsNothing);
    expect(find.text('Rename', findRichText: true), findsOne);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('narrow, it folds into ⋯ with the terminal’s and the '
      'details’', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    filesChats.value = {};
    final c = ChatState('c', '/Users/me/repo')
      ..agent = 'claude'
      ..title = 'Fix the login redirect';
    Future<void> pump(double width) => tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ChatHeader(
                c,
                d,
                tab: ChatTab.chat,
                onTab: (_) {},
                panel: false,
                onPanel: () {},
              ),
            ),
          ),
        ),
      ),
    );
    // Where the terminal's is a button, so is the files'.
    for (var width = 320.0; width <= 1200; width += 10) {
      await pump(width);
      expect(
        _button.evaluate().length,
        find.byType(TerminalButton).evaluate().length,
        reason: '$width wide',
      );
    }
    await pump(330);
    expect(_button, findsNothing);
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    final labels = [
      for (final e in find.byType(RichText).evaluate())
        (e.widget as RichText).text.toPlainText(),
    ];
    expect(labels.where((l) => l.startsWith('Show ')).toList(), [
      'Show terminal',
      'Show files',
      'Show details',
    ]);
    await tester.tap(find.text('Show files', findRichText: true));
    await tester.pumpAndSettle();
    expect(filesChats.value, {'c'});
    d.dispose();
  });

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final (size, width) in [('wide', 1700.0), ('narrow', 720.0)]) {
      for (final open in [false, true]) {
        final state = open ? 'open' : 'closed';
        testWidgets('renders: the header, the pane $state, $size, $name', (
          tester,
        ) async {
          final d = await _app(
            tester,
            size: Size(width, 900),
            brightness: brightness,
            open: open,
          );
          expect(tester.takeException(), isNull);
          expect(_button, findsOne);
          expect(find.byType(FilesPane), open ? findsOne : findsNothing);
          expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'files_button_${size}_${state}_$name',
          );
          await closeView(tester, d);
        }, variant: _mac);
      }
    }
  }
}
