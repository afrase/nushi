import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/related_worktrees.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/worktrees_widget.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The details panel's Worktrees widget in a window, on made-up worktrees:
// what's there is its list, what's gone is folded under one line.

const _repo = '/Users/me/acme';

RelatedWorktree _worktree(
  String branch, {
  bool gone = false,
  bool merged = false,
}) => RelatedWorktree(
  path: '$_repo/.claude/worktrees/$branch',
  branch: branch,
  baseCommit: 'b' * 40,
  lastHead: 'c' * 40,
  state: gone ? 'removed' : 'present',
  merged: merged,
);

/// The cases looked at, by name: three there and two gone (one merged),
/// all gone, one there and merged, and more than five there.
final Map<String, List<RelatedWorktree>> _cases = {
  'mixed': [
    _worktree('old-spike', gone: true),
    _worktree('login-fix', gone: true, merged: true),
    _worktree('cache-layer'),
    _worktree('docs-pass'),
    _worktree('parser-rewrite'),
  ],
  'all_gone': [
    _worktree('old-spike', gone: true),
    _worktree('login-fix', gone: true, merged: true),
    _worktree('theme-tweak', gone: true, merged: true),
  ],
  'one_merged': [_worktree('login-fix', merged: true)],
  'many': [
    for (final b in [
      'api-client',
      'billing',
      'cache-layer',
      'docs-pass',
      'export-csv',
      'feed-paging',
      'parser-rewrite',
    ])
      _worktree(b),
  ],
};

RelatedWorktreeStats _stats(String path) => path.endsWith('old-spike')
    ? RelatedWorktreeStats(path: path, commitsGone: true)
    : RelatedWorktreeStats(
        path: path,
        files: path.length % 5 + 1,
        added: path.length * 3,
        removed: path.length % 7,
        ahead: path.length % 3,
      );

/// The app at [size] on a chat whose related worktrees are [list], the
/// details panel shown and its widgets open.
Future<Daemon> _app(
  WidgetTester tester,
  List<RelatedWorktree> list,
  Size size,
  Brightness brightness,
) async {
  showDetails.value = true;
  collapsedWidgets.value = {};
  widgetOrder.value = [];
  final fake =
      FakeDaemon([chat('c', 'claude', 'Split the work', folder: _repo)])
        ..answer = (input) => switch (input) {
          GetChatRequest() => GetChatResponse(
            items: [userSays('u', 'Split the work among subagents.')],
          ),
          GetRelatedWorktreesRequest() => GetRelatedWorktreesResponse(
            worktrees: list,
          ),
          GetRelatedWorktreeStatsRequest(:final paths) =>
            GetRelatedWorktreeStatsResponse(
              stats: [for (final p in paths) _stats(p)],
            ),
          _ => null,
        };
  return await openApp(tester, fake, size: size, brightness: brightness);
}

/// The Worktrees widget on screen.
Finder get _widget => find.ancestor(
  of: find.text('Worktrees'),
  matching: find.byType(PanelWidget),
);

/// The text [name] in the widget.
Finder _in(String name) =>
    find.descendant(of: _widget, matching: find.text(name));

/// The ink [name]'s row is written in.
Color? _ink(WidgetTester tester, String name) =>
    tester.widget<Text>(_in(name)).style?.color;

/// The end word on [name]'s row.
Finder _end(String name, String end) => find.descendant(
  of: find.ancestor(of: _in(name), matching: find.byType(Column)).first,
  matching: find.text(end),
);

/// The inks of [name]'s work line ("+12 −3, 4 files"), each span's.
Set<Color?> _workInks(WidgetTester tester, String name) {
  final row = find.ancestor(of: _in(name), matching: find.byType(Column));
  final work = find.descendant(
    of: row.first,
    matching: find.textContaining('file', findRichText: true),
  );
  final inks = <Color?>{};
  tester.widget<RichText>(work.first).text.visitChildren((span) {
    if (span is TextSpan && (span.text ?? '').isNotEmpty) {
      inks.add(span.style?.color);
    }
    return true;
  });
  return inks;
}

