import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'harness.dart';

// The app on a chat with every kind of pane to open beside it, for the
// layout's tests and renders (ADR 0123). It reads nothing of the layout's
// own code, so the same renders can be made of an older app.

/// What the chat in [panesApp] holds: a question, a subagent's call that
/// read a file, a background command still running, and the answer.
final panesItems = [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Where is the login redirect handled?',
  ),
  Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    title: 'Find the redirect',
    status: 'completed',
    subagent: Subagent(state: 'done', result: 'In `auth/redirect.go`.'),
  ),
  Item(
    id: 'r',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    parent: 'a',
    title: 'Read auth/redirect.go',
    status: 'completed',
  ),
  Item(
    id: 'cmd',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    title: 'npm run dev',
    status: 'completed',
    backgroundCommand: BackgroundCommand(
      state: 'running',
      started: Int64(
        fixtureNow.subtract(const Duration(seconds: 12)).millisecondsSinceEpoch,
      ),
      output: 'ready on http://localhost:3000\n',
    ),
  ),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'It is handled in `auth/redirect.go`.',
  ),
];

/// The panes a [panesApp] opens: the side chat, Files, a subagent's pane
/// or a background command's, `previews` files' previews or `browser`
/// browser tabs (or both, files first: the last opened shows).
typedef PanesOpen = ({
  bool side,
  bool files,
  bool subagent,
  bool command,
  int previews,
  int browser,
});

/// No pane open.
const PanesOpen noPanes = (
  side: false,
  files: false,
  subagent: false,
  command: false,
  previews: 0,
  browser: 0,
);

/// The app on chat c ([panesItems]), its window [width] by [height], the
/// sidebar shown or hidden, the details wanted or not, the terminal open
/// or not and [open]'s panes open, the chat archived or not, holding
/// [items] ([panesItems] by default). The fake is
/// returned, to count what was asked; [folderCancels] hears each folder
/// whose listing's watch ends. FindChatFiles finds those of [found].
Future<(Daemon, FakeDaemon)> panesApp(
  WidgetTester tester, {
  required double width,
  double height = 900,
  bool sidebar = false,
  bool details = true,
  bool terminal = false,
  bool archived = false,
  Brightness? brightness,
  PanesOpen open = noPanes,
  Map<String, double> widths = const {},
  List<Item>? items,
  List<String>? folderCancels,
  Set<String> found = const {},
}) async {
  // On Linux, its window and conventions, as a real Linux machine has.
  if (defaultTargetPlatform == TargetPlatform.linux) {
    native
      ..window = const LinuxWindow()
      ..conventions = linuxConventions;
  }
  showDetails.value = details;
  sidebarHidden.value = !sidebar;
  paneWidths.value = widths;
  filesChats.value = {};
  terminalChats.value = terminal ? {'c'} : {};
  chatFullWidth.value = false;
  final c = chat('c', 'claude', 'Fix the login redirect')..archived = archived;
  final fake = FakeDaemon([c, chat('d', 'codex', 'Fix the cart', age: 5)]);
  final shells = FakeShells(
    fake,
    terminals: [
      Terminal(id: 't', chatId: 'c', folder: '/Users/me/nushi', shell: 'fish'),
    ],
  );
  final shellStreams = fake.streams;
  final opened = <StreamController<Object?>>[];
  addTearDown(() {
    for (final s in opened) {
      unawaited(s.close());
    }
  });
  Object? answer(Object input) => switch (input) {
    GetChatRequest(:final chatId) when chatId == 'c' => GetChatResponse(
      chat: c,
      items: items ?? panesItems,
    ),
    GetChatRequest() => GetChatResponse(),
    FindChatFilesRequest(:final paths) => FindChatFilesResponse(
      found: paths.where(found.contains),
    ),
    _ => null,
  };
  Stream<Object>? streams(Object input) {
    switch (input) {
      case WatchChatFileRequest(:final path):
        final text = '# ${path.split('/').last}\n\nBrew, then pour.\n';
        final s = StreamController<WatchChatFileResponse>()
          ..add(
            WatchChatFileResponse(
              path: '/Users/me/nushi/$path',
              data: utf8.encode(text),
              size: Int64(text.length),
            ),
          );
        opened.add(s);
        return s.stream;
      case WatchChatFolderRequest(:final path):
        final s =
            StreamController<WatchChatFolderResponse>(
              onCancel: () => folderCancels?.add(path),
            )..add(
              WatchChatFolderResponse(
                folders: [
                  FolderListing(
                    path: path,
                    entries: [
                      FolderEntry(name: 'auth', kind: 'folder'),
                      FolderEntry(name: 'README.md', kind: 'file'),
                    ],
                  ),
                ],
              ),
            );
        opened.add(s);
        return s.stream;
    }
    return shellStreams?.call(input);
  }

  fake
    ..on(answer)
    ..streams = streams;
  shells.replay['t'] = r'$ ';
  final d = await openApp(
    tester,
    fake,
    size: Size(width, height),
    brightness: brightness,
  );
  await openPanesIn(tester, d, open);
  return (d, fake);
}

/// Opens [open]'s panes on chat c, the way the app does, and settles.
Future<void> openPanesIn(WidgetTester tester, Daemon d, PanesOpen open) async {
  final c = d.chats['c']!;
  if (open.side) c.side.value = ChatState('s', '/Users/me')..title = 'Side';
  if (open.files) filesChats.value = {...filesChats.value, 'c'};
  for (var i = 0; i < open.previews; i++) {
    c.openInFiles(['PLAN.md', 'auth/redirect.go', 'NOTES.md'][i % 3]);
  }
  for (var i = 0; i < open.browser; i++) {
    c.openBrowserTab('http://localhost:${3000 + i}');
  }
  if (open.subagent) c.pane.value = 'a';
  if (open.command) c.pane.value = 'cmd';
  await tester.pumpAndSettle();
}
