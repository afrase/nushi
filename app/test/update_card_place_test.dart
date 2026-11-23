import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_pane.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/commit_box.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/pull_tab.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/top_notices.dart';
import 'package:nushi/trust_ask.dart';
import 'package:nushi/update_toast.dart';

import 'browser_fixture.dart' show browserFakes;
import 'fake_daemon.dart' show FakeDaemon, loadFonts;
import 'github_fixture.dart' as gh;
import 'harness.dart';
import 'jira_fixture.dart' as jira;
import 'pull_fixture.dart';
import 'right_panes_fixture.dart';
import 'update_fixtures.dart';

// Where the newer release's card sits in every view and at every width a
// window has (ADR 0128, amended 2026-11-19): in the window's bottom right
// corner, the same inset from its right and bottom edges whatever is open,
// raised only above a bar with controls at the foot of what's under it;
// never over a control (a button, a field, a bar or a pane's header; a
// scrolling list's rows, as the transcript's, it may cover), wholly inside
// the window, and all there, over the panes too.

/// The card's room from the window's right and bottom edges: the main
/// area's pad and its own inset in it.
const double _inset = NushiTheme.windowPad + TopNotices.cardInset;

/// The card's answer to a ping, on [fake], and the ping that brings it.
Future<void> _card(WidgetTester tester, Daemon d, FakeDaemon fake) async {
  final before = fake.answer;
  fake.answer = (input) => switch (input) {
    PingRequest() => PingResponse(
      apiVersion: apiVersion,
      version: '0.1.16',
      update: newerUpdate('0.1.17'),
    ),
    _ => before?.call(input),
  };
  await d.ping();
  await tester.pumpAndSettle();
}

/// A diff long enough to fill the Changes view.
final List<FileChange> _longDiff = [
  for (final name in ['auth/redirect.go', 'auth/session.go'])
    FileChange(
      path: name,
      status: 'modified',
      oldText: [for (var i = 0; i < 200; i++) 'line $i'].join('\n'),
      newText: [
        for (var i = 0; i < 200; i++)
          if (i.isEven) 'line $i' else 'changed $i',
      ].join('\n'),
      added: 100,
      removed: 100,
    ),
];

Object? _changes(Object input) => switch (input) {
  GetFolderStatusRequest() => GetFolderStatusResponse(
    git: true,
    branch: 'fix-login',
    defaultBase: 'main',
  ),
  ListCommitsRequest() => ListCommitsResponse(),
  GetDiffRequest() => GetDiffResponse(files: _longDiff),
  _ => null,
};

/// What the card must never lie over, beside every shared control: the
/// bars at a view's foot and a pane's header.
const _bars = [Composer, StatusBar, CommitBox, RepliesWaiting, PaneHeader];

/// Whether [e] is in a list that scrolls up and down (a transcript's rows,
/// a diff's, a pull request's sections), which the card may cover.
bool _scrolls(Element e) {
  var found = false;
  e.visitAncestorElements((a) {
    if (a.widget case Scrollable(:final axisDirection)
        when axisDirectionToAxis(axisDirection) == Axis.vertical) {
      found = true;
    }
    return !found;
  });
  return found;
}

/// Whether what's hit at [p] is the card.
bool _cardAt(WidgetTester tester, Offset p) {
  final cards = updateToast.evaluate().map((e) => e.renderObject).toSet();
  return tester.hitTestOnBinding(p).path.any((h) => cards.contains(h.target));
}

/// The bars with controls the card stands above ([UnderCard]), each
/// without its bare ends ([UnderCard.clear]: a chat's foot is as wide as
/// its view, its composer only its column's).
List<Rect> _floorBars(WidgetTester tester) => [
  for (final e in find.byType(UnderCard).evaluate())
    switch (tester.getRect(find.byElementPredicate((x) => x == e))) {
      final r => Rect.fromLTRB(
        r.left + (e.widget as UnderCard).clear,
        r.top,
        r.right - (e.widget as UnderCard).clear,
        r.bottom,
      ),
    },
];

/// Whether the card is across from a bar's controls: it must rise.
bool _acrossBar(WidgetTester tester) {
  final card = tester.getRect(updateToast);
  return _floorBars(tester)
      .any((r) => r.left < card.right && r.right > card.left);
}

