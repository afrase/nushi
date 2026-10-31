import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/web_page.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// What the preview tabs' tests share: a chat that wrote two files, its
// daemon, the app on it, and where to look.

const Map<String, String> tabFilesText = {
  'docs/report.md': '# The report\n\nAll well.\n',
  'docs/plan.md': '# The plan\n\nShip it.\n',
  'site/plan.md': '# Another plan\n',
  'site/index.html': '<h1>The page</h1>\n',
  'a.csv': 'id,name\n1,tea\n',
};

Item writeCall(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'edit',
  title: 'Write',
  status: 'completed',
  paths: [path],
);

Item agentSays(String id) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Wrote it.');

final tabItems = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Write the report and the plan.',
  ),
  writeCall('r', 'docs/report.md'),
  agentSays('m1'),
  writeCall('p', 'docs/plan.md'),
  agentSays('m2'),
];

const tabModel = 'claude-opus-5-5[1m]';

final tabPull = GitHubLink(
  host: 'github.com',
  repo: 'afrase/nushi',
  number: 12,
  pull: true,
);

/// A page host that says when it's made and gone.
class CountedPage implements PageHost {
  new(this.live) {
    live.value++;
  }

  final ValueNotifier<int> live;

  @override
  Widget view(BuildContext context) =>
      const ColoredBox(color: Color(0xFFFBF7F0), child: SizedBox.expand());

  @override
  Future<void> load(String path, String root) async {}

  @override
  Future<void> reload() async {}

  @override
  void dispose() => live.value--;
}

/// The daemon: each file answered once, its stream left open; a file
/// that isn't in [tabFilesText] is missing. Whatever's asked goes in [asked].
FakeDaemon tabsDaemon({
  List<String>? asked,
  bool pull = false,
  bool model = false,
}) {
  final open = <StreamController<WatchChatFileResponse>>[];
  addTearDown(() {
    for (final s in open) {
      unawaited(s.close());
    }
  });
  final c = chat('c', 'claude', 'Write the release report')
    ..pull = (pull ? tabPull : GitHubLink());
  if (!pull) c.clearPull();
  return FakeDaemon([c])
    ..answer = ((input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: tabItems,
        config: [
          if (model)
            ConfigOption(
              id: 'model',
              category: 'model',
              current: tabModel,
              values: [ConfigValue(value: tabModel, name: tabModel)],
            ),
        ],
      ),
      FindChatPullRequest() => FindChatPullResponse(
        pull: pull ? tabPull : null,
      ),
      ListTerminalsRequest(:final chatId) => ListTerminalsResponse(
        terminals: [
          Terminal(id: 't1', chatId: chatId, folder: '/tmp', shell: 'zsh'),
        ],
      ),
      _ => null,
    })
    ..streams = (input) {
      if (input is AttachTerminalRequest) {
        return StreamController<AttachTerminalResponse>().stream;
      }
      if (input is! WatchChatFileRequest) return null;
      asked?.add(input.path);
      final text = tabFilesText[input.path];
      final s = StreamController<WatchChatFileResponse>();
      open.add(s);
      s.add(
        text == null
            ? WatchChatFileResponse(
                path: '/Users/me/nushi/${input.path}',
                missing: true,
              )
            : WatchChatFileResponse(
                path: '/Users/me/nushi/${input.path}',
                data: utf8.encode(text),
                size: Int64(text.length),
              ),
      );
      return s.stream;
    };
}

Future<Daemon> tabsApp(
  WidgetTester tester, {
  double width = 1700,
  Brightness? brightness,
  List<String>? asked,
  bool pull = false,
  bool model = false,
  ValueNotifier<int>? pages,
}) async {
  viewport(tester, Size(width, 900), brightness: brightness);
  showDetails.value = false;
  paneWidths.value = {};
  if (pages != null) {
    final was = newPageHost;
    newPageHost = () => CountedPage(pages);
    addTearDown(() => newPageHost = was);
  }
  final d = await tabsDaemon(
    asked: asked,
    pull: pull,
    model: model,
  ).connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Future<void> pressKeys(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool meta = false,
  bool control = false,
}) async {
  final mods = [
    if (control) LogicalKeyboardKey.controlLeft,
    if (meta) LogicalKeyboardKey.metaLeft,
  ];
  for (final m in mods) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyEvent(key);
  for (final m in mods.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pumpAndSettle();
}

Finder previewOf(String id) => find.descendant(
  of: find.byWidgetPredicate((w) => w is ToolCallView && w.item.id == id),
  matching: find.byType(PreviewButton),
);

Finder get paneView =>
    find.byWidgetPredicate((w) => w is PreviewPane && !w.tab);

Finder get tabView => find.byWidgetPredicate((w) => w is PreviewPane && w.tab);

Finder get headerView => find.byType(ChatHeader);

Finder inHeader(Finder f) => find.descendant(of: headerView, matching: f);

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Clicks the row's Preview with ⌘ held.
Future<void> commandClick(WidgetTester tester, String id) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.tap(previewOf(id));
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

final macOnly = TargetPlatformVariant.only(TargetPlatform.macOS);
