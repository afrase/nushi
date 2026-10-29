import 'dart:io';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/worktree.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final String _repo = '${Platform.environment['HOME']}/code/cappy';
final String _try = '$_repo/.worktrees/cappy/try-sqrly';

/// The owner's case: cappy on main, try-sqrly in a worktree of its own.
ListBranchesResponse _list({bool inTry = false}) => ListBranchesResponse(
  branches: [
    GitBranch(name: 'main', worktree: _repo),
    GitBranch(name: 'try-sqrly', worktree: _try),
    GitBranch(name: 'fix/login-redirect'),
    GitBranch(name: 'old-experiment'),
  ],
  worktrees: [
    GitWorktree(path: _repo, branch: 'main', main: true, current: !inTry),
    GitWorktree(path: _try, branch: 'try-sqrly', current: inTry),
    GitWorktree(path: '/tmp/cappy-locked', branch: 'kept', locked: true),
  ],
);

/// A chat with a message in cappy (or in try-sqrly's worktree).
ChatState _chat({bool busy = false, bool inTry = false}) =>
    ChatState('c', inTry ? _try : _repo)
      ..worktree = inTry
          ? Worktree(
              repo: _repo,
              path: _try,
              branch: 'try-sqrly',
              base: 'main',
              found: true,
            )
          : null
      ..load(
        GetChatResponse(
          items: [Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE)],
          status: ChatStatus(busy: busy),
        ),
      );

/// A daemon whose folder is on main (or try-sqrly), answering SwitchBranch
/// with [switched] in turn (the last one again after).
FakeDaemon _fake({
  bool inTry = false,
  List<SwitchBranchResponse> switched = const [],
}) {
  var n = 0;
  return FakeDaemon([Chat(id: 'c', agent: 'claude', folder: _repo)])
    ..answer = (input) => switch (input) {
      GetFolderStatusRequest() => GetFolderStatusResponse(
        git: true,
        branch: inTry ? 'try-sqrly' : 'main',
        defaultBase: 'main',
      ),
      ListBranchesRequest() => _list(inTry: inTry),
      SwitchBranchRequest() => switched[(n++).clamp(0, switched.length - 1)],
      _ => null,
    };
}

