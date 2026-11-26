import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

// No action from a key or the menu bar runs over a dialog that asks
// something (docs/design.md's Dialogs): the palette, New chat, Archive and
// a chat's number do nothing while Delete's confirm is open, and the
// dialog keeps its own keys. On Linux the keys come through the app's
// Shortcuts alone, as there's no menu bar.
//
// The key tests guard the app's keys as now bound, above the Navigator,
// so a dialog's focus reaches them: they don't show the bug, and passed
// before, when a dialog's keys never reached the app's Shortcuts. On the
// Mac the bug came by the menu bar, which runs a key Flutter leaves
// unhandled as its item; the harness has no menu bar to do that, so the
// menu bar's own test, which runs its items, is the one that shows it.

/// The Delete dialog's title for chat c.
const _title = 'Delete “Tidy the note list”?';

/// The app on chats c and d, c shown, its Delete dialog open; Linux's
/// window and conventions on Linux.
Future<(FakeDaemon, Daemon)> _deleting(WidgetTester tester) async {
  if (defaultTargetPlatform == TargetPlatform.linux) {
    native
      ..window = const LinuxWindow()
      ..conventions = linuxConventions;
  }
  showDetails.value = false;
  final fake =
      FakeDaemon([
          chat('c', 'claude', 'Tidy the note list'),
          chat('d', 'codex', 'Fix the cart', age: 5),
        ])
        ..answer = (input) => input is PlanDeleteChatRequest
            ? PlanDeleteChatResponse(deletesHistory: true)
            : null;
  final d = await openApp(tester, fake, size: const Size(1200, 700));
  unawaited(
    showDeleteChat(tester.element(find.byType(ChatView)), d.chats['c']!, d),
  );
  await tester.pumpAndSettle();
  expect(find.text(_title), findsOne);
  return (fake, d);
}

/// The menu bar's item [label] in its menu [menu], submenus flattened.
PlatformMenuItem _item(WidgetTester tester, String menu, String label) {
  final m = tester
      .widget<PlatformMenuBar>(find.byType(PlatformMenuBar))
      .menus
      .whereType<PlatformMenu>()
      .firstWhere((m) => m.label == menu);
  Iterable<PlatformMenuItem> items(PlatformMenuItem m) => switch (m) {
    PlatformMenuItemGroup(:final members) => members.expand(items),
    PlatformMenu(:final menus) => [m, ...menus.expand(items)],
    _ => [m],
  };
  return m.menus.expand(items).firstWhere((i) => i.label == label);
}

/// Only Delete's dialog is open, the chat shown is still c, and nothing
/// was asked of the daemon past what opening the dialog asked.
void _onlyDelete(Daemon d, FakeDaemon fake, int calls) {
  expect(find.text(_title), findsOne);
  expect(find.byType(Dialog), findsOne);
  expect(find.byType(Palette), findsNothing);
  expect(d.selectedId, 'c');
  expect(fake.calls.skip(calls).whereType<ListAgentsRequest>(), isEmpty);
  expect(fake.calls.skip(calls).whereType<ListTerminalsRequest>(), isEmpty);
  expect(fake.calls.skip(calls).whereType<ArchiveChatRequest>(), isEmpty);
}

void main() {
  setUpAll(loadFonts);

  testWidgets("the app's keys do nothing over Delete's dialog, and Enter "
      'presses its Cancel', (tester) async {
    final (fake, d) = await _deleting(tester);
    final calls = fake.calls.length;
    await press(tester, LogicalKeyboardKey.keyK, cmd: true); // the palette
    _onlyDelete(d, fake, calls);
    await press(tester, LogicalKeyboardKey.keyN, cmd: true); // New chat
    _onlyDelete(d, fake, calls);
    await press(tester, LogicalKeyboardKey.digit2, cmd: true); // chat d
    _onlyDelete(d, fake, calls);

    expect(focusedButton(tester), 'Cancel'); // Enter never deletes
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(fake.calls.whereType<DeleteChatRequest>(), isEmpty);

    // With the dialog gone the keys work again.
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(find.byType(Palette), findsOne);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets("over a confirm the app's keys do nothing; Esc closes it and "
      'Enter confirms', (tester) async {
    final (fake, d) = await _deleting(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final calls = fake.calls.length;
    Future<bool> ask() => confirm(
      tester.element(find.byType(ChatView)),
      'Archive the chat?',
      'Archiving ends its terminals.',
      'Archive',
    );

    var answer = ask();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    await press(tester, LogicalKeyboardKey.keyN, cmd: true);
    expect(find.text('Archive the chat?'), findsOne);
    expect(find.byType(Dialog), findsOne);
    expect(fake.calls.skip(calls).whereType<ListAgentsRequest>(), isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Archive the chat?'), findsNothing);
    expect(await answer, isFalse);

    answer = ask();
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(find.byType(Palette), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Archive the chat?'), findsNothing);
    expect(await answer, isTrue);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets("the menu bar's items do nothing over Delete's dialog: the "
      'palette, New chat, Archive, a chat by number, Next Chat', (
    tester,
  ) async {
    final (fake, d) = await _deleting(tester);
    final calls = fake.calls.length;
    for (final (menu, label) in [
      ('View', 'Command Palette…'),
      ('File', 'New Chat…'),
      ('Chat', 'Archive'),
      ('View', 'Chat 2 in the Sidebar'),
      ('View', 'Next Chat'),
    ]) {
      _item(tester, menu, label).onSelected!();
      await tester.pumpAndSettle();
      _onlyDelete(d, fake, calls);
    }
    // The dialog's own Delete still works.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<DeleteChatRequest>(), hasLength(1));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Clean Up… opens its dialog only if nothing opened while it '
      'read the pull request: run twice, one dialog; ⌘K meanwhile, none', (
    tester,
  ) async {
    showDetails.value = false;
    final link = GitHubLink(
      host: 'github.com',
      repo: fixtureRepo,
      number: 537,
      id: 'PR_537',
      pull: true,
    );
    final wt = Worktree(
      repo: '/Users/me/nushi',
      path: '/Users/me/nushi/.worktrees/tidy',
      branch: 'tidy',
      base: 'main',
    );
    final c = chat('c', 'claude', 'Tidy the note list')
      ..worktree = wt
      ..folder = wt.path
      ..pull = link
      ..pulls.add(link);
    var held = Completer<GetGitHubPullResponse>();
    final fake = FakeDaemon([c])
      ..answer = (input) => switch (input) {
        GetGitHubPullRequest() => held.future,
        GetCleanUpRequest() => GetCleanUpResponse(
          worktree: wt,
          state: WorktreeState(commits: 1),
        ),
        _ => null,
      };
    final d = await openApp(tester, fake, size: const Size(1200, 700));
    final cleanUp = _item(tester, 'Chat', 'Clean Up…');
    final title = find.text('Clean up after #537');

    cleanUp.onSelected!();
    cleanUp.onSelected!();
    await tester.pump();
    held.complete(GetGitHubPullResponse(pull: fixturePull()));
    await tester.pumpAndSettle();
    expect(title, findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    held = Completer();
    cleanUp.onSelected!();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(find.byType(Palette), findsOne);
    held.complete(GetGitHubPullResponse(pull: fixturePull()));
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(find.byType(Palette), findsOne);
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(find.byType(Palette), findsNothing);
    await closeView(tester, d);
  }, variant: onMac);
}
