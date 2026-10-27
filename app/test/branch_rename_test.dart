import 'dart:io';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/branch_rename.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

final String _repo = '${Platform.environment['HOME']}/code/nushi';
const _long = 'nushi/bump-go-to-1-27-3-and-fix-the-flaky-tests';

/// A worktree chat with a message, its folder on [branch].
ChatState _chat({String branch = 'nushi/brave-otter', bool busy = false}) =>
    ChatState('c', '$_repo/.worktrees/brave-otter')
      ..worktree = Worktree(
        repo: _repo,
        path: '$_repo/.worktrees/brave-otter',
        branch: branch,
        base: 'main',
      )
      ..load(
        GetChatResponse(
          items: [Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE)],
          status: ChatStatus(busy: busy),
        ),
      );

/// A daemon whose folder is on [branch], answering RenameBranch with
/// [rename] (a thrown error fails it).
FakeDaemon _fake(String branch, {Object? Function()? rename}) =>
    FakeDaemon([Chat(id: 'c', agent: 'claude', folder: _repo)])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: branch,
        ),
        RenameBranchRequest() => rename?.call(),
        _ => null,
      };

/// The details panel, [width] wide, beside nothing.
Future<Daemon> _panel(
  WidgetTester tester,
  FakeDaemon fake,
  ChatState chat, {
  Tokens tokens = Tokens.dark,
  double width = DetailsPanel.width,
}) async {
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: NushiTheme(tokens).toThemeData(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 520,
            child: DetailsPanel(chat: chat, daemon: d, onChanges: () {}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return d;
}

Finder get _environment => find.widgetWithText(PanelCard, 'Environment');
Finder get _pencil => find.byTooltip('Rename branch…');

void main() {
  setUpAll(loadFonts);
  setUp(() => collapsedCards.value = {});

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    // At the panel's usual width and its widest: the pencil right after the
    // name, a long name cut before it.
    for (final width in [DetailsPanel.width, 480.0]) {
      testWidgets('golden, the Environment card ${width.round()} wide, $name', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 2
          ..physicalSize = Size(width, 520) * 2;
        addTearDown(tester.view.reset);
        final d = await _panel(
          tester,
          _fake(_long),
          _chat(branch: _long),
          tokens: tokens,
          width: width,
        );
        final card = tester.getRect(_environment);
        final pencil = tester.getRect(find.byIcon(Icons.edit_outlined));
        expect(pencil.right, lessThanOrEqualTo(card.right));
        expect(
          pencil.left,
          greaterThan(tester.getRect(find.textContaining('nushi/bump')).right),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          _environment,
          matchesGoldenFile('goldens/branch_row_${width.round()}_$name.png'),
        );
        d.dispose();
      });
    }

    testWidgets('golden, the Rename branch dialog refused, $name', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(720, 420) * 2;
      addTearDown(tester.view.reset);
      final fake = _fake(
        'nushi/bump-go-1-27-3',
        rename: () => throw ConnectException(
          Code.failedPrecondition,
          'It’s on the remote: rename it there too, or keep it',
        ),
      );
      final d = await _panel(
        tester,
        fake,
        _chat(branch: 'nushi/bump-go-1-27-3'),
        tokens: tokens,
      );
      await tester.tap(_pencil);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nushi/go-1-27-3');
      await tester.pump();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.byType(RenameBranchDialog), findsOneWidget);
      await expectLater(
        find.byType(AlertDialog),
        matchesGoldenFile('goldens/branch_rename_$name.png'),
      );
      d.dispose();
    });
  }

  testWidgets('Rename branch… sends the new name, and the panel reads the '
      'folder again', (tester) async {
    final fake = _fake('nushi/brave-otter');
    final d = await _panel(tester, fake, _chat());
    int reads() => fake.calls.whereType<GetFolderStatusRequest>().length;
    final before = reads();
    await tester.tap(_pencil);
    await tester.pumpAndSettle();

    // The current name, picked whole; Rename waits for another.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'nushi/brave-otter');
    expect(field.controller!.selection.end, 'nushi/brave-otter'.length);
    expect(find.textContaining('.worktrees/brave-otter'), findsOneWidget);
    await tester.tap(find.text('Rename'));
    await tester.pump();
    expect(fake.calls.whereType<RenameBranchRequest>(), isEmpty);

    await tester.enterText(find.byType(TextField), ' me/login-fix ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final sent = fake.calls.whereType<RenameBranchRequest>().single;
    expect((sent.chatId, sent.branch), ('c', 'me/login-fix'));
    expect(find.byType(RenameBranchDialog), findsNothing);
    expect(reads(), greaterThan(before));
    d.dispose();
  });

  testWidgets('a refusal stays in the dialog, and typing clears it', (
    tester,
  ) async {
    final fake = _fake(
      'nushi/brave-otter',
      rename: () =>
          throw ConnectException(Code.invalidArgument, 'not a name git takes'),
    );
    final d = await _panel(tester, fake, _chat());
    await tester.tap(_pencil);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a b');
    await tester.pump();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.text('not a name git takes'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a-b');
    await tester.pump();
    expect(find.text('not a name git takes'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(RenameBranchDialog), findsNothing);
    d.dispose();
  });

  testWidgets('no renaming during a turn', (tester) async {
    final d = await _panel(
      tester,
      _fake('nushi/brave-otter'),
      _chat(busy: true),
    );
    await tester.tap(_pencil, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(RenameBranchDialog), findsNothing);
    d.dispose();
  });

  testWidgets('the transcript says Nushi renamed the branch, quietly', (
    tester,
  ) async {
    final d = await _fake('nushi/x').connect(tester);
    final note = Item(
      id: 'n',
      kind: ItemKind.ITEM_KIND_NOTICE,
      status: 'branch_renamed',
      text: 'Branch renamed to nushi/bump-go-1-27-3',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: ItemView(note, _chat(), d, live: false, still: true),
        ),
      ),
    );
    expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.account_tree_outlined));
    expect(icon.color, Tokens.dark.textMuted);
    d.dispose();
  });
}
