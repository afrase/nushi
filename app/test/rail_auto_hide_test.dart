import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/beside_fit.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_panes.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/sidebar_beside.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/transcript.dart';

import 'browser_fixture.dart' show browserFakes;
import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'right_panes_fixture.dart';

// The details rail tucks itself away when the panes beside the chat need
// its room, and comes back when there's room again (ADR 0123): decided on
// the room alone, never saved, the header's button still the user's
// choice. Only once the transcript is too narrow even then do the panes
// lie over it.

/// Linux too, for a few: the same layout (ADR 0123).
PanesOpen _openOf(List<PaneSpec> panes, {int previews = 0}) => (
  side: panes.contains(ChatPanes.side),
  files: panes.contains(ChatPanes.files),
  subagent: panes.contains(ChatPanes.subagent),
  command: false,
  previews: previews,
  browser: panes.contains(ChatPanes.browser) ? 1 : 0,
);

/// A file open: in the Files pane.
final PanesOpen _aFile = _openOf([ChatPanes.files], previews: 1);

Type _typeOf(PaneSpec p) => switch (p.name) {
  'side' => SideChat,
  'filesPane' => FilesPane,
  'subagent' => SubagentPane,
  _ => BrowserPane,
};

/// The rail shows (drawn: not tucked away).
bool _rail() => find.byType(DetailsPanel).evaluate().isNotEmpty;

/// The panes lie over the transcript: it runs on under the first.
bool _over(WidgetTester tester, List<PaneSpec> panes) =>
    tester.getRect(_transcript).right >
    tester.getRect(find.byType(_typeOf(panes.first))).left;

/// The chat's own transcript.
final Finder _transcript = find.byWidgetPredicate(
  (w) => w is Transcript && w.items == null && w.chat.id == 'c',
);

/// The header's details button, by its tooltip.
Finder get _button => find.descendant(
  of: find.byType(ChatHeader),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Tooltip &&
        ((w.message ?? '').endsWith('details') ||
            (w.message ?? '').startsWith('Hide details') ||
            w.message == 'The window is too narrow' ||
            w.message == 'Details show on the Chat tab'),
  ),
);

String _tip(WidgetTester tester) => tester.widget<Tooltip>(_button).message!;