/// Whether the card, in the window [width] wide, is in its corner: [_inset]
/// from its right edge, and from its bottom edge unless it stands
/// [TopNotices.cardInset] above a bar with controls at the foot of what's
/// under it ([UnderCard]); whether it's lifted so.
bool _cornered(WidgetTester tester, double width, String name) {
  final card = tester.getRect(updateToast);
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  expect(width - card.right, _inset, reason: '$name: right inset');
  if (height - card.bottom == _inset) return false;
  final bars = _floorBars(tester);
  expect(
    bars.any(
      (r) =>
          (r.top - card.bottom - TopNotices.cardInset).abs() < 0.5 &&
          r.left < card.right &&
          r.right > card.left,
    ),
    isTrue,
    reason: '$name: off the corner ($card) but above no bar of $bars',
  );
  return true;
}

/// The card in the window [width] wide: in its corner ([_cornered]),
/// lifted or not as [lifted] says when given, shown whole, inside the
/// window, and over no control nor a bar, which it would hide.
Future<void> _placed(
  WidgetTester tester,
  String name,
  double width, {
  bool? lifted,
}) async {
  await render(tester, find.byType(NushiApp), name);
  expect(tester.takeException(), isNull);
  expect(updateToast, findsOneWidget);
  final up = _cornered(tester, width, name);
  if (lifted != null) expect(up, lifted, reason: '$name: lifted');
  final card = tester.getRect(updateToast);
  final inner = card.deflate(8);
  final hits = [
    for (final p in [
      inner.topLeft,
      inner.topRight,
      inner.bottomLeft,
      inner.bottomRight,
      inner.center,
    ])
      _cardAt(tester, p),
  ];
  expect(hits.contains(false), isFalse, reason: '$name: hidden $hits');
  expect(card.left, greaterThanOrEqualTo(0));
  expect(card.right, lessThanOrEqualTo(width));
  expect(card.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
  final controls = [
    ...find.byType(Pressable).evaluate().where((e) => !_scrolls(e)),
    // A field that scrolls with its page (a pull request's comment box,
    // under its description) is as a list's row: the page scrolls it out
    // from under the card.
    ...find.byType(EditableText).evaluate().where((e) => !_scrolls(e)),
    for (final t in _bars) ...find.byType(t).evaluate(),
  ];
  final mine = find
      .descendant(
        of: updateToast,
        matching: find.byWidgetPredicate((_) => true),
      )
      .evaluate()
      .toSet();
  // Where the card is on top of a control's box, the control must be out
  // of reach there with the card gone too (under a pane lying over it).
  final covered = <(Element, RenderBox, Offset)>[];
  for (final e in controls) {
    if (mine.contains(e)) continue;
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    final o = card.intersect(r);
    if (o.width <= 0.5 || o.height <= 0.5) continue;
    for (final p in [o.center, o.centerLeft + const Offset(1, 0)]) {
      if (_cardAt(tester, p)) covered.add((e, box, p));
    }
  }
  if (covered.isEmpty) return;
  dismissedUpdate.value = '0.1.17';
  await tester.pumpAndSettle();
  for (final (e, box, p) in covered) {
    expect(
      tester.hitTestOnBinding(p).path.any((h) => h.target == box),
      isFalse,
      reason: '$name: the card $card over ${e.widget.runtimeType} at $p',
    );
  }
  dismissedUpdate.value = null;
  await tester.pumpAndSettle();
}

/// Opens the chat's [tab] (its header folds its tabs when narrow, so wide
/// first) and narrows the window to [width].
Future<void> _tab(WidgetTester tester, String tab, double width) async {
  await tester.tap(
    find.descendant(of: find.byType(ChatHeader), matching: find.text(tab)),
  );
  await tester.pumpAndSettle();
  viewport(tester, Size(width, 800));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);
  setUp(() {
    brewCask = null;
  });

  // Renders to look at: the card over a chat alone, beside the details
  // column and over a side chat, wide and narrow, in both themes.
  for (final width in [1700.0, 720.0]) {
    for (final brightness in Brightness.values) {
      for (final (scene, details, side) in [
        ('alone', false, false),
        ('details', true, false),
        ('side', false, true),
      ]) {
        final name = 'corner_${scene}_${width.toInt()}_${brightness.name}';
        testWidgets('render $name', (tester) async {
          final (d, fake) = await panesApp(
            tester,
            width: width,
            height: 800,
            sidebar: true,
            details: details,
            brightness: brightness,
            open: (
              side: side,
              files: false,
              subagent: false,
              command: false,
              previews: 0,
              browser: 0,
            ),
          );
          await _card(tester, d, fake);
          await render(tester, find.byType(NushiApp), name);
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }

  for (final width in [400.0, 480.0, 600.0, 720.0, 900.0, 1280.0, 1700.0]) {
    final w = width.toInt();
    Future<(Daemon, FakeDaemon)> open(
      WidgetTester tester, {
      bool details = false,
      PanesOpen panes = noPanes,
      double at = 0,
      bool sidebar = true,
      bool terminal = false,
    }) async {
      final (d, fake) = await panesApp(
        tester,
        width: at > 0 ? at : width,
        height: 800,
        sidebar: sidebar,
        details: details,
        terminal: terminal,
        open: panes,
      );
      await _card(tester, d, fake);
      return (d, fake);
    }

    group('$w wide', () {
      for (final sidebar in [true, false]) {
        final name = 'chat_${sidebar ? '' : 'nosidebar_'}$w';
        testWidgets('the Chat tab, $name', (tester) async {
          final (d, _) = await open(tester, sidebar: sidebar);
          // Above the composer where the chat's column reaches under
          // it; in the corner beside it where the view is wider than the
          // column and its gutter has room for the card.
          final beside = width == 1700 && !sidebar;
          expect(_acrossBar(tester), !beside, reason: name);
          await _placed(tester, name, width, lifted: !beside);
          if (beside) {
            final field = tester.getRect(find.byType(EditableText).first);
            expect(tester.getRect(updateToast).left, greaterThan(field.right));
          }
          await closeView(tester, d);
        }, variant: onMac);
      }

      testWidgets('the details rail', (tester) async {
        final (d, _) = await open(tester, details: true);
        final rail = find.byType(DetailsPanel).hitTestable();
        final shown = rail.evaluate().isNotEmpty;
        // Over the rail's foot, at the corner; tucked away, above the
        // composer, as alone.
        await _placed(tester, 'details_$w', width, lifted: !shown);
        if (shown) {
          final card = tester.getRect(updateToast);
          expect(card.left, greaterThanOrEqualTo(tester.getRect(rail).left));
        }
        await closeView(tester, d);
      }, variant: onMac);

      // Over the terminal's text at the corner: it has no controls at its
      // foot, and the composer is above it.
      testWidgets('the terminal', (tester) async {
        final (d, _) = await open(tester, terminal: true);
        await _placed(tester, 'terminal_$w', width, lifted: false);
        await closeView(tester, d);
      }, variant: onMac);

      // Each pane, beside the transcript where it's wide enough and over
      // it where it isn't, has the corner: a side chat lifts the card above
      // its composer; Files, a subagent's pane and the browser have plain
      // content at their foot, which the card lies over.
      for (final (pane, panes, lifted) in [
        ('files', (files: true, side: false, sub: false, browser: 0), false),
        ('side', (files: false, side: true, sub: false, browser: 0), true),
        ('subagent', (files: false, side: false, sub: true, browser: 0), false),
        ('browser', (files: false, side: false, sub: false, browser: 1), false),
      ]) {
        for (final sidebar in [true, false]) {
          final name = '${pane}_${sidebar ? '' : 'nosidebar_'}$w';
          testWidgets('the $pane pane, $name', (tester) async {
            if (panes.browser > 0) browserFakes();
            final (d, _) = await open(
              tester,
              sidebar: sidebar,
              panes: (
                side: panes.side,
                files: panes.files,
                subagent: panes.sub,
                command: false,
                previews: 0,
                browser: panes.browser,
              ),
            );
            // A pane narrower than the card (a subagent's, or one squeezed
            // in a narrow window) leaves it over the transcript's composer
            // too, which it rises above.
            final paneOf = find.byType(switch (pane) {
              'files' => FilesPane,
              'side' => SideChat,
              'subagent' => SubagentPane,
              _ => BrowserPane,
            });
            final narrow =
                tester.getRect(paneOf).width <
                UpdateToast.width + TopNotices.cardInset;
            await _placed(
              tester,
              name,
              width,
              lifted: (narrow && _acrossBar(tester)) || lifted,
            );
            // Over the pane, which has the window's corner.
            final card = tester.getRect(updateToast);
            expect(tester.getRect(paneOf).contains(card.center), isTrue);
            await closeView(tester, d);
          }, variant: onMac);
        }
      }

      // Over Files expanded over all, beside a side chat (under it, kept
      // but not drawn): at the corner, not lifted for the hidden composers.
      // At 400 Files is too squeezed for its Expand.
      testWidgets('Files expanded', skip: width < 480, (tester) async {
        final (d, _) = await open(
          tester,
          panes: (
            side: true,
            files: true,
            subagent: false,
            command: false,
            previews: 0,
            browser: 0,
          ),
        );
        await tester.tap(find.byTooltip('Expand'));
        await tester.pumpAndSettle();
        await _placed(tester, 'expanded_$w', width, lifted: false);
        await closeView(tester, d);
      }, variant: onMac);

      // Under Settings, which opens over all, where it was. Narrower than
      // 600 Settings' rows overflow, the card aside.
      testWidgets('Settings', skip: width < 600, (tester) async {
        final (d, _) = await open(tester, details: true);
        final before = tester.getRect(updateToast);
        d.openSettings();
        await tester.pumpAndSettle();
        await render(tester, find.byType(NushiApp), 'settings_$w');
        expect(tester.getRect(updateToast), before);
        _cornered(tester, width, 'settings_$w');
        d.closeSettings();
        await closeView(tester, d);
      }, variant: onMac);

      testWidgets('the Changes tab, a long diff', (tester) async {
        final (d, fake) = await open(tester, at: 1700);
        final before = fake.answer;
        fake.answer = (input) => _changes(input) ?? before?.call(input);
        await _tab(tester, 'Changes', width);
        expect(
          find.textContaining('redirect.go', findRichText: true),
          findsWidgets,
        );
        await _placed(tester, 'changes_$w', width);
        await closeView(tester, d);
      }, variant: onMac);

      // At 400 a to-do row's buttons overflow, the card aside.
      testWidgets('the Pull request tab, cards waiting', skip: width < 480, (
        tester,
      ) async {
        final (d, fake) = await openPullTab(
          tester,
          fixturePull(),
          size: const Size(1700, 800),
          open: false,
        );
        await _card(tester, d, fake);
        d.chats['c']!.draft.replies.value = [
          (quote: 'CI / rubocop', text: 'Fix it', from: 'checks'),
        ];
        await _tab(tester, 'Pull request', width);
        expect(find.byType(RepliesWaiting), findsOneWidget);
        await _placed(tester, 'pull_$w', width);
        d.chats['c']!.draft.replies.value = const [];
        await closeView(tester, d);
      }, variant: onMac);

      for (final (view, go) in <(String, void Function(Daemon))>[
        (
          'nothing',
          (d) => d
            ..selectedId = null
            ..listChanged(),
        ),
        (
          'trust',
          (d) => d
            ..trustAsk = TrustAsk(
              '/Users/me/site',
              'Start Claude',
              const [],
              'claude',
            )
            ..listChanged(),
        ),
      ]) {
        testWidgets(view, (tester) async {
          final (d, _) = await open(tester);
          go(d);
          await tester.pumpAndSettle();
          await _placed(tester, '${view}_$w', width);
          await closeView(tester, d);
        }, variant: onMac);
      }

      // Their lists, then an item open. Narrower than 600 their headers
      // overflow, the card aside.
      for (final (view, opener, row) in [
        ('jira', jira.openView, 'Log in with a passkey'),
        ('github', gh.openView, 'Add Sub and Neg'),
      ]) {
        testWidgets(view, skip: width < 600, (tester) async {
          final (fake, d) = await opener(
            tester,
            window: true,
            size: Size(width, 800),
          );
          await _card(tester, d, fake);
          await _placed(tester, '${view}_list_$w', width);
          await tester.tap(find.text(row).first);
          await tester.pumpAndSettle();
          await _placed(tester, '${view}_item_$w', width);
          await closeView(tester, d);
        }, variant: onMac);
      }
    });
  }
}
