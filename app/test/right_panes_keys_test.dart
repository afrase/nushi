import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/transcript_find.dart';

import 'browser_fixture.dart' show addressField, browserFakes;
import 'fake_daemon.dart' show FakeDaemon, loadFonts;
import 'github_fixture.dart' show pullCommits, pullOf;
import 'harness.dart';
import 'right_panes_fixture.dart';

// The keys, the focus, the expanded browser tab and the terminal with the
// panes right of the details rail (ADR 0123).

PanesOpen _open({
  bool side = false,
  bool files = false,
  bool subagent = false,
  int previews = 0,
  int browser = 0,
}) => (
  side: side,
  files: files,
  subagent: subagent,
  command: false,
  previews: previews,
  browser: browser,
);

final Finder _rail = find.byType(DetailsPanel);

bool get _linux => defaultTargetPlatform == TargetPlatform.linux;

/// ⌃`, the terminal's key on both.
Future<void> _terminalKey(WidgetTester tester) =>
    press(tester, LogicalKeyboardKey.backquote, ctrl: true);

/// The palette, [query] typed, its first row run.
Future<void> _palette(WidgetTester tester, String query) async {
  await press(tester, LogicalKeyboardKey.keyK, cmd: true);
  await tester.enterText(
    find.descendant(of: find.byType(Palette), matching: find.byType(TextField)),
    query,
  );
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

Rect _r(WidgetTester tester, Finder f) => tester.getRect(f);

void main() {
  setUpAll(loadFonts);

  testWidgets('Hide details from the palette while tucked: only the choice '
      'changes, and nothing moves', (tester) async {
    final (d, fake) = await panesApp(
      tester,
      width: windowFor(1100, sidebar: false),
      open: _open(previews: 1),
    );
    // Pull request #1240, linked below: GitHub's answer for its tab.
    fake.on(_pull1240);
    expect(_rail, findsNothing);
    final preview = _r(tester, find.byType(FileView));
    final header = _r(tester, find.byType(ChatHeader));
    await _palette(tester, 'hide details');
    expect(showDetails.value, isFalse);
    expect(_r(tester, find.byType(FileView)), preview);
    expect(_r(tester, find.byType(ChatHeader)), header);
    await _palette(tester, 'show details');
    expect(showDetails.value, isTrue);
    expect(_rail, findsNothing);
    // On Changes and on Pull request there's no details to show or hide:
    // the chat has a linked pull request, so that tab is there.
    final c = d.chats['c']!
      ..linkPull(
        GitHubLink(
          host: 'github.com',
          repo: 'afrase/nushi',
          number: 1240,
          pull: true,
        ),
      );
    for (final tab in [ChatTab.changes, ChatTab.pull]) {
      c.tab.value = tab;
      await tester.pumpAndSettle();
      expect(c.tab.value, tab);
      await _palette(tester, 'hide details');
      expect(showDetails.value, isTrue, reason: '$tab');
      // Nothing matched, so the palette is still open: closed, the next
      // tab's opens on that tab.
      expect(find.text('Nothing matches'), findsOneWidget, reason: '$tab');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Palette), findsNothing);
    }
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('⇧⌘E: Files opens right of the rail, its button lit, the '
      "header's buttons left by its width", (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1600, sidebar: false),
    );
    final menu = _r(tester, find.byTooltip('Chat menu'));
    final area = _r(tester, find.byType(Pane));
    await press(tester, LogicalKeyboardKey.keyE, cmd: true, shift: true);
    final files = _r(tester, find.byType(FilesPane));
    expect(files.left, _r(tester, _rail).right);
    expect(files.right, area.right);
    expect(_r(tester, find.byTooltip('Chat menu')).right, menu.right - 820);
    expect(
      tester
          .widget<IconTap>(
            find
                .descendant(
                  of: find.byType(FilesButton),
                  matching: find.byType(IconTap),
                )
                .first,
          )
          .lit,
      isTrue,
    );
    await press(tester, LogicalKeyboardKey.keyE, cmd: true, shift: true);
    expect(find.byType(FilesPane), findsNothing);
    expect(_r(tester, find.byTooltip('Chat menu')), menu);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets('⇧⌘B hides the side chat and shows it again, the rail coming '
      'back and tucking away for it', (tester) async {
    // 1150 for the chat: the rail beside the side chat needs 1184.
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1150, sidebar: false),
      open: _open(side: true),
    );
    expect(_rail, findsNothing);
    await press(tester, LogicalKeyboardKey.keyB, cmd: true, shift: true);
    expect(find.byType(SideChat), findsNothing);
    expect(_rail, findsOneWidget);
    await press(tester, LogicalKeyboardKey.keyB, cmd: true, shift: true);
    expect(find.byType(SideChat), findsOneWidget);
    expect(_rail, findsNothing);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets('New browser tab opens right of the rail; ⌘L is its '
      'address; closing its last tab brings the rail back', (tester) async {
    browserFakes();
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1600, sidebar: false),
    );
    await _palette(tester, 'new browser tab');
    final browser = _r(tester, find.byType(BrowserPane));
    expect(browser.left, _r(tester, _rail).right);
    await press(tester, LogicalKeyboardKey.keyL, cmd: true);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: addressField,
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    // A second tab, then ⌘W for each: the first closes one, the second
    // the last, and the rail has the pane's edge again.
    await _palette(tester, 'new browser tab');
    final c = d.chats['c']!;
    expect(c.browser.tabs.value, hasLength(2));
    await press(tester, LogicalKeyboardKey.keyW, cmd: true);
    expect(c.browser.tabs.value, hasLength(1));
    expect(_r(tester, find.byType(BrowserPane)), browser);
    await press(tester, LogicalKeyboardKey.keyW, cmd: true);
    expect(find.byType(BrowserPane), findsNothing);
    expect(_r(tester, _rail).right, _r(tester, find.byType(Pane)).right);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets('a browser tab that tucks the rail: ⌘R reloads its page, Back '
      'and Forward go through the chats and back to it as it was, and ⌘W '
      'on its last tab brings the rail back', (tester) async {
    final fakes = browserFakes();
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1100, sidebar: false),
    );
    // A place to go back to.
    d.select('d');
    await tester.pumpAndSettle();
    d.select('c');
    await tester.pumpAndSettle();
    final c = d.chats['c']!..openBrowserTab('http://localhost:3000');
    await tester.pumpAndSettle();
    expect(_rail, findsNothing);
    final browser = _r(tester, find.byType(BrowserPane));
    final header = _r(tester, find.byType(ChatHeader));
    // ⌘R (Control+R on Linux): the page again, nothing moved.
    await press(tester, LogicalKeyboardKey.keyR, cmd: true);
    expect(fakes.hosts.single.reloads, 1);
    expect(_r(tester, find.byType(BrowserPane)), browser);
    // Back and Forward: ⌘[ and ⌘] on the Mac, Alt+Left and Alt+Right on
    // Linux.
    Future<void> step({required bool back}) async {
      if (_linux) {
        await press(
          tester,
          back ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
          alt: true,
        );
      } else {
        await press(
          tester,
          back
              ? LogicalKeyboardKey.bracketLeft
              : LogicalKeyboardKey.bracketRight,
          cmd: true,
        );
      }
    }

    await step(back: true);
    expect(d.selectedId, 'd');
    expect(find.byType(BrowserPane), findsNothing);
    expect(_rail, findsOneWidget);
    await step(back: false);
    expect(d.selectedId, 'c');
    expect(_rail, findsNothing);
    expect(_r(tester, find.byType(BrowserPane)), browser);
    expect(_r(tester, find.byType(ChatHeader)), header);
    // ⌘W on its only tab: closed, the rail back.
    await press(tester, LogicalKeyboardKey.keyW, cmd: true);
    expect(c.browser.shown.value, isNull);
    expect(find.byType(BrowserPane), findsNothing);
    expect(_rail, findsOneWidget);
    expect(_r(tester, _rail).right, _r(tester, find.byType(Pane)).right);
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets('⌃`: the terminal under the transcript and the rail, beside '
      'the panes or under them, the panes as tall', (tester) async {
    // Wide, the preview beside the transcript; narrow, over it (the
    // transcript runs on under it): each way once.
    for (final (area, over) in [(1600.0, false), (700.0, true)]) {
      final (d, _) = await panesApp(
        tester,
        width: windowFor(area, sidebar: false),
        open: _open(previews: 1),
      );
      final preview = _r(tester, find.byType(FilesPane));
      final transcript = _r(
        tester,
        find.byWidgetPredicate(
          (w) => w is Transcript && w.items == null && w.chat.id == 'c',
        ),
      );
      expect(transcript.right > preview.left, over);
      await _terminalKey(tester);
      final terminal = _r(tester, find.byType(TerminalPanel));
      // Under the transcript, beside the panes or under them (ADR 0123);
      // the panes as tall as before.
      if (over) {
        expect(terminal.right, greaterThan(preview.left));
        expect(terminal.right, lessThan(_r(tester, find.byType(Pane)).right));
      } else {
        expect(terminal.right, preview.left);
      }
      expect(_r(tester, find.byType(FilesPane)), preview);
      await _terminalKey(tester);
      expect(find.byType(TerminalPanel), findsNothing);
      await closeView(tester, d);
    }
  }, variant: macAndLinux);

  testWidgets(r'⌘\: the sidebar hidden gives the rail its room back', (
    tester,
  ) async {
    // 1500 for the chat with the sidebar hidden: the rail beside the
    // Files pane; 1248 with it shown: tucked.
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1500, sidebar: false),
      sidebar: true,
      open: _open(previews: 1),
    );
    expect(_rail, findsNothing);
    await press(tester, LogicalKeyboardKey.backslash, cmd: true);
    expect(sidebarHidden.value, isTrue);
    expect(_rail, findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('⌘F: the find bar in the transcript, left of the rail', (
    tester,
  ) async {
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1600, sidebar: false),
      open: _open(previews: 1),
    );
    await press(tester, LogicalKeyboardKey.keyF, cmd: true);
    expect(
      _r(tester, find.byType(FindBar)).right,
      lessThanOrEqualTo(_r(tester, _rail).left),
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the focus in the rail as it tucks away goes to the chat's "
      'keys: ⌃` still works, and typing writes in the box', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1100, sidebar: false),
    );
    final inRail =
        find
              .descendant(of: _rail, matching: find.byType(Focus))
              .evaluate()
              .map((e) => (e.widget as Focus).focusNode)
              .firstWhere((n) => n != null && n.canRequestFocus)!
          ..requestFocus();
    await tester.pump();
    expect(inRail.hasFocus, isTrue);
    d.chats['c']!.openInFiles('PLAN.md');
    await tester.pumpAndSettle();
    expect(_rail, findsNothing);
    final keys = tester.widget<TerminalKeys>(find.byType(TerminalKeys)).focus;
    expect(keys.hasFocus, isTrue);
    await _terminalKey(tester);
    expect(terminalChats.value, contains('c'));
    await _terminalKey(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byType(Composer),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'q',
    );
    await closeView(tester, d);
  }, variant: onMac);

  for (final terminal in [false, true]) {
    testWidgets('Tab goes header, transcript, rail, then the panes left to '
        'right, never back from a pane into the header, the terminal last '
        '(${terminal ? 'open' : 'shut'})', (tester) async {
      browserFakes();
      final (d, _) = await panesApp(
        tester,
        width: windowFor(2200, sidebar: false),
        terminal: terminal,
        open: _open(files: true, previews: 1, browser: 1),
      );
      final regions = <(String, Finder)>[
        ('terminal', find.byType(TerminalPanel)),
        ('header', find.byType(ChatHeader)),
        ('rail', _rail),
        ('files', find.byType(FilesPane)),
        ('browser', find.byType(BrowserPane)),
        ('transcript', find.byType(Transcript)),
      ];
      String? region(FocusNode n) {
        final ctx = n.context;
        if (ctx == null) return null;
        for (final (name, f) in regions) {
          for (final e in f.evaluate()) {
            var hit = false;
            ctx.visitAncestorElements((a) => !(hit = a == e));
            if (hit || ctx == e) return name;
          }
        }
        return null;
      }

      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byType(Composer),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .unfocus();
      await tester.pump();
      final seen = <String>[];
      for (var i = 0; i < 120; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final n = FocusManager.instance.primaryFocus;
        final r = n == null ? null : region(n);
        if (r != null && (seen.isEmpty || seen.last != r)) seen.add(r);
      }
      // Once in a pane, never back to the header before the round's end;
      // the terminal, which keeps Tab for its shell, after all of them.
      const order = ['header', 'transcript', 'rail', 'files', 'browser'];
      for (var i = 1; i < seen.length; i++) {
        final a = order.indexOf(seen[i - 1]);
        final b = order.indexOf(seen[i]);
        final last = seen[i] == 'terminal';
        expect(
          last ? a == order.length - 1 : b > a || b == 0,
          isTrue,
          reason: '${seen[i - 1]} → ${seen[i]}',
        );
      }
      expect(seen, containsAll(['header', 'rail', 'files', 'browser']));
      if (terminal) expect(seen.last, 'terminal');
      await closeView(tester, d);
    }, variant: onMac);
  }

  group('Expand', () {
    Future<Daemon> expanded(
      WidgetTester tester, {
      double area = 1600,
      bool sidebar = false,
      bool terminal = true,
    }) async {
      browserFakes();
      final (d, _) = await panesApp(
        tester,
        width: windowFor(area, sidebar: sidebar),
        sidebar: sidebar,
        terminal: terminal,
        open: _open(browser: 1),
      );
      await tester.tap(find.byTooltip('Expand'));
      await tester.pumpAndSettle();
      return d;
    }

    testWidgets('covers the whole pane, header and terminal too, which take '
        'no pointer or focus; one page all along', (tester) async {
      final fakes = browserFakes();
      final (d, _) = await panesApp(
        tester,
        width: windowFor(1600, sidebar: false),
        terminal: true,
        open: _open(browser: 1),
      );
      final browser = _r(tester, find.byType(BrowserPane));
      final rail = _r(tester, _rail);
      await tester.tap(find.byTooltip('Expand'));
      await tester.pumpAndSettle();
      expect(
        _r(tester, find.byType(BrowserPane)),
        _r(tester, find.byType(Pane)),
      );
      for (final t in [ChatHeader, DetailsPanel, TerminalPanel, Composer]) {
        expect(find.byType(t), findsNothing, reason: '$t drawn');
        expect(find.byType(t, skipOffstage: false), findsOneWidget);
      }
      // Locked: no edge to drag.
      expect(
        tester
            .widget<Resizable>(
              find.ancestor(
                of: find.byType(BrowserPane),
                matching: find.byType(Resizable),
              ),
            )
            .locked,
        isTrue,
      );
      await tester.tap(find.byTooltip('Collapse'));
      await tester.pumpAndSettle();
      expect(_r(tester, find.byType(BrowserPane)), browser);
      expect(_r(tester, _rail), rail);
      expect(fakes.hosts, hasLength(1));
      expect(fakes.hosts.single.opened, hasLength(1));
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('the Files pane covers it too: header, rail, terminal and '
        'box hidden; ⌃` puts it back and shows the terminal', (tester) async {
      final (d, _) = await panesApp(
        tester,
        width: windowFor(1600, sidebar: false),
        terminal: true,
        open: _open(files: true, previews: 1),
      );
      final files = _r(tester, find.byType(FilesPane));
      Finder inFiles(String tip) => find.descendant(
        of: find.byType(FilesPane),
        matching: find.byTooltip(tip),
      );
      await tester.tap(inFiles('Expand'));
      await tester.pumpAndSettle();
      expect(_r(tester, find.byType(FilesPane)), _r(tester, find.byType(Pane)));
      for (final t in [ChatHeader, DetailsPanel, TerminalPanel, Composer]) {
        expect(find.byType(t), findsNothing, reason: '$t drawn');
        expect(find.byType(t, skipOffstage: false), findsOneWidget);
      }
      await _terminalKey(tester);
      expect(inFiles('Expand'), findsOneWidget);
      expect(_r(tester, find.byType(FilesPane)), files);
      expect(find.byType(TerminalPanel), findsOneWidget);
      await closeView(tester, d);
    }, variant: macAndLinux);

    testWidgets('tucked or over, collapsing puts each back', (tester) async {
      for (final area in [1100.0, 900.0]) {
        browserFakes();
        final (d, _) = await panesApp(
          tester,
          width: windowFor(area, sidebar: false),
          open: _open(browser: 1),
        );
        final browser = _r(tester, find.byType(BrowserPane));
        final header = _r(tester, find.byType(ChatHeader));
        await tester.tap(find.byTooltip('Expand'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Collapse'));
        await tester.pumpAndSettle();
        expect(_r(tester, find.byType(BrowserPane)), browser);
        expect(_r(tester, find.byType(ChatHeader)), header);
        expect(_rail, findsNothing);
        await closeView(tester, d);
      }
    }, variant: onMac);

    testWidgets('with the sidebar hidden, its tabs start past the traffic '
        'lights', (tester) async {
      for (final sidebar in [false, true]) {
        final d = await expanded(tester, sidebar: sidebar);
        final row = find
            .descendant(
              of: find.byType(BrowserPane),
              matching: find.byType(PaneHeader),
            )
            .first;
        final first = _r(
          tester,
          find.descendant(of: row, matching: find.byType(Text)).first,
        );
        expect(
          first.left,
          greaterThanOrEqualTo(
            sidebar
                ? _r(tester, find.byType(Pane)).left
                : NushiTheme.windowPad + hiddenHeaderStart,
          ),
        );
        await closeView(tester, d);
      }
    }, variant: macAndLinux);

    testWidgets('⌃` puts it back and shows the terminal, in one press', (
      tester,
    ) async {
      final d = await expanded(tester, terminal: false);
      await _terminalKey(tester);
      expect(find.byTooltip('Expand'), findsOneWidget);
      expect(find.byType(TerminalPanel), findsOneWidget);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('⌃` with the terminal open under it puts it back and shows '
        'that terminal, never closing it', (tester) async {
      final d = await expanded(tester);
      await _terminalKey(tester);
      expect(find.byTooltip('Expand'), findsOneWidget);
      expect(find.byType(TerminalPanel), findsOneWidget);
      expect(terminalChats.value, {'c'});
      // Shown, ⌃` hides it as ever.
      await _terminalKey(tester);
      expect(find.byType(TerminalPanel), findsNothing);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets("the palette's Show terminal puts it back and shows the "
        'terminal', (tester) async {
      final d = await expanded(tester, terminal: false);
      await _palette(tester, 'show terminal');
      expect(find.byTooltip('Expand'), findsOneWidget);
      expect(find.byType(TerminalPanel), findsOneWidget);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets("another chat's terminal opening leaves it expanded", (
      tester,
    ) async {
      final d = await expanded(tester);
      toggleTerminal('d');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Collapse'), findsOneWidget);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('Changes puts it back', (tester) async {
      final d = await expanded(tester);
      d.chats['c']!.tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      d.chats['c']!.tab.value = ChatTab.chat;
      await tester.pumpAndSettle();
      expect(find.byTooltip('Expand'), findsOneWidget);
      expect(find.byType(ChatHeader), findsOneWidget);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('the window narrowed under it: collapsed, the layout is the '
        "new width's", (tester) async {
      final d = await expanded(tester, terminal: false);
      viewport(tester, Size(windowFor(1100, sidebar: false), 900));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Collapse'));
      await tester.pumpAndSettle();
      expect(_rail, findsNothing);
      final browser = _r(tester, find.byType(BrowserPane));
      expect(browser.top, _r(tester, find.byType(Pane)).top);
      expect(_r(tester, find.byType(ChatHeader)).right, browser.left);
      await closeView(tester, d);
    }, variant: onMac);
  });

  group('the terminal', () {
    int resizes(FakeDaemon fake) =>
        fake.calls.whereType<ResizeTerminalRequest>().length;

    testWidgets('a pane opening or closing resizes its shell once; the '
        'details, shown or tucked, never', (tester) async {
      // 1520 for the chat: the rail beside Files (1500), not beside Files
      // and a subagent's pane (1764).
      final (d, fake) = await panesApp(
        tester,
        width: windowFor(1520, sidebar: false),
        terminal: true,
      );
      await tester.pump(const Duration(seconds: 1));
      var was = resizes(fake);
      filesChats.value = {'c'};
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(resizes(fake) - was, 1);
      was = resizes(fake);
      showDetails.value = false;
      await tester.pumpAndSettle();
      showDetails.value = true;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(resizes(fake) - was, 0);
      // A file opened in it: no pane opens, so no resize.
      was = resizes(fake);
      d.chats['c']!.openInFiles('PLAN.md');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(resizes(fake) - was, 0);
      // A subagent's pane too: the rail tucks away (1764 for the two).
      d.chats['c']!.pane.value = 'a';
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(_rail, findsNothing);
      expect(resizes(fake) - was, 1);
      was = resizes(fake);
      filesChats.value = {};
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(resizes(fake) - was, 1);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets("a pane's edge dragged beside it: at most one resize each "
        '100 ms, and the last', (tester) async {
      final (d, fake) = await panesApp(
        tester,
        width: windowFor(1600, sidebar: false),
        terminal: true,
        open: _open(previews: 1),
      );
      await tester.pump(const Duration(seconds: 1));
      final was = resizes(fake);
      final pane = _r(tester, find.byType(FileView));
      final drag = await tester.startGesture(
        Offset(pane.left + Resizable.edgeWidth / 2, pane.top + 300),
      );
      for (var i = 0; i < 30; i++) {
        await drag.moveBy(const Offset(-3, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pump(const Duration(seconds: 2));
      expect(resizes(fake) - was, inInclusiveRange(2, 7));
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('its edge goes as high as before, and moves no pane', (
      tester,
    ) async {
      final (d, _) = await panesApp(
        tester,
        width: windowFor(1600, sidebar: false),
        terminal: true,
        open: _open(previews: 1),
      );
      final area = _r(tester, find.byType(Pane));
      final preview = _r(tester, find.byType(FileView));
      final terminal = _r(tester, find.byType(TerminalPanel));
      final drag = await tester.startGesture(
        Offset(terminal.center.dx, terminal.top + 2),
      );
      await drag.moveBy(const Offset(0, -20));
      await tester.pump();
      await drag.moveBy(const Offset(0, -2000));
      await tester.pump();
      await drag.up();
      await tester.pump(const Duration(seconds: 2));
      expect(
        _r(tester, find.byType(TerminalPanel)).height,
        area.height - PaneHeader.height - 160,
      );
      expect(_r(tester, find.byType(FileView)), preview);
      await closeView(tester, d);
    }, variant: onMac);
  });

  testWidgets('a tucked rail draws nothing: no frames while idle', (
    tester,
  ) async {
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1100, sidebar: false),
      open: _open(previews: 1),
      // No command running: its time would tick each second.
      items: [
        for (final i in panesItems)
          if (i.id != 'cmd') i,
      ],
    );
    await tester.pump(const Duration(seconds: 2));
    FocusManager.instance.primaryFocus?.unfocus(); // no caret blinking
    await tester.pump(const Duration(seconds: 1));
    expect(_rail, findsNothing);
    expect(
      TickerMode.valuesOf(
        tester.element(find.byType(DetailsPanel, skipOffstage: false)),
      ).enabled,
      isFalse,
    );
    var frames = 0;
    var counting = true;
    tester.binding.addPersistentFrameCallback((_) {
      if (counting) frames++;
    });
    const vsync = Duration(microseconds: 16667);
    for (var t = Duration.zero; t < const Duration(seconds: 12); t += vsync) {
      await tester.pump(vsync);
    }
    counting = false;
    expect(frames, 0);
    expect(find.byType(FileView), findsOneWidget);
    // The chat holds what it was given: no command running.
    expect(find.text('npm run dev', skipOffstage: false), findsNothing);
    await closeView(tester, d);
  }, variant: onMac);
}

/// GitHub's answers for pull request #1240, which a test links its chat to.
Object? _pull1240(Object input) => switch (input) {
  GetGitHubPullRequest() => GetGitHubPullResponse(
    pull: pullOf(
      GitHubLink(
        host: 'github.com',
        repo: 'afrase/nushi',
        number: 1240,
        id: 'PR_1240',
        pull: true,
      ),
    ),
  ),
  GetGitHubCommitsRequest() => pullCommits(),
  _ => null,
};