void main() {
  setUpAll(loadFonts);

  // Every row of the table, the sidebar shown and hidden, at its line and
  // a point either side: at the line it's the better state.
  for (final row in thresholdRows) {
    for (final sidebar in [true, false]) {
      final where = sidebar ? 'sidebar shown' : 'sidebar hidden';
      final beside = switch (row.beside) {
        final b? => windowFor(b, sidebar: sidebar).toInt(),
        null => '-',
      };
      testWidgets('${row.name}, $where: the rail from '
          '${windowFor(row.rail, sidebar: sidebar).toInt()}, beside from '
          '$beside', (tester) async {
        final rail = windowFor(row.rail, sidebar: sidebar);
        browserFakes();
        final (d, _) = await panesApp(
          tester,
          width: rail,
          sidebar: sidebar,
          open: _openOf(row.panes),
        );
        Future<void> at(double w) async {
          viewport(tester, Size(w, 900));
          await tester.pumpAndSettle();
        }

        // Named for the sidebar and the platform too, so neither run
        // writes over another's.
        final shown = sidebar ? 'sidebar' : 'nosidebar';
        final named = '${shown}_${defaultTargetPlatform.name}';

        for (final (w, shows) in [
          (rail + 1, true),
          (rail, true),
          (rail - 1, false),
        ]) {
          await at(w);
          expect(_rail(), shows, reason: 'at $w');
          if (row.panes.isNotEmpty) expect(_over(tester, row.panes), false);
          if (w != rail + 1) {
            await render(
              tester,
              find.byType(NushiApp),
              'rail_line_${row.name}_${w.toInt()}_$named',
            );
          }
        }
        if (row.narrow case final n?) {
          // At the line the panes are at their widths; a point under it the
          // widest gives that point, still beside the transcript.
          final narrow = windowFor(n, sidebar: sidebar);
          for (final (w, less) in [(narrow, 0.0), (narrow - 1, 1.0)]) {
            await at(w);
            expect(_rail(), false, reason: 'at $w');
            expect(_over(tester, row.panes), false, reason: 'at $w');
            final widths = [
              for (final p in row.panes)
                tester.getRect(find.byType(_typeOf(p))).width,
            ];
            final want = [for (final p in row.panes) p.initial];
            want[want.lastIndexOf(want.reduce(max))] -= less;
            expect(widths, want, reason: 'at $w');
            await render(
              tester,
              find.byType(NushiApp),
              'narrow_line_${row.name}_${w.toInt()}_$named',
            );
          }
        }
        if (row.beside case final b?) {
          final beside = windowFor(b, sidebar: sidebar);
          for (final (w, over) in [(beside, false), (beside - 1, true)]) {
            await at(w);
            expect(_rail(), false, reason: 'at $w');
            expect(_over(tester, row.panes), over, reason: 'at $w');
            await render(
              tester,
              find.byType(NushiApp),
              'beside_line_${row.name}_${w.toInt()}_$named',
            );
          }
        }
        expect(showDetails.value, isTrue);
        await closeView(tester, d);
      }, variant: {'none', 'browser'}.contains(row.name) ? macAndLinux : onMac);
    }
  }

  testWidgets('hiding it for room is never saved, and the button keeps the '
      "user's choice", (tester) async {
    // A file in the Files pane: the rail tucks under 1500 for the chat.
    final width = windowFor(1450, sidebar: false);
    final (d, _) = await panesApp(tester, width: width + 200);
    await tester.pump(const Duration(seconds: 2));
    final saved = readSaved();
    var told = 0;
    void count() => told++;
    showDetails.addListener(count);
    addTearDown(() => showDetails.removeListener(count));
    viewport(tester, Size(width, 900));
    await openPanesIn(tester, d, _aFile);
    expect(_rail(), false);
    expect(told, 0);
    await tester.pump(const Duration(seconds: 2)); // a save would be done
    expect(readSaved()['details'], saved['details']);
    expect((readSaved()['panes'] as Map?)?['details'], isNull);
    // The button: lit, it hides them, and says they're tucked away.
    final button = tester.widget<Tooltip>(_button);
    expect(
      button.message,
      'Hide details (tucked away while the panes need the room)',
    );
    final header = tester.getRect(find.byType(ChatHeader));
    final preview = tester.getRect(find.byType(FileView));
    final menu = tester.getRect(find.byTooltip('Chat menu'));
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(showDetails.value, isFalse);
    expect(_tip(tester), 'Show details');
    // Nothing moved.
    expect(tester.getRect(find.byType(ChatHeader)), header);
    expect(tester.getRect(find.byType(FileView)), preview);
    expect(tester.getRect(find.byTooltip('Chat menu')), menu);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(showDetails.value, isTrue);
    expect(_rail(), false);
    expect(tester.getRect(find.byType(FileView)), preview);
    // Room again: they're back. Not wanted, they don't come.
    viewport(tester, Size(width + 200, 900));
    await tester.pumpAndSettle();
    expect(_rail(), true);
    showDetails.value = false;
    viewport(tester, Size(width, 900));
    await tester.pumpAndSettle();
    viewport(tester, Size(width + 400, 900));
    await tester.pumpAndSettle();
    expect(_rail(), false);
    // Nor when the panes close, one and then the other, narrow again.
    viewport(tester, Size(width, 900));
    await tester.pumpAndSettle();
    final c = d.chats['c']!;
    c.files.close(c.files.shown.value!);
    await tester.pumpAndSettle();
    expect(find.byType(FileView), findsNothing);
    expect(find.byType(FilesPane), findsOneWidget);
    expect(_rail(), false);
    toggleFiles(c);
    await tester.pumpAndSettle();
    expect(find.byType(FilesPane), findsNothing);
    expect(_rail(), false);
    expect(find.byType(DetailsPanel, skipOffstage: false), findsNothing);
    expect(_tip(tester), 'Show details');
    expect(showDetails.value, isFalse);
    await closeView(tester, d);
  }, variant: macAndLinux);

  for (final tucked in [false, true]) {
    testWidgets('a peek at the hidden sidebar, the rail '
        '${tucked ? 'tucked' : 'shown'} beside the browser, flips nothing: '
        'the rail stays as it was and no pane moves', (tester) async {
      // At the browser's line the rail just fits; a point under, it's
      // tucked. The peek lies over the chat, so it takes none of the room.
      final row = thresholdRows.firstWhere((r) => r.name == 'browser');
      browserFakes();
      final line = windowFor(row.rail, sidebar: false);
      final (d, _) = await panesApp(
        tester,
        width: tucked ? line - 1 : line,
        open: _openOf(row.panes),
      );
      expect(_rail(), !tucked);
      Map<String, Rect> rects() => {
        'header': tester.getRect(find.byType(ChatHeader)),
        'browser': tester.getRect(find.byType(BrowserPane)),
        'menu': tester.getRect(find.byTooltip('Chat menu')),
        if (!tucked) 'rail': tester.getRect(find.byType(DetailsPanel)),
      };
      final before = rects();
      var flips = 0;
      final shows = _rail();
      void check(String when) {
        if (_rail() != shows) flips++;
        expect(rects(), before, reason: when);
      }

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 400));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.byTooltip('Show the sidebar\u2002⌘\\')),
      );
      // Each frame of its slide in, then at rest.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        check('sliding in, frame $i');
      }
      await tester.pumpAndSettle();
      expect(find.byType(Sidebar), findsOneWidget);
      expect(sidebarHidden.value, isTrue, reason: 'a peek');
      check('peeking');
      // The pointer off it: it slides away, and still nothing moved.
      await mouse.moveTo(Offset(before['browser']!.center.dx, 400));
      await tester.pump(SidebarBeside.grace);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        check('sliding away, frame $i');
      }
      await tester.pumpAndSettle();
      expect(find.byType(Sidebar), findsNothing);
      check('gone');
      expect(flips, 0);
      expect(showDetails.value, isTrue);
      await closeView(tester, d);
    }, variant: onMac);
  }

  group('it comes back when there is room again:', () {
    // The subagent's pane at the line, less a point: tucked.
    final width = windowFor(944, sidebar: true) - 1;

    Future<void> tucked(WidgetTester tester) async {
      expect(_rail(), false);
      expect(find.byType(DetailsPanel, skipOffstage: false), findsOneWidget);
    }

    /// It slides in: drawn right of where it ends on its first frame.
    Future<void> slidesBack(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_rail(), true);
      final first = tester.getRect(find.byType(DetailsPanel)).left;
      await tester.pumpAndSettle();
      expect(_rail(), true);
      expect(
        first,
        greaterThan(tester.getRect(find.byType(DetailsPanel)).left),
      );
    }

    Future<Daemon> app(WidgetTester tester) async {
      final (d, _) = await panesApp(
        tester,
        width: width,
        sidebar: true,
        open: _openOf([ChatPanes.subagent]),
      );
      await tucked(tester);
      return d;
    }

    testWidgets('the window widens', (tester) async {
      final d = await app(tester);
      viewport(tester, Size(width + 40, 900));
      await slidesBack(tester);
      await closeView(tester, d);
    }, variant: macAndLinux);

    testWidgets('the pane closes', (tester) async {
      final d = await app(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SubagentPane),
          matching: find.byTooltip('Close'),
        ),
      );
      await slidesBack(tester);
      await closeView(tester, d);
    }, variant: macAndLinux);

    testWidgets('its edge is dragged narrower', (tester) async {
      final d = await app(tester);
      final pane = tester.getRect(find.byType(SubagentPane));
      final drag = await tester.startGesture(
        Offset(pane.left + Resizable.edgeWidth / 2, pane.center.dy),
      );
      await drag.moveBy(const Offset(20, 0));
      await tester.pump();
      await drag.moveBy(const Offset(20, 0));
      await slidesBack(tester);
      await drag.up();
      await tester.pump(const Duration(seconds: 2));
      expect(_rail(), true);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('its edge, dragged wide, is reset with a double-click', (
      tester,
    ) async {
      final (d, _) = await panesApp(
        tester,
        width: width + 40,
        sidebar: true,
        open: _openOf([ChatPanes.subagent]),
        widths: {'subagent': 400},
      );
      await tucked(tester);
      final pane = tester.getRect(find.byType(SubagentPane));
      final at = Offset(pane.left + Resizable.edgeWidth / 2, pane.center.dy);
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at);
      await slidesBack(tester);
      expect(paneWidths.value['subagent'], isNull);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('the sidebar hides', (tester) async {
      final d = await app(tester);
      sidebarHidden.value = true;
      await slidesBack(tester);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('the Files pane closes (⇧⌘E)', (tester) async {
      final (d, _) = await panesApp(
        tester,
        width: windowFor(1764, sidebar: true) - 1,
        sidebar: true,
        open: _openOf([ChatPanes.files, ChatPanes.subagent]),
      );
      await tucked(tester);
      expect(find.byType(FilesPane), findsOneWidget);
      toggleFiles(_chat(tester));
      await slidesBack(tester);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('the side chat hides (⇧⌘B)', (tester) async {
      final (d, _) = await panesApp(
        tester,
        width: windowFor(1324, sidebar: true) - 1,
        sidebar: true,
        open: _openOf([ChatPanes.side, ChatPanes.subagent]),
      );
      await tucked(tester);
      _chat(tester).sideHidden.value = true;
      await slidesBack(tester);
      await closeView(tester, d);
    }, variant: onMac);
  });

  testWidgets("with no pane, the window's own rule (ADR 0092): too narrow "
      'under 804 for the chat, the button disabled and saying so', (
    tester,
  ) async {
    for (final sidebar in [true, false]) {
      final line = windowFor(804, sidebar: sidebar);
      final (d, _) = await panesApp(tester, width: line, sidebar: sidebar);
      expect(_rail(), true);
      expect(_tip(tester), 'Hide details');
      viewport(tester, Size(line - 1, 900));
      await tester.pumpAndSettle();
      expect(_rail(), false);
      expect(_tip(tester), 'The window is too narrow');
      // Gone, not tucked: as before.
      expect(find.byType(DetailsPanel, skipOffstage: false), findsNothing);
      await closeView(tester, d);
    }
  }, variant: onMac);

  testWidgets('a pane open in a chat area under 804: too narrow, no '
      'button or ⋯ entry, the panel gone and made once each time the area '
      'crosses back', (tester) async {
    final (d, fake) = await panesApp(
      tester,
      width: windowFor(800, sidebar: false),
      open: _openOf([ChatPanes.subagent]),
    );
    expect(_rail(), false);
    // Gone, not tucked, as with no pane: it's made again once there's room.
    expect(find.byType(DetailsPanel, skipOffstage: false), findsNothing);
    // Its button folds into ⋯ first, and ⋯ has no details either.
    expect(_button, findsNothing);
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget); // the menu's open
    expect(find.text('Show details'), findsNothing);
    expect(find.text('Hide details'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    // Back and forth across 804, the pane still open: made (tucked, as
    // the pane needs its room) at each crossing up, showing what the chat's
    // changes have (ChatChanges) and asking the daemon for the folder again.
    int asks() =>
        fake.calls.whereType<GetFolderStatusRequest>().length +
        fake.calls.whereType<ListBranchesRequest>().length;
    var asked = asks();
    for (var i = 0; i < 3; i++) {
      viewport(tester, Size(windowFor(805, sidebar: false), 900));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsPanel, skipOffstage: false), findsOneWidget);
      expect(_rail(), false);
      expect(asks() - asked, 2);
      asked = asks();
      viewport(tester, Size(windowFor(803, sidebar: false), 900));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsPanel, skipOffstage: false), findsNothing);
      expect(asks(), asked);
    }
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("tucked, the rail still asks what fills the chat's context "
      'after a turn, as a shown one does, so it comes back current', (
    tester,
  ) async {
    // The Files pane needs the rail's room in a chat area of 1100.
    final (d, fake) = await panesApp(
      tester,
      width: windowFor(1100, sidebar: false),
      open: _aFile,
    );
    fake.on(
      (input) => input is GetContextUsageRequest
          ? GetContextUsageResponse(
              categories: [
                ContextCategory(
                  name: 'Messages',
                  tokens: Int64(5),
                  part: 'messages',
                ),
              ],
            )
          : null,
    );
    final c = d.chats['c']!
      // A turn under way: the status the chat list sends.
      ..listed(ChatStatus(busy: true, canAskContext: true));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(DetailsPanel), findsNothing);
    expect(find.byType(DetailsPanel, skipOffstage: false), findsOneWidget);
    int asked() => fake.calls.whereType<GetContextUsageRequest>().length;
    expect(asked(), 0, reason: 'busy: not yet');
    // The turn ends: asked a moment later, once, while tucked.
    c.listed(ChatStatus(canAskContext: true));
    await tester.pump(const Duration(seconds: 2));
    expect(asked(), 1);
    expect(find.byType(DetailsPanel), findsNothing);
    // Within the minute, another turn asks nothing more.
    c
      ..listed(ChatStatus(busy: true, canAskContext: true))
      ..listed(ChatStatus(canAskContext: true));
    await tester.pump(const Duration(seconds: 2));
    expect(asked(), 1);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Artifacts… lists in the palette while the rail is tucked, '
      'and opens it where there is room', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1100, sidebar: false),
      open: _aFile,
    );
    final c = d.chats['c']!;
    expect(c.panelFits(), isFalse);
    showDetails.value = false;
    await tester.pumpAndSettle();
    revealArtifacts(tester.element(find.byType(ChatHeader)), c);
    await tester.pumpAndSettle();
    expect(find.byType(Palette), findsOneWidget);
    expect(showDetails.value, isFalse);
    Navigator.of(tester.element(find.byType(Palette))).pop();
    await tester.pumpAndSettle();
    toggleFiles(c);
    await tester.pumpAndSettle();
    expect(c.panelFits(), isTrue);
    revealArtifacts(tester.element(find.byType(ChatHeader)), c);
    await tester.pumpAndSettle();
    expect(find.byType(Palette), findsNothing);
    expect(showDetails.value, isTrue);
    expect(_rail(), true);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("an archived chat's side chat takes no room", (tester) async {
    // At the Files pane's own line: the rail shows beside it, the side
    // chat not placed.
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1500, sidebar: false),
      archived: true,
      open: _openOf([ChatPanes.side, ChatPanes.files], previews: 1),
    );
    expect(find.byType(SideChat, skipOffstage: false), findsNothing);
    expect(find.byType(FileView), findsOneWidget);
    expect(_rail(), true);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a chat whose session is gone is laid out as a live one: '
      'its side chat, a session of its own, takes its room (only archiving '
      "ends it), so the rail tucks at the Files pane's line", (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1500, sidebar: false),
      open: _openOf([ChatPanes.side, ChatPanes.files], previews: 1),
    );
    final c = d.chats['c']!..listed(ChatStatus(sessionGone: true));
    await tester.pumpAndSettle();
    expect(c.sessionGone, isTrue);
    // The chat's composer gives way to the notice; the side chat keeps its
    // own.
    bool composerOf(String id) => find
        .byWidgetPredicate((w) => w is Composer && w.chat.id == id)
        .evaluate()
        .isNotEmpty;
    expect(composerOf('c'), isFalse);
    expect(composerOf('s'), isTrue);
    expect(find.byType(SideChat), findsOneWidget);
    expect(find.byType(FileView), findsOneWidget);
    expect(_rail(), false);
    // The room back without the side chat: the rail shows again, as in an
    // archived chat at this width.
    c.sideHidden.value = true;
    await tester.pumpAndSettle();
    expect(_rail(), true);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Changes and back, tucked: nothing slides, the header across '
      'on Changes', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1100, sidebar: false),
      open: _aFile,
    );
    final c = d.chats['c']!;
    final preview = tester.getRect(find.byType(FileView));
    expect(_rail(), false);
    c.tab.value = ChatTab.changes;
    await tester.pump();
    expect(find.byType(FileView), findsNothing);
    expect(
      find.byType(DetailsPanel, skipOffstage: false),
      findsNothing,
      reason: 'no details on Changes',
    );
    // The button says why it's off: the tab, not the window.
    expect(_tip(tester), 'Details show on the Chat tab');
    expect(
      tester.getRect(find.byType(ChatHeader)).width,
      tester.getRect(find.byType(Pane)).width,
    );
    await tester.pumpAndSettle();
    c.tab.value = ChatTab.chat;
    await tester.pump();
    expect(tester.getRect(find.byType(FileView)), preview);
    expect(_rail(), false);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FileView)), preview);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('another chat with room shows its rail at once, and back '
      'the first is tucked, with no slide', (tester) async {
    final (d, _) = await panesApp(
      tester,
      width: windowFor(1100, sidebar: false),
      open: _aFile,
    );
    final preview = tester.getRect(find.byType(FileView));
    d.select('d');
    await tester.pump();
    await tester.pump();
    expect(_rail(), true);
    final rail = tester.getRect(find.byType(DetailsPanel));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(DetailsPanel)), rail);
    d.select('c');
    await tester.pump();
    await tester.pump();
    expect(_rail(), false);
    expect(tester.getRect(find.byType(FileView)), preview);
    await closeView(tester, d);
  }, variant: onMac);
}

ChatState _chat(WidgetTester tester) =>
    tester.widget<ChatHeader>(find.byType(ChatHeader)).chat;
