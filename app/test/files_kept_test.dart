import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_tabs.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/files_top_row.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show EventsResponse;
import 'package:nushi/main.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart' show FakeDaemon;
import 'harness.dart';
import 'panes_app.dart';

// A chat's Files pane and file tabs kept across launches (ADR 0070's and
// 0123's amendments of 2026-11-19): Nushi restarts for each update.

const _all = {'PLAN.md', 'auth/redirect.go', 'NOTES.md'};

List<String> _tabs(Daemon d) => [
  for (final f in d.chats['c']!.files.tabs.value) f.path,
];

String? _shown(Daemon d) => d.chats['c']!.files.shown.value?.path;

/// The files still there, for a FindChatFiles that fails while [fails]
/// (the connection lost as it's asked).
final class _Flaky extends SetBase<String> {
  bool fails = true;

  @override
  bool contains(Object? element) =>
      fails ? throw StateError('lost') : _all.contains(element);

  @override
  bool add(String value) => throw UnsupportedError('read only');
  @override
  bool remove(Object? value) => throw UnsupportedError('read only');
  @override
  String? lookup(Object? element) => contains(element) ? '$element' : null;
  @override
  Iterator<String> get iterator => _all.iterator;
  @override
  int get length => _all.length;
  @override
  Set<String> toSet() => {..._all};
}

