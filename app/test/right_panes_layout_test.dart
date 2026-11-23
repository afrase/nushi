import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/background_commands.dart';
import 'package:nushi/beside_fit.dart';
import 'package:nushi/browser_bar.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_panes.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/controls.dart' show MenuField;
import 'package:nushi/details_panel.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_bar.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/files_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pane_tabs.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';

import 'browser_fixture.dart' show browserFakes;
import 'fake_daemon.dart' show loadFonts;
import 'github_fixture.dart' show pullCommits, pullOf;
import 'harness.dart';
import 'header_checks.dart';
import 'right_panes_fixture.dart';

// Where a chat's parts are with panes open (ADR 0123): the transcript, the
// details rail, then every pane, each the pane's full height with its top
// row level with the chat's header, which spans the transcript and the
// rail; the terminal under those two. Narrower, the rail tucks away;
// narrower still, the panes lie over the transcript, under the header.

/// Linux too: the same layout (ADR 0123).
/// Whether a row of the layout's matrix runs on Linux too: at 1700 and
/// 720, the sidebar shown and hidden, the terminal shut (ADR 0123).
bool _onLinux(double width, {required bool terminal}) =>
    !terminal && (width == 1700 || width == 720);

/// A kind of pane, how to open it, what it opens as (its specs, left to
/// right) and the widget each is.
typedef _Kind = ({
  String name,
  PanesOpen open,
  List<PaneSpec> specs,
  List<Type> types,
});

PanesOpen _open({
  bool side = false,
  bool files = false,
  bool subagent = false,
  bool command = false,
  int previews = 0,
  int browser = 0,
}) => (
  side: side,
  files: files,
  subagent: subagent,
  command: command,
  previews: previews,
  browser: browser,
);

final List<_Kind> _kinds = [
  (
    name: 'side',
    open: _open(side: true),
    specs: [ChatPanes.side],
    types: [SideChat],
  ),
  (
    name: 'files',
    open: _open(files: true),
    specs: [ChatPanes.files],
    types: [FilesPane],
  ),
  (
    name: 'subagent',
    open: _open(subagent: true),
    specs: [ChatPanes.subagent],
    types: [SubagentPane],
  ),
  (
    name: 'command',
    open: _open(command: true),
    specs: [ChatPanes.subagent],
    types: [BackgroundCommandPane],
  ),
  (
    name: '3 files',
    open: _open(previews: 3),
    specs: [ChatPanes.files],
    types: [FilesPane],
  ),
  (
    name: '2 browser tabs',
    open: _open(browser: 2),
    specs: [ChatPanes.browser],
    types: [BrowserPane],
  ),
  (
    name: 'files + browser',
    open: _open(files: true, browser: 1),
    specs: [ChatPanes.files, ChatPanes.browser],
    types: [FilesPane, BrowserPane],
  ),
];

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

Finder _transcript() => find.byWidgetPredicate(
  (w) => w is Transcript && w.items == null && w.chat.id == 'c',
);

/// The pane's own top row: its first [PaneHeader].
Finder _topRow(Finder pane) =>
    find.descendant(of: pane, matching: find.byType(PaneHeader)).first;

