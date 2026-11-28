import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/pull_rows.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'pull_fixture.dart';
import 'pull_widget_rows_test.dart' show states;

// Issue 119: a pull request's row with data long enough to cut, in each
// state it can be in. Three reviews in turn found a link or a cut text
// against another cut text, each fix moving the link; the row's layout is
// now fixed (PullRow's comment) and these hold it.

/// A title of 80 characters, too long for the details panel.
const _title =
    "Export sighting dates in every site's own time zone, with each offset "
    'after them';

/// [p] with the long data: the title, large counts and a long base.
GitHubPull _long(GitHubPull p) => p
  ..item.title = _title
  ..additions = 12840
  ..deletions = 3771
  ..base = 'export-in-site-zone';

/// Each state a row can be in, and the cue its second line ends in (null:
/// none).
final Map<String, (GitHubPull Function(), String?)> _rows = {
  'open': (states['running']!, null),
  'draft': (states['draft']!, null),
  'failing checks': (
    () => states['failing']!()..item.review = 'approved',
    '2 threads',
  ),
  'changes requested': (states['failing']!, 'changes requested'),
  'merged': (states['merged']!, 'merged into export-in-site-zone'),
  'merged with Clean up': (
    states['merged']!,
    'merged into export-in-site-zone',
  ),
  'closed': (states['closed']!, 'closed without merging'),
  'ready to merge': (states['ready']!, 'ready to merge'),
  'in the queue': (() => mergePull('queue'), 'ready to merge'),
};

/// The details panel's Pull request widget.
Finder get _widget => find.ancestor(
  of: find.text('Pull request').last,
  matching: find.byType(PanelWidget),
);

/// The row's laid-out texts, each with its box in the window.
List<(RenderParagraph, Rect)> _texts(WidgetTester tester) => [
  for (final e
      in find
          .descendant(of: find.byType(PullRow), matching: find.byType(RichText))
          .evaluate())
    if (e.renderObject case final RenderParagraph p when p.size.width > 0)
      (p, p.localToGlobal(Offset.zero) & p.size),
];

/// Whether [p] is a link's text ([LinkText]).
bool _isLink(WidgetTester tester, RenderParagraph p) => find
    .ancestor(
      of: find.byElementPredicate((e) => e.renderObject == p),
      matching: find.byType(LinkText),
    )
    .evaluate()
    .isNotEmpty;

/// The app on a chat linked to [whole] at the details panel's width (its
/// only one, so its narrowest and its default), merged rows' clean-up
/// started unless [cleanUp].
Future<Daemon> _open(
  WidgetTester tester,
  GitHubPull whole, {
  bool cleanUp = true,
  Brightness brightness = Brightness.dark,
}) async {
  final (d, _) = await openPullTab(
    tester,
    whole,
    size: const Size(1700, 900),
    details: true,
    open: false,
    brightness: brightness,
  );
  if (!cleanUp) {
    // A clean-up that ran (only the chat archived): Clean up… is no longer
    // offered.
    await CleanUpJob.of(d.chats['c']!).run(d, (
      archive: true,
      worktree: false,
      force: false,
      branch: false,
      forceBranch: false,
      remote: false,
      stopTurn: false,
    ), null);
    await tester.pumpAndSettle();
  }
  return d;
}

/// The Pull request tab, wide, on a chat with [whole] (#537) and a second
/// pull request, its picker of their rows open.
Future<Daemon> _picker(
  WidgetTester tester,
  GitHubPull whole, {
  Brightness brightness = Brightness.dark,
}) async {
  final other = fixturePull()
    ..item.ref.number = 541
    ..item.id = 'PR_541'
    ..item.title = 'Keep the offset in the export file';
  GitHubLink link(GitHubPull p) => GitHubLink(
    host: 'github.com',
    repo: p.item.ref.repo,
    number: p.item.ref.number,
    id: p.item.id,
    pull: true,
  );
  final (d, _) = await openPullTab(
    tester,
    whole,
    size: const Size(1700, 900),
    brightness: brightness,
    more: (input) => switch (input) {
      FindChatPullRequest() => FindChatPullResponse(
        host: 'github.com',
        repo: whole.item.ref.repo,
        branch: whole.head,
        pull: link(whole),
        pulls: [link(whole), link(other)],
      ),
      GetGitHubPullRequest(:final ref) => GetGitHubPullResponse(
        pull: ref.number == 541 ? other : whole,
      ),
      _ => null,
    },
  );
  await tester.tap(find.byTooltip("The chat's pull requests"));
  await tester.pumpAndSettle();
  expect(find.byType(PullRow), findsNWidgets(2));
  return d;
}