void main() {
  setUpAll(loadFonts);

  const wide = Size(1700, 900);

  testWidgets("what's there is listed; what's gone folds under one closed "
      'line, and opened says so in muted ink', (tester) async {
    final d = await _app(tester, _cases['mixed']!, wide, Brightness.dark);
    for (final name in ['parser-rewrite', 'docs-pass', 'cache-layer']) {
      expect(_in(name), findsOne);
    }
    expect(_in('old-spike'), findsNothing);
    expect(_in('login-fix'), findsNothing);
    await tester.tap(_in('2 removed, 1 merged'));
    await tester.pumpAndSettle();
    expect(_end('old-spike', 'Removed'), findsOne);
    // In sentence case, as "Removed" beside it.
    expect(_end('old-spike', 'Commits gone'), findsOne);
    expect(_end('login-fix', 'Merged, removed'), findsOne);
    final t = NushiTheme.of(tester.element(_widget)).t;
    expect(_ink(tester, 'old-spike'), t.textMuted);
    expect(_ink(tester, 'login-fix'), t.textMuted);
    expect(_ink(tester, 'docs-pass'), t.text);
    // Still a click away: Changes on its commits.
    final chat = d.chats['c']!;
    await tester.tap(_in('old-spike'));
    await tester.pumpAndSettle();
    expect(chat.related.shown, '$_repo/.claude/worktrees/old-spike');
    expect(chat.tab.value, ChatTab.changes);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a gone row recedes whole: its work line in muted ink, a '
      "live row's counts in green and red", (tester) async {
    final d = await _app(tester, _cases['mixed']!, wide, Brightness.dark);
    await tester.tap(_in('2 removed, 1 merged'));
    await tester.pumpAndSettle();
    final t = NushiTheme.of(tester.element(_widget)).t;
    expect(_workInks(tester, 'login-fix'), {t.textMuted});
    expect(_workInks(tester, 'docs-pass'), containsAll([t.done, t.crashed]));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('all gone: only the folded line, no row of a worktree', (
    tester,
  ) async {
    final d = await _app(tester, _cases['all_gone']!, wide, Brightness.dark);
    expect(_in('3 removed, 2 merged'), findsOne);
    for (final name in ['old-spike', 'login-fix', 'theme-tweak']) {
      expect(_in(name), findsNothing);
    }
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('merged and still there reads Merged, in ink', (tester) async {
    final d = await _app(tester, _cases['one_merged']!, wide, Brightness.dark);
    expect(_end('login-fix', 'Merged'), findsOne);
    expect(_in('1 removed'), findsNothing);
    final t = NushiTheme.of(tester.element(_widget)).t;
    expect(_ink(tester, 'login-fix'), t.text);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('more than five there: five, then the rest folded', (
    tester,
  ) async {
    final d = await _app(tester, _cases['many']!, wide, Brightness.dark);
    expect(_in('2 more'), findsOne);
    expect(_in('parser-rewrite'), findsOne);
    expect(_in('billing'), findsNothing);
    expect(find.textContaining('removed'), findsNothing);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('the count line says what is there and what is gone, and the '
      'work line has no middle dot', (tester) async {
    for (final (list, summary) in [
      (_cases['mixed']!, '3, 2 removed'),
      (_cases['all_gone']!, '3 removed'),
      (_cases['many']!, '7'),
    ]) {
      final d = await _app(tester, list, wide, Brightness.dark);
      collapsedWidgets.value = {'Worktrees'};
      await tester.pumpAndSettle();
      expect(_in(summary), findsOne, reason: summary);
      collapsedWidgets.value = {};
      await tester.pumpAndSettle();
      final work = find.descendant(
        of: _widget,
        matching: find.textContaining('files', findRichText: true),
      );
      for (final e in work.evaluate()) {
        final text = (e.widget as RichText).text.toPlainText();
        expect(text, isNot(contains('·')));
        expect(text, isNot(contains(' — ')));
      }
      await closeView(tester, d);
    }
  }, variant: onMac);

  test('the folded line counts the merged', () {
    RelatedWorktree gone({bool merged = false, bool pull = false}) =>
        RelatedWorktree(state: 'removed', merged: merged, pullMerged: pull);
    expect(goneLine([gone()]), '1 removed');
    expect(goneLine([gone(), gone()]), '2 removed');
    expect(goneLine([gone(merged: true)]), '1 removed, merged');
    expect(
      goneLine([gone(merged: true), gone(pull: true)]),
      '2 removed, both merged',
    );
    expect(
      goneLine([for (var i = 0; i < 3; i++) gone(merged: true)]),
      '3 removed, all merged',
    );
    expect(
      goneLine([gone(), gone(pull: true), gone(merged: true)]),
      '3 removed, 2 merged',
    );
  });

  test('how one ended, in sentence case', () {
    RelatedWorktree w({bool gone = false, bool merged = false}) =>
        RelatedWorktree(state: gone ? 'removed' : 'present', merged: merged);
    expect(worktreeEnd(w()), '');
    expect(worktreeEnd(w(merged: true)), 'Merged');
    expect(worktreeEnd(w(gone: true)), 'Removed');
    expect(worktreeEnd(w(gone: true, merged: true)), 'Merged, removed');
  });

  // The widget on its own, its gone ones opened, is its golden.
  for (final brightness in Brightness.values) {
    testWidgets('golden: there and gone, ${brightness.name}', (tester) async {
      final d = await _app(tester, _cases['mixed']!, wide, brightness);
      await tester.tap(_in('2 removed, 1 merged'));
      await tester.pumpAndSettle();
      await expectLater(
        _widget,
        matchesGoldenFile('goldens/worktrees_widget_${brightness.name}.png'),
      );
      await closeView(tester, d);
    }, variant: onMac);

    // What a user sees first: the gone ones folded under their line.
    testWidgets('golden: the gone ones closed, ${brightness.name}', (
      tester,
    ) async {
      final d = await _app(tester, _cases['mixed']!, wide, brightness);
      expect(_in('login-fix'), findsNothing);
      await expectLater(
        _widget,
        matchesGoldenFile(
          'goldens/worktrees_widget_closed_${brightness.name}.png',
        ),
      );
      await closeView(tester, d);
    }, variant: onMac);

    // Folded whole, its count line says what's there and what's gone.
    testWidgets('golden: folded, its count line, ${brightness.name}', (
      tester,
    ) async {
      final d = await _app(tester, _cases['mixed']!, wide, brightness);
      collapsedWidgets.value = {'Worktrees'};
      await tester.pumpAndSettle();
      expect(_in('3, 2 removed'), findsOne);
      await expectLater(
        _widget,
        matchesGoldenFile(
          'goldens/worktrees_widget_folded_${brightness.name}.png',
        ),
      );
      await closeView(tester, d);
    }, variant: onMac);
  }

  // The window about 1700 wide, and the narrowest that still shows the
  // panel (it has one width: ADR 0092); with what's gone opened too.
  for (final width in [1700.0, 1080.0]) {
    for (final brightness in renderThemes) {
      final theme = brightness.name;
      for (final MapEntry(key: name, value: list) in _cases.entries) {
        renderTest('worktrees $name, ${width.toInt()} wide, $theme', (
          tester,
        ) async {
          final d = await _app(tester, list, Size(width, 900), brightness);
          expect(find.byType(DetailsPanel), findsOne);
          expect(_widget, findsOne);
          final shot = 'worktrees_${name}_${width.toInt()}_$theme';
          await render(tester, find.byType(NushiApp), shot);
          final fold = find.descendant(
            of: _widget,
            matching: find.textContaining(' removed'),
          );
          if (fold.evaluate().isNotEmpty) {
            await tester.tap(fold);
            await tester.pumpAndSettle();
            expectTextInside(tester, width);
            await render(tester, find.byType(NushiApp), '${shot}_opened');
          }
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }
}