void main() {
  setUpAll(loadFonts);

  for (final width in [1900.0, 1700.0, 720.0]) {
    for (final sidebar in [true, false]) {
      for (final kind in _kinds) {
        for (final terminal in [false, true]) {
          final where = sidebar ? 'the sidebar shown' : 'the sidebar hidden';
          final term = terminal ? ', the terminal open' : '';
          testWidgets(
            '${kind.name} at ${width.toInt()}, $where$term',
            (tester) async {
              browserFakes();
              final (d, _) = await panesApp(
                tester,
                width: width,
                sidebar: sidebar,
                terminal: terminal,
                open: kind.open,
              );
              expect(tester.takeException(), isNull);
              expectTextInside(tester, width);
              final area = _rect(tester, find.byType(Pane));
              final fit = chatFit(
                room: area.width,
                panes: kind.specs,
                saved: const {},
                wantRail: true,
              );
              final panes = [
                for (final t in kind.types) _rect(tester, find.byType(t)),
              ];
              final header = _rect(tester, find.byType(ChatHeader));
              final menu = _rect(tester, find.byTooltip('Chat menu'));
              final transcript = _rect(tester, _transcript());
              final bottom = terminal
                  ? _rect(tester, find.byType(TerminalPanel)).top
                  : area.bottom;
              // Left to right, touching, the last at the window's margin.
              for (var i = 1; i < panes.length; i++) {
                expect(panes[i].left, panes[i - 1].right);
              }
              expect(panes.last.right, width - NushiTheme.windowPad);
              expect(header.top, area.top);
              expect(header.left, area.left);
              expect(header.height, PaneHeader.height);
              if (!sidebar) {
                // The sidebar's button past the Mac's lights or at Linux's
                // inset, and the title past the buttons.
                // A chat with no colour: its title at the header's start.
                expectHiddenHeaderStart(
                  tester,
                  title: 'Fix the login redirect',
                  colored: false,
                );
              }
              final first = panes.first;
              // Beside the transcript or over it, the panes run the pane's
              // full height, the terminal or not, each top row level with
              // the chat's header, which spans the transcript and the rail
              // and never the panes.
              for (final p in panes) {
                expect(p.top, area.top);
                expect(p.bottom, area.bottom);
              }
              for (final t in kind.types) {
                final row = _rect(tester, _topRow(find.byType(t)));
                expect(row.top, header.top);
                expect(row.bottom, header.bottom);
              }
              expect(header.width, fit.left);
              expect(menu.right, header.right - ChatHeader.end);
              if (!fit.over) {
                expect(first.left, area.left + fit.left);
                expect(header.right, first.left);
                expect(menu.right, first.left - ChatHeader.end);
                if (terminal) {
                  final term = _rect(tester, find.byType(TerminalPanel));
                  expect(term.left, area.left);
                  expect(term.right, first.left);
                }
                if (fit.rail) {
                  final rail = _rect(tester, find.byType(DetailsPanel));
                  expect(transcript.right, rail.left);
                  expect(rail.right, first.left);
                  expect(rail.top, header.bottom);
                  expect(rail.bottom, bottom);
                } else {
                  expect(find.byType(DetailsPanel), findsNothing);
                  expect(transcript.right, first.left);
                }
              } else {
                // Over the transcript, which keeps its least under them, the
                // header and the terminal as wide; the panes cover its right.
                expect(header.right, greaterThan(first.left));
                expect(transcript.left, area.left);
                expect(transcript.right, header.right);
                expect(find.byType(DetailsPanel), findsNothing);
                if (terminal) {
                  final term = _rect(tester, find.byType(TerminalPanel));
                  expect(term.left, area.left);
                  expect(term.right, header.right);
                }
              }
              // Each pane's buttons in its own top row, none of them in the
              // chat's header; one top row each, nothing under it a header.
              for (final t in kind.types) {
                final pane = find.byType(t);
                final row = _rect(tester, _topRow(pane));
                expect(row.top, _rect(tester, pane).top);
                final heads = find.descendant(
                  of: pane,
                  matching: find.byType(PaneHeader),
                );
                expect(heads, findsOneWidget);
                final close = find.descendant(
                  of: pane,
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is Tooltip &&
                        {'Close', 'End the side chat'}.contains(w.message),
                  ),
                );
                expect(close, findsAtLeast(1));
                for (final e in close.evaluate()) {
                  final r = tester.getRect(find.byWidget(e.widget));
                  expect(row.contains(r.center), isTrue, reason: '$t');
                }
              }
              expect(
                find.descendant(
                  of: find.byType(ChatHeader),
                  matching: find.byTooltip('Close'),
                ),
                findsNothing,
              );
              // The tabs in the top row; the address, or the Files pane's bar
              // with the path, under it.
              if (kind.name == '3 files' || kind.types.contains(BrowserPane)) {
                final pane = find.byType(kind.types.last);
                final row = _rect(tester, _topRow(pane));
                final tabs = find.descendant(
                  of: pane,
                  matching: find.byType(PaneTabs),
                );
                // Each kind here has two tabs or more, or a browser's.
                expect(tabs, findsOneWidget);
                final plus = find.descendant(
                  of: pane,
                  matching: find.byType(NewBrowserTab),
                );
                // A browser squeezed under a few chips' room keeps its tabs
                // and buttons, and leaves out its +.
                if (kind.types.last == BrowserPane &&
                    _rect(tester, pane).width >= 200) {
                  expect(plus, findsOneWidget);
                }
                for (final f in [tabs, if (plus.evaluate().isNotEmpty) plus]) {
                  final r = _rect(tester, f);
                  expect(r.top, greaterThanOrEqualTo(row.top), reason: '$f');
                  expect(r.bottom, lessThanOrEqualTo(row.bottom), reason: '$f');
                }
                final below = kind.types.last == BrowserPane
                    ? find.byType(BrowserBar)
                    : find.byType(FilesBar);
                expect(_rect(tester, below).top, row.bottom);
              }
              await closeView(tester, d);
            },
            variant: _onLinux(width, terminal: terminal) ? macAndLinux : onMac,
          );
        }
      }
    }
  }

  /// The color at ([x], [y]) in logical points of [image], drawn at 1x.
  Color at(ui.Image image, ByteData bytes, double x, double y) {
    final i = (y.floor() * image.width + x.floor()) * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }

  for (final (name, brightness, tokens) in [
    ('dark', Brightness.dark, Tokens.dark),
    ('light', Brightness.light, Tokens.light),
  ]) {
    testWidgets("the header's line meets the pane's top row's, and the "
        "pane's edge runs the full height, $name", (tester) async {
      final (d, _) = await panesApp(
        tester,
        width: 1700,
        brightness: brightness,
        open: _open(files: true),
      );
      final files = _rect(tester, find.byType(FilesPane));
      final rail = _rect(tester, find.byType(DetailsPanel));
      final line = Color.alphaBlend(tokens.line, tokens.base);
      void isLine(Color c, String where) {
        expect(c.r, closeTo(line.r, 1.5 / 255), reason: where);
        expect(c.g, closeTo(line.g, 1.5 / 255), reason: where);
        expect(c.b, closeTo(line.b, 1.5 / 255), reason: where);
      }

      final element = find.byType(NushiApp).evaluate().single;
      await tester.runAsync(() async {
        final image = await captureImage(element);
        final bytes = (await image.toByteData())!;
        // The header's line runs on into the pane's, with no gap.
        const y = NushiTheme.windowPad + PaneHeader.height - 1;
        for (final x in [files.left - 30, files.left - 2, files.left + 2]) {
          isLine(at(image, bytes, x, y), 'the top line at $x');
        }
        isLine(at(image, bytes, files.left + 120, y), 'in the pane');
        // The pane's edge from the top to the bottom, the header's band
        // too; the rail's under the header.
        for (final dy in [20.0, 300.0, 880.0]) {
          isLine(at(image, bytes, files.left, dy), 'the edge at $dy');
        }
        isLine(at(image, bytes, rail.left, 300), "the rail's line");
        image.dispose();
      });
      await closeView(tester, d);
    }, variant: onMac);
  }

  testWidgets('a header 360 wide, with a long title and every chip, '
      'folds and keeps ⋯ at its end, and the title its least past the '
      'lights', (tester) async {
    browserFakes();
    // The subagent's pane dragged as wide as it goes beside the
    // transcript, which keeps its least: the header is 360 wide.
    final width = windowFor(928, sidebar: false);
    final (d, fake) = await panesApp(
      tester,
      width: width,
      open: _open(subagent: true),
      widths: {'subagent': 928 - 360},
    );
    // Pull request #1240, linked below: GitHub's answer for its tab.
    fake.on(_pull1240);
    d.chats['c']!
      ..title = 'A title long enough to want all of the room it can get'
      ..jiraKey = 'NUSHI-1234'
      ..github = GitHubLink(
        host: 'github.com',
        repo: 'afrase/nushi',
        number: 1234,
      )
      ..linkPull(
        GitHubLink(
          host: 'github.com',
          repo: 'afrase/nushi',
          number: 1240,
          pull: true,
        ),
      );
    await tester.pumpAndSettle();
    final header = _rect(tester, find.byType(ChatHeader));
    expect(header.width, 360);
    expect(tester.takeException(), isNull);
    expectTextInside(tester, width);
    expect(
      _rect(tester, find.byTooltip('Chat menu')).right,
      header.right - ChatHeader.end,
    );
    // The sidebar is hidden, so the row starts past the lights: the
    // agent's mark and the tabs' field fold into ⋯ before the title gets
    // less than its least. The state's dot stays, and says whose it is.
    final c = d.chats['c']!;
    void titleKeepsItsLeast() {
      final title = find.descendant(
        of: find.byType(ChatHeader),
        matching: find.text(c.shownTitle),
      );
      expect(title, findsOneWidget);
      expect(
        _rect(tester, title).width,
        greaterThanOrEqualTo(headerTitleLeast),
      );
      expect(tester.takeException(), isNull);
    }

    titleKeepsItsLeast();
    final inHeader = find.byType(ChatHeader);
    expect(
      find.descendant(of: inHeader, matching: find.byType(AgentMark)),
      findsNothing,
    );
    expect(
      find.descendant(of: inHeader, matching: find.byType(MenuField)),
      findsNothing,
    );
    expect(find.byTooltip('Claude: idle'), findsOneWidget);
    // The Jira key and the GitHub chips folded into ⋯, each a row there,
    // and the tabs too.
    expect(find.text('NUSHI-1234'), findsNothing);
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    expect(find.text('Show NUSHI-1234 in Jira'), findsOneWidget);
    expect(find.text('Show #1234 from GitHub'), findsOneWidget);
    // The pull request's chip's row is the Pull request tab's, so only
    // that shows.
    expect(find.text('Changes'), findsOneWidget);
    expect(find.text('Show pull request #1240'), findsNothing);
    await tester.tap(find.text('Pull request'));
    await tester.pumpAndSettle();
    expect(c.tab.value, ChatTab.pull);
    // The widest tab's name changes nothing: the title keeps its least.
    titleKeepsItsLeast();
    // With the room back, they're chips in the row again, and not in ⋯.
    c
      ..tab.value = ChatTab.chat
      ..pane.value = null;
    await tester.pumpAndSettle();
    expect(find.text('NUSHI-1234'), findsOneWidget);
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Show NUSHI-1234 in Jira'), findsNothing);
    expect(find.text('Show #1234 from GitHub'), findsNothing);
    expect(find.text('Show pull request #1240'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a header narrowed by a pane folds only what doesn't fit: "
      "Claude's short name leaves the browser's button and the whole title "
      'room', (tester) async {
    // 660 wide: the row with OpenCode's name, the Files and browser
    // buttons and the title's least would need 668.
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1000, sidebar: true),
      sidebar: true,
      details: false,
      open: _open(subagent: true),
      widths: {'subagent': 340},
    );
    final header = _rect(tester, find.byType(ChatHeader));
    expect(header.width, 660);
    expect(find.byType(BrowserButton), findsOneWidget);
    final title = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(ChatHeader),
        matching: find.text('Fix the login redirect'),
      ),
    );
    expect(title.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a chat narrower than its panes' least widths narrows them, "
      'Files first, none past its left edge', (tester) async {
    // 732 for the chat: the side chat, Files and the browser need 1100.
    browserFakes();
    final (d, _) = await panesApp(
      tester,
      width: windowFor(732, sidebar: true),
      sidebar: true,
      open: _open(side: true, files: true, previews: 1, browser: 1),
    );
    expect(tester.takeException(), isNull);
    final area = _rect(tester, find.byType(Pane));
    final panes = [
      for (final t in [SideChat, FilesPane, BrowserPane])
        _rect(tester, find.byType(t)),
    ];
    expect(panes.first.left, area.left);
    for (var i = 1; i < panes.length; i++) {
      expect(panes[i].left, closeTo(panes[i - 1].right, 0.01));
    }
    expect(panes.last.right, area.right);
    // Each to the least its rows hold (240, 200, 300: Files gives the
    // most), then all by the same share of that: 732 of 740.
    for (final (i, least) in [240.0, 200.0, 300.0].indexed) {
      expect(panes[i].width, closeTo(least * 732 / 740, 0.01));
    }
    // Inside Files, under its viewer's least, the tree has given all its
    // width to the viewer, and with none left it isn't there (ADR 0123).
    final files = panes[1].width;
    expect(find.byType(FilesTree), findsNothing);
    expect(_rect(tester, find.byType(FileView)).width, closeTo(files, 0.01));
    // Wider, they're back at their least or more.
    viewport(tester, Size(windowFor(1500, sidebar: true), 900));
    await tester.pumpAndSettle();
    expect(
      _rect(tester, find.byType(SideChat)).width,
      greaterThanOrEqualTo(300),
    );
    expect(tester.takeException(), isNull);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a notice takes a row under the chat header, as wide as it, '
      'a pane open beside the chat: the pane and its address row stay '
      'where they were, clear of it (ADR 0128)', (tester) async {
    browserFakes();
    final (d, _) = await panesApp(tester, width: 1700, open: _open(browser: 1));
    final pane = _rect(tester, find.byType(BrowserPane));
    final view = _rect(tester, find.byType(ChatView));
    d
      ..notice = 'Didn’t start Claude in site'
      ..listChanged();
    await tester.pumpAndSettle();
    final bar = _rect(
      tester,
      find
          .ancestor(
            of: find.textContaining('start Claude in site'),
            matching: find.byType(TopBar),
          )
          .first,
    );
    final header = _rect(tester, find.byType(ChatHeader));
    expect(bar.top, header.bottom);
    expect(bar.left, header.left);
    expect(bar.right, header.right);
    expect(_rect(tester, find.byType(BrowserPane)), pane);
    expect(bar.right, lessThanOrEqualTo(pane.left));
    // The transcript goes down by the row.
    expect(_rect(tester, find.byType(ChatView)).top, greaterThan(view.top));
    expect(
      _rect(tester, find.byType(ChatView)).top,
      greaterThanOrEqualTo(bar.bottom),
    );
    await closeView(tester, d);
  }, variant: macAndLinux);

  // The window with its panes, compared (macOS only; CI within
  // golden_tolerance.dart): the hairlines' seams, the tabs in the top row
  // and the rail's band, each way the panes are laid out, with two
  // browser tabs.
  final shots = <(String, double, bool, PanesOpen, String)>[
    ('beside', 1700, false, _open(browser: 2), 'rail'),
    // Files with a file, and the browser: 1740 of the chat's room beside
    // the transcript, 2060 with the rail.
    (
      'tucked',
      1900,
      false,
      _open(files: true, previews: 1, browser: 2),
      'tucked',
    ),
    // The side chat, Files and the browser want 2120 of the chat's room
    // and need 1460, each at its least: at 1700 Files narrows, and at 1100
    // they lie over the transcript; the sidebar hidden, as in every window
    // golden.
    (
      'narrowed',
      1700,
      false,
      _open(side: true, files: true, previews: 1, browser: 2),
      'tucked',
    ),
    (
      'over',
      1100,
      false,
      _open(side: true, files: true, previews: 1, browser: 2),
      'over',
    ),
    ('cover', 1700, false, _open(browser: 2), 'cover'),
    // 704 for the chat: the preview narrowed to 344 beside it.
    ('720', 720, false, _open(browser: 2), 'tucked'),
  ];
  for (final (name, width, sidebar, open, way) in shots) {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      testWidgets('the window, $name, ${brightness.name}', (tester) async {
        browserFakes();
        final (d, _) = await panesApp(
          tester,
          width: width,
          sidebar: sidebar,
          brightness: brightness,
          open: open,
        );
        if (way == 'cover') {
          await tester.tap(find.byTooltip('Expand'));
          await tester.pumpAndSettle();
        }
        FocusManager.instance.primaryFocus?.unfocus(); // no caret
        await tester.pumpAndSettle();
        // Laid out the way the name says.
        final area = _rect(tester, find.byType(Pane));
        final rail = find.byType(DetailsPanel);
        Rect header() => _rect(tester, find.byType(ChatHeader));
        switch (way) {
          case 'cover':
            // Over everything: no header, the browser the whole pane.
            expect(find.byType(ChatHeader), findsNothing);
            expect(_rect(tester, find.byType(BrowserPane)), area);
          case 'rail':
            expect(rail, findsOneWidget);
            expect(header().right, lessThan(area.right));
          case 'tucked':
            expect(rail, findsNothing);
            expect(header().right, lessThan(area.right));
          case 'over':
            // The chat at its least under the panes, its header too.
            expect(rail, findsNothing);
            expect(header().width, ChatView.leastBesideWide);
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile(
            'goldens/right_panes_${name}_${brightness.name}.png',
          ),
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
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