Future<Daemon> _panel(
  WidgetTester tester,
  FakeDaemon fake,
  ChatState chat, {
  Tokens tokens = Tokens.dark,
  VoidCallback? onChanges,
}) async {
  viewport(tester, const Size(560, 460), ratio: 2);
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: DetailsPanel.width,
            height: 460,
            child: DetailsPanel(
              chat: chat,
              daemon: d,
              onChanges: onChanges ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return d;
}

/// Opens the Branch row's menu.
Future<void> _open(WidgetTester tester, String branch) async {
  final environment = find.widgetWithText(PanelWidget, 'Environment');
  await tester.tap(
    find.descendant(of: environment, matching: find.text(branch)),
  );
  await tester.pumpAndSettle();
}

/// A menu row by its label (its detail follows it in the same text).
Finder _row(String label) => find.ancestor(
  of: find.textContaining(RegExp('^${RegExp.escape(label)}(\\s|\$)')),
  matching: find.byType(MenuItemButton),
);

void main() {
  setUpAll(loadFonts);
  setUp(() => collapsedWidgets.value = {});

  // The whole window, wide and as narrow as shows the panel: the menu
  // opens under the row, inside the window; the row's ▾ at the panel's
  // right edge.
  for (final width in [1700.0, 1100.0]) {
    testWidgets('the Branch menu in a ${width.round()} window', (tester) async {
      viewport(tester, Size(width, 620));
      showDetails.value = true;
      final c = Chat(
        id: 'c',
        agent: 'claude',
        title: 'Try sqrly',
        folder: _repo,
      );
      final fake = _fake()
        ..chats.add(c)
        ..answer = (input) => switch (input) {
          GetChatRequest() => GetChatResponse(
            chat: c,
            items: [
              Item(
                id: 'u',
                kind: ItemKind.ITEM_KIND_USER_MESSAGE,
                text: 'Open my worktree',
              ),
            ],
          ),
          GetFolderStatusRequest() => GetFolderStatusResponse(
            git: true,
            branch: 'main',
          ),
          ListBranchesRequest() => _list(),
          _ => null,
        };
      final d = await fake.connect(tester);
      d.select('c');
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byType(DetailsPanel));
      final box = tester.getRect(
        find.widgetWithText(PanelWidget, 'Environment'),
      );
      expect(panel.right, width);
      final chevron = tester.getRect(
        find
            .descendant(
              of: find.byType(MenuField),
              matching: find.byIcon(Icons.keyboard_arrow_down),
            )
            .first,
      );
      expect(box.right - chevron.right, lessThan(20));
      await _open(tester, 'main');
      final menu = tester.getRect(_row('New branch…'));
      expect(menu.right, lessThanOrEqualTo(width));
      expect(menu.top, greaterThan(chevron.bottom));
      expect(tester.takeException(), isNull);
      await closeView(tester, d);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

  testWidgets('golden, the Branch menu open, dark', (tester) async {
    final d = await _panel(tester, _fake(), _chat());
    await _open(tester, 'main');
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/branch_menu_dark.png'),
    );
    d.dispose();
  });

  testWidgets('the menu: branches newest first, the current one checked, '
      'another worktree’s marked, then New branch…', (tester) async {
    final d = await _panel(tester, _fake(), _chat());
    await _open(tester, 'main');
    final labels = [
      for (final b in tester.widgetList<MenuItemButton>(
        find.byType(MenuItemButton),
      ))
        b,
    ];
    expect(labels, hasLength(5));
    final y = [
      for (final l in [
        'main',
        'try-sqrly',
        'fix/login-redirect',
        'old-experiment',
        'New branch…',
      ])
        tester.getRect(_row(l)).top,
    ];
    expect(y, orderedEquals([...y]..sort()));
    expect(find.textContaining('in a worktree'), findsOneWidget);
    expect(
      find.descendant(of: _row('main'), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    d.dispose();
  });

  testWidgets('another worktree’s branch: not switched, its worktree '
      'offered, and opening it moves the chat there', (tester) async {
    final fake = _fake();
    final d = await _panel(tester, fake, _chat());
    await _open(tester, 'main');
    await tester.tap(_row('try-sqrly'));
    await tester.pumpAndSettle();
    expect(find.text('try-sqrly is in a worktree'), findsOneWidget);
    expect(fake.calls.whereType<SwitchBranchRequest>(), isEmpty);
    await tester.tap(find.text('Open its worktree'));
    await tester.pumpAndSettle();
    expect(find.text('Move to the worktree of try-sqrly?'), findsOneWidget);
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    final moved = fake.calls.whereType<MoveChatRequest>().single;
    expect((moved.folder, moved.worktree), (_try, false));
    d.dispose();
  });

  testWidgets('uncommitted changes: said plainly, with Show changes', (
    tester,
  ) async {
    var shown = 0;
    final fake = _fake(switched: [SwitchBranchResponse(changed: 2)]);
    final d = await _panel(tester, fake, _chat(), onChanges: () => shown++);
    await _open(tester, 'main');
    await tester.tap(_row('fix/login-redirect'));
    await tester.pumpAndSettle();
    expect(find.text('Uncommitted changes'), findsOneWidget);
    expect(
      find.textContaining('main has 2 files with uncommitted changes'),
      findsOneWidget,
    );
    await tester.tap(find.text('Show changes'));
    await tester.pumpAndSettle();
    expect(shown, 1);
    expect(
      fake.calls.whereType<SwitchBranchRequest>().single.withOthers,
      false,
    );
    d.dispose();
  });

  testWidgets('another chat in the folder: asked once, then switched with '
      'it', (tester) async {
    final fake = _fake(
      switched: [
        SwitchBranchResponse(others: ['Fix the login']),
        SwitchBranchResponse(switched: true),
      ],
    );
    final d = await _panel(tester, fake, _chat());
    await _open(tester, 'main');
    await tester.tap(_row('old-experiment'));
    await tester.pumpAndSettle();
    expect(find.text('Another chat works in this folder'), findsOneWidget);
    expect(
      find.textContaining('“Fix the login” is in this folder too'),
      findsOneWidget,
    );
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();
    final sent = fake.calls.whereType<SwitchBranchRequest>().toList();
    expect(
      [for (final s in sent) (s.branch, s.withOthers)],
      [('old-experiment', false), ('old-experiment', true)],
    );
    d.dispose();
  });

  testWidgets('a refusal (another chat mid-turn) shows as the daemon says it', (
    tester,
  ) async {
    final fake = _fake()
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'main',
        ),
        ListBranchesRequest() => _list(),
        SwitchBranchRequest() => throw ConnectException(
          Code.failedPrecondition,
          '“Fix the login” is working in this folder: switch the branch '
          'once it’s done',
        ),
        _ => null,
      };
    final d = await _panel(tester, fake, _chat());
    await _open(tester, 'main');
    await tester.tap(_row('old-experiment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('“Fix the login” is working'), findsOneWidget);
    d.dispose();
  });

  testWidgets('New branch… switches to a new branch from HEAD', (tester) async {
    final fake = _fake(switched: [SwitchBranchResponse(switched: true)]);
    final d = await _panel(tester, fake, _chat());
    await _open(tester, 'main');
    await tester.tap(_row('New branch…'));
    await tester.pumpAndSettle();
    expect(find.textContaining('From main'), findsOneWidget);
    await tester.enterText(find.byType(TextField), ' me/new-thing ');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    final sent = fake.calls.whereType<SwitchBranchRequest>().single;
    expect((sent.branch, sent.newBranch), ('me/new-thing', true));
    d.dispose();
  });

  testWidgets('mid-turn: the rows show, unavailable, under why', (
    tester,
  ) async {
    final fake = _fake();
    final d = await _panel(tester, fake, _chat(busy: true));
    await _open(tester, 'main');
    expect(find.textContaining('Once the agent is done'), findsOneWidget);
    await tester.tap(_row('old-experiment'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<SwitchBranchRequest>(), isEmpty);
    d.dispose();
  });

  testWidgets('in a worktree: the worktrees, the current one checked, no '
      'New branch…; another one moves the chat', (tester) async {
    final fake = _fake(inTry: true);
    final d = await _panel(tester, fake, _chat(inTry: true));
    await _open(tester, 'try-sqrly');
    expect(_row('New branch…'), findsNothing);
    expect(_row('fix/login-redirect'), findsNothing);
    expect(find.textContaining('the repository'), findsOneWidget);
    expect(find.textContaining('locked'), findsOneWidget);
    expect(
      find.descendant(
        of: _row('try-sqrly'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.tap(_row('main'));
    await tester.pumpAndSettle();
    expect(find.text('Move to the repository?'), findsOneWidget);
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<MoveChatRequest>().single.folder, _repo);
    d.dispose();
  });

  testWidgets('the Worktree row: New worktree…, a divider, then the other '
      'worktrees; each moves the chat', (tester) async {
    final fake = _fake();
    final d = await _panel(tester, fake, _chat());
    expect(find.text('Move to new worktree'), findsNothing);
    await _open(tester, 'None');
    final add = tester.getRect(_row('New worktree…'));
    expect(tester.getRect(_row('try-sqrly')).top, greaterThan(add.bottom));
    expect(_row('kept'), findsOneWidget);
    expect(_row('main'), findsNothing); // the chat's own folder
    await tester.tap(_row('New worktree…'));
    await tester.pumpAndSettle();
    expect(find.text('Move to a new worktree?'), findsOneWidget);
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    final moved = fake.calls.whereType<MoveChatRequest>().single;
    expect((moved.folder, moved.worktree), (_repo, true));

    await _open(tester, 'None');
    await tester.tap(_row('try-sqrly'));
    await tester.pumpAndSettle();
    expect(find.text('Move to the worktree of try-sqrly?'), findsOneWidget);
    d.dispose();
  });

  testWidgets('golden, the Worktree menu open, light', (tester) async {
    final d = await _panel(tester, _fake(), _chat(), tokens: Tokens.light);
    await _open(tester, 'None');
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/worktree_menu_light.png'),
    );
    d.dispose();
  });

  testWidgets('the Worktree row mid-turn: its value as it is, the rows '
      'unavailable under why', (tester) async {
    final fake = _fake();
    final d = await _panel(tester, fake, _chat(busy: true));
    final field = find.ancestor(
      of: find.text('None'),
      matching: find.byType(MenuField),
    );
    expect(
      find.descendant(of: field, matching: find.byType(Opacity)),
      findsNothing, // not faded
    );
    await _open(tester, 'None');
    expect(find.textContaining('Once the agent is done'), findsOneWidget);
    await tester.tap(_row('New worktree…'), warnIfMissed: false);
    await tester.tap(_row('try-sqrly'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Move to a new worktree?'), findsNothing);
    expect(fake.calls.whereType<MoveChatRequest>(), isEmpty);
    d.dispose();
  });

  testWidgets('the widget’s values end at one right edge, menus too', (
    tester,
  ) async {
    final d = await _panel(tester, _fake(), _chat(), tokens: Tokens.light);
    final environment = find.widgetWithText(PanelWidget, 'Environment');
    // Inside the widget's border and right inset, where text values end.
    final edge = tester.getRect(environment).right - 11;
    final carets = find.descendant(
      of: find.descendant(of: environment, matching: find.byType(FlushMenus)),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.keyboard_arrow_down ||
                w.icon == Icons.expand_more),
      ),
    );
    expect(carets, findsNWidgets(3)); // Folder, Branch and Worktree
    for (final c in carets.evaluate()) {
      // The ▾'s glyph ends 3.5 px inside its box.
      final glyph = tester.getRect(find.byWidget(c.widget)).right - 3.5;
      expect(glyph, closeTo(edge, 2));
    }
    d.dispose();
  });

  testWidgets('a new chat’s folder menu offers the worktrees', (tester) async {
    final fake = _fake();
    final d = await fake.connect(tester);
    final chat = ChatState('c', _repo)..load(GetChatResponse());
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: NewChatBar(chat: chat, daemon: d),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('cappy'));
    await tester.pumpAndSettle();
    expect(find.text('Worktrees of cappy'), findsOneWidget);
    await tester.tap(_row('try-sqrly'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<MoveChatRequest>().single.folder, _try);
    d.dispose();
  });
}