/// Quits [d] and launches again, the prefs read from `app.json` as a new
/// launch reads them, with the files [found] still there.
Future<(Daemon, FakeDaemon)> _relaunch(
  WidgetTester tester,
  Daemon d, {
  Set<String> found = _all,
  double width = 1700,
}) async {
  await closeView(tester, d);
  final saved = readSaved();
  fileTabsKept.readFrom(saved);
  final app = await panesApp(tester, width: width, found: found);
  filesChats.value = {...?(saved['files'] as List<Object?>?)?.cast<String>()};
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final width in [1700.0, 720.0]) {
    testWidgets('the tabs and the one showing come back, $width wide', (
      tester,
    ) async {
      var (d, _) = await panesApp(tester, width: width);
      final c = d.chats['c']!;
      showOrHideFiles(c);
      ['PLAN.md', 'auth/redirect.go', 'NOTES.md'].forEach(c.openInFiles);
      c
        ..openInFiles('auth/redirect.go')
        ..files.showSource('PLAN.md', on: true);
      await tester.pumpAndSettle();
      // As opened by hand, to set beside the render after the relaunch.
      await render(
        tester,
        find.byType(NushiApp),
        'files_hand_${width.round()}',
      );

      (d, _) = await _relaunch(tester, d, width: width);
      expect(filesOpen(d.chats['c']!), isTrue);
      expect(_tabs(d), ['PLAN.md', 'auth/redirect.go', 'NOTES.md']);
      expect(_shown(d), 'auth/redirect.go');
      expect(d.chats['c']!.files.sources, {'PLAN.md'});
      expect(find.byType(FilesPane), findsOneWidget);
      for (final name in ['PLAN.md', 'redirect.go', 'NOTES.md']) {
        expect(
          find.descendant(
            of: find.byType(FilesTopRow),
            matching: find.text(name),
          ),
          findsOneWidget,
        );
      }
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(NushiApp),
        'files_kept_${width.round()}',
      );
      await closeView(tester, d);
    }, variant: onMac);
  }

  testWidgets('a restore that fails keeps the tabs for later, and the '
      'next word of the chat tries again', (tester) async {
    var (d, _) = await panesApp(tester, width: 1700);
    ['PLAN.md', 'NOTES.md'].forEach(d.chats['c']!.openInFiles);
    await tester.pumpAndSettle();

    final found = _Flaky();
    final FakeDaemon fake;
    (d, fake) = await _relaunch(tester, d, found: found);
    expect(_tabs(d), isEmpty);
    // A tab opened meanwhile doesn't replace those kept…
    d.chats['c']!.openInFiles('auth/redirect.go');
    await tester.pumpAndSettle();
    expect(fileTabsKept.value['c']!.tabs, ['PLAN.md', 'NOTES.md']);

    // …and the chat's next event, the daemon back, restores them.
    found.fails = false;
    final c = fake.chats.firstWhere((c) => c.id == 'c');
    fake.emit(EventsResponse(chatId: 'c', chat: c));
    await tester.pumpAndSettle();
    expect(_tabs(d), ['PLAN.md', 'NOTES.md', 'auth/redirect.go']);
    expect(fileTabsKept.value['c']!.tabs, [
      'PLAN.md',
      'NOTES.md',
      'auth/redirect.go',
    ]);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a file gone since doesn’t come back; the next tab shows in '
      'the place of a gone one that showed', (tester) async {
    var (d, _) = await panesApp(tester, width: 1700);
    final c = d.chats['c']!;
    ['PLAN.md', 'auth/redirect.go', 'NOTES.md'].forEach(c.openInFiles);
    c.openInFiles('auth/redirect.go');
    await tester.pumpAndSettle();

    (d, _) = await _relaunch(tester, d, found: {'PLAN.md', 'NOTES.md'});
    expect(_tabs(d), ['PLAN.md', 'NOTES.md']);
    expect(_shown(d), 'NOTES.md');
    // What's kept now has the gone file left out.
    expect(fileTabsKept.value['c']!.tabs, ['PLAN.md', 'NOTES.md']);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('with every file gone the pane comes back with no tabs', (
    tester,
  ) async {
    var (d, _) = await panesApp(tester, width: 1700);
    d.chats['c']!.openInFiles('PLAN.md');
    await tester.pumpAndSettle();

    (d, _) = await _relaunch(tester, d, found: {});
    expect(filesOpen(d.chats['c']!), isTrue);
    expect(_tabs(d), isEmpty);
    expect(_shown(d), isNull);
    expect(fileTabsKept.value, isNot(contains('c')));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a pane a file’s opening opened comes back, its tab too', (
    tester,
  ) async {
    var (d, _) = await panesApp(tester, width: 1700);
    d.chats['c']!.openInFiles('PLAN.md');
    await tester.pumpAndSettle();
    expect(readSaved()['files'], ['c']);

    (d, _) = await _relaunch(tester, d);
    expect(filesOpen(d.chats['c']!), isTrue);
    expect(_tabs(d), ['PLAN.md']);
    expect(_shown(d), 'PLAN.md');
    expect(find.byType(FilesPane), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a tab closed, or the pane, stays so', (tester) async {
    var (d, _) = await panesApp(tester, width: 1700);
    final c = d.chats['c']!
      ..openInFiles('PLAN.md')
      ..openInFiles('NOTES.md');
    c.files.close(const PreviewFile('PLAN.md'));
    showOrHideFiles(c); // hides the pane, keeping its tabs
    await tester.pumpAndSettle();

    (d, _) = await _relaunch(tester, d);
    expect(filesOpen(d.chats['c']!), isFalse);
    expect(_tabs(d), ['NOTES.md']);
    expect(_shown(d), 'NOTES.md');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a provisional tab comes back provisional', (tester) async {
    var (d, _) = await panesApp(tester, width: 1700);
    d.chats['c']!
      ..openInFiles('PLAN.md')
      ..openInFiles('NOTES.md', keep: false);
    await tester.pumpAndSettle();

    (d, _) = await _relaunch(tester, d);
    expect(
      d.chats['c']!.files.provisional.value,
      const PreviewFile('NOTES.md'),
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a tab is kept by its name in the chat’s folder, however it '
      'was opened', (tester) async {
    final (d, _) = await panesApp(tester, width: 1700);
    d.chats['c']!.openInFiles('/Users/me/nushi/./auth//redirect.go');
    await tester.pumpAndSettle();
    expect((readSaved()['fileTabs']! as Map)['c'], {
      'tabs': ['auth/redirect.go'],
      'shown': 'auth/redirect.go',
    });
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a gone chat’s tabs are dropped', (tester) async {
    fileTabsKept.value = {
      'gone': const KeptTabs(['PLAN.md'], shown: 'PLAN.md'),
    };
    await tester.pumpAndSettle();
    expect((readSaved()['fileTabs']! as Map).keys, ['gone']);
    final (d, _) = await panesApp(tester, width: 1700);
    expect(fileTabsKept.value, isEmpty);
    expect(readSaved()['fileTabs'], isEmpty);
    await closeView(tester, d);
  }, variant: onMac);

  test('what’s saved is read without throwing; a wrong part is left out', () {
    fileTabsKept.readFrom({
      'fileTabs': {
        'a': {
          'tabs': ['x.md', 3, '', 'y.md', 'x.md'],
          'shown': 'z.md',
          'provisional': 'y.md',
          'sources': ['x.md', 'q.md'],
        },
        'b': {'tabs': <Object?>[]},
        'c': 'nonsense',
      },
    });
    final kept = fileTabsKept.value;
    expect(kept.keys, ['a']);
    expect(kept['a']!.json, {
      'tabs': ['x.md', 'y.md'],
      'provisional': 'y.md',
      'sources': ['x.md'],
    });
  });
}
