import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/inline_edit.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_group_header.dart';
import 'package:nushi/sidebar_row.dart';
import 'package:nushi/sidebar_sections.dart';
import 'package:nushi/terminal_tabs.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';
import 'harness.dart';

// The app with every name that's edited in place (`InlineEdit`) on show:
// a chat in the sidebar and its header, a terminal tab, a sidebar
// section, and the new chat dialog's branch for a Jira issue; and how
// each edit starts. For `inline_edit_test.dart` and its renders.

/// The open chat's title.
const renameTitle = 'Plant the spring beds';

/// The terminal's name.
const renameTerminal = 'Seed tray';

/// The section's name.
const renameSection = 'Greenhouse';

/// The issue's key, which its branch starts with.
const renameIssue = 'BED-7';

const _site = 'garden.atlassian.net';

/// One Jira site with one issue, for the new chat dialog.
Object? _jira(Object input) => switch (input) {
  ListJiraSitesRequest() => ListJiraSitesResponse(
    sites: [JiraSite(id: _site, url: 'https://$_site')],
  ),
  FindJiraIssuesRequest() => FindJiraIssuesResponse(
    issues: [
      FoundJiraIssue(
        site: _site,
        issue: JiraIssue(
          key: renameIssue,
          summary: 'Mulch the herb beds',
          status: 'To Do',
          statusCategory: 'new',
        ),
      ),
    ],
  ),
  _ => null,
};

/// The app on chat `c` ([renameTitle]), with its terminal and a section
/// holding another chat, 1700 by 900 at [ratio] in [brightness].
Future<Daemon> renameApp(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  double ratio = 1,
}) async {
  showDetails.value = false;
  lastJiraSite.value = _site;
  final fake = FakeDaemon([
    chat('c', 'claude', renameTitle, age: 1),
    chat('b', 'claude', 'Prune the roses', age: 3),
  ])..answer = _jira;
  FakeShells(
    fake,
    terminals: [
      Terminal(
        id: 't1',
        chatId: 'c',
        folder: '/Users/me/garden',
        shell: 'fish',
        name: renameTerminal,
      ),
    ],
  );
  terminalChats.value = {'c'};
  sidebarSections.value = const [
    Section(id: 's1', name: renameSection, chats: ['b']),
  ];
  final d = await openApp(tester, fake, brightness: brightness);
  if (ratio != 1) {
    viewport(
      tester,
      const Size(1700, 900),
      ratio: ratio,
      brightness: brightness,
    );
    await tester.pumpAndSettle();
  }
  return d;
}

/// A place a name is edited in: what opens it (`prepare`, if anything),
/// what holds it (whose height mustn't change), the name as shown, and
/// how its edit starts.
typedef RenamePlace = ({
  String name,
  Future<void> Function(WidgetTester tester)? prepare,
  Finder Function() holder,
  Finder Function() text,
  Future<void> Function(WidgetTester tester, Daemon d) start,
});

Finder _sidebarTitle() => find
    .descendant(of: find.byType(SidebarRow), matching: find.text(renameTitle))
    .first;

Finder _tabName() => find.descendant(
  of: find.byType(TerminalTabs),
  matching: find.text(renameTerminal),
);

/// The new chat dialog's branch line, the issue picked.
Finder _branchLine() => find
    .ancestor(of: find.text('In a new worktree on'), matching: find.byType(Row))
    .at(1);

/// Every place a name is edited in place.
final List<RenamePlace> renamePlaces = [
  (
    name: 'the sidebar row',
    prepare: null,
    holder: () =>
        find.ancestor(of: _sidebarTitle(), matching: find.byType(SidebarRow)),
    text: _sidebarTitle,
    start: (tester, d) async {
      await tester.tapAt(
        tester.getCenter(_sidebarTitle()),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
    },
  ),
  (
    name: 'the chat header',
    prepare: null,
    holder: () => find.byType(ChatHeader),
    text: () => find.descendant(
      of: find.byType(ChatHeader),
      matching: find.text(renameTitle),
    ),
    start: (tester, d) async {
      d.chats['c']!.renaming.value = true;
      await tester.pumpAndSettle();
    },
  ),
  (
    name: 'a terminal tab',
    prepare: null,
    holder: () => find.byType(TerminalTabs),
    text: _tabName,
    start: (tester, d) async {
      // A second click soon after the first renames.
      await tester.tap(_tabName());
      await tester.pump();
      await tester.tap(_tabName());
      await tester.pumpAndSettle();
    },
  ),
  (
    name: 'a sidebar section',
    prepare: null,
    holder: () => find
        .ancestor(
          of: find.text(renameSection),
          matching: find.byType(GroupHeader),
        )
        .first,
    text: () => find.text(renameSection),
    start: (tester, d) async {
      renamingSection.value = 's1';
      await tester.pumpAndSettle();
    },
  ),
  (
    name: "the new chat dialog's branch",
    prepare: openIssueDialog,
    holder: _branchLine,
    text: () => find.descendant(
      of: _branchLine(),
      matching: find.textContaining(renameIssue),
    ),
    start: (tester, d) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
    },
  ),
];

/// Opens the new chat dialog on [renameIssue], for its branch.
Future<void> openIssueDialog(WidgetTester tester) async {
  await tester.tap(find.byTooltip('New chat here').first);
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
  await tester.pump(Waits.typing);
  await tester.pumpAndSettle();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

/// The field being edited.
Finder get editing => find.byType(InlineEdit);

/// The box drawn round the field: its decoration and its rect.
(BoxDecoration, Rect) editBox(WidgetTester tester) {
  final box = find.descendant(
    of: editing,
    matching: find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).border != null,
    ),
  );
  expect(box, findsOne, reason: 'the field draws its own box');
  return (
    tester.widget<DecoratedBox>(box).decoration as BoxDecoration,
    tester.getRect(box),
  );
}

/// Where the text's first line starts: its left edge and its baseline,
/// in the window, for the shown name ([of] a Text) or the field's.
Offset textStart(WidgetTester tester, Finder of) {
  RenderBox? text;
  void visit(RenderObject r) {
    if (text != null) return;
    if (r is RenderParagraph || r is RenderEditable) {
      text = r as RenderBox;
      return;
    }
    r.visitChildren(visit);
  }

  visit(tester.renderObject(of));
  final box = text!;
  final at = box.localToGlobal(Offset.zero);
  return at.translate(
    0,
    box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!,
  );
}