/// What the row in [state] must hold: no cut text followed on its line by
/// a link or another cut text, the [cue] whole, Clean up… a pill.
void _check(WidgetTester tester, String state, String? cue) {
  final texts = _texts(tester);
  expect(texts, isNotEmpty);
  // A line is the texts whose boxes overlap in height, in order from
  // the left.
  for (final (p, box) in texts) {
    final after = [
      for (final (q, other) in texts)
        if (q != p &&
            other.top < box.bottom &&
            other.bottom > box.top &&
            other.left >= box.right)
          q,
    ];
    if (!p.didExceedMaxLines) continue;
    for (final q in after) {
      final words = q.text.toPlainText();
      expect(
        q.didExceedMaxLines,
        isFalse,
        reason: '"${p.text.toPlainText()}" is cut, then "$words" is cut',
      );
      expect(
        _isLink(tester, q),
        isFalse,
        reason: '"${p.text.toPlainText()}" is cut, then a link "$words"',
      );
    }
  }
  if (cue != null) {
    final shows = [
      for (final (p, _) in texts)
        if (p.text.toPlainText().contains(cue)) p,
    ];
    expect(shows, hasLength(1), reason: 'the state "$cue" shows');
    expect(shows.single.didExceedMaxLines, isFalse, reason: 'state cut');
  }
  final clean = find.descendant(
    of: find.byType(PullRow),
    matching: find.text('Clean up…'),
  );
  if (state != 'merged with Clean up') {
    expect(clean, findsNothing);
    return;
  }
  // A button with a face: a pill, its fill drawn, never bare words.
  expect(
    find.ancestor(of: clean, matching: find.byType(PillButton)),
    findsOneWidget,
  );
  final pill = find.ancestor(of: clean, matching: find.byType(PillButton));
  expect(
    find.ancestor(
      of: clean,
      matching: find.descendant(
        of: pill,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              ((w.decoration! as BoxDecoration).color?.a ?? 0) > 0,
        ),
      ),
    ),
    findsOneWidget,
  );
  expect(_isLink(tester, tester.renderObject(clean)), isFalse);
}

void main() {
  setUpAll(loadFonts);

  test('the title is 80 characters', () => expect(_title.length, 80));

  for (final MapEntry(key: state, value: (whole, cue)) in _rows.entries) {
    testWidgets('$state: no cut text is followed by a link or another cut '
        'text, the state shows whole, Clean up… has a face', (tester) async {
      final d = await _open(tester, _long(whole()), cleanUp: state != 'merged');
      try {
        expect(tester.getSize(find.byType(DetailsPanel)).width, 320);
        _check(tester, state, cue);
      } finally {
        d.dispose();
      }
    }, variant: onMac);
  }

  testWidgets('a state wider than the line alone is cut at its end, the '
      'counts gone first', (tester) async {
    final d = await _open(
      tester,
      _long(states['merged']!())
        ..base = 'export-every-sighting-date-in-its-own-site-time-zone',
      cleanUp: false,
    );
    final texts = [for (final (p, _) in _texts(tester)) p];
    final state = texts.singleWhere(
      (p) => p.text.toPlainText().startsWith('Merged into export-every'),
    );
    expect(state.didExceedMaxLines, isTrue);
    expect(
      texts.where((p) => p.text.toPlainText().contains('12840')),
      isEmpty,
      reason: 'the counts give way before the state',
    );
    d.dispose();
  }, variant: onMac);

  testWidgets('the counts give way before the state: dropped whole, never '
      'cut inside a number, the state whole after its comma', (tester) async {
    final d = await _open(tester, _long(states['merged']!()), cleanUp: false);
    final texts = [for (final (p, _) in _texts(tester)) p];
    final number = texts.singleWhere(
      (p) => p.text.toPlainText().startsWith('#537'),
    );
    final state = texts.singleWhere(
      (p) => p.text.toPlainText() == ', merged into export-in-site-zone',
    );
    expect(number.text.toPlainText(), '#537');
    expect(number.didExceedMaxLines, isFalse);
    expect(state.didExceedMaxLines, isFalse);
    expect(
      texts.where((p) => p.text.toPlainText().contains(RegExp('12840|3771'))),
      isEmpty,
      reason: 'the counts are dropped whole, not cut',
    );
    d.dispose();
  }, variant: onMac);

  testWidgets("in the Pull request tab's picker the merged row holds too", (
    tester,
  ) async {
    final d = await _picker(tester, _long(states['merged']!()));
    _check(tester, 'merged with Clean up', 'merged into export-in-site-zone');
    d.dispose();
  }, variant: onMac);

  for (final b in renderThemes) {
    final name = b.name;
    for (final (state, whole, cleanUp) in [
      ('merged-clean-up', states['merged']!, true),
      ('changes-requested', states['failing']!, true),
    ]) {
      renderTest('render: the $state row in the details panel, $name', (
        tester,
      ) async {
        final d = await _open(
          tester,
          _long(whole()),
          cleanUp: cleanUp,
          brightness: b,
        );
        // The panel's only width (DetailsPanel.width) is its narrowest and
        // its default: one picture is both.
        await render(tester, _widget, 'panel_${state}_320_$name');
        await render(tester, find.byType(NushiApp), 'window_${state}_$name');
        d.dispose();
      }, variant: onMac);
      renderTest("render: the $state row in the Pull request tab's picker, "
          '$name', (tester) async {
        final d = await _picker(tester, _long(whole()), brightness: b);
        await render(tester, find.byType(NushiApp), 'tab_${state}_$name');
        d.dispose();
      }, variant: onMac);
    }
  }
}
