// The Artifacts widget takes in the files a Claude workflow's agents wrote
// (Workflow.written, API 156): among the chat's own by when they changed,
// the run that changed one last named in its tooltip, with no mark on the
// row.
import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/artifacts_widget.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _m = Duration(minutes: 1);

/// A write of the chat's own that ended [ago] before now.
Item _wrote(String id, String path, Duration ago) =>
    wrote(id, path)..ended = msAgo(ago);

/// The chat's report and chart, then a workflow that writes an audit and
/// its chart and edits the chat's report again.
List<Item> _items({String name = 'audit-docs', bool written = true}) => [
  userSays('u', 'Write the report, then audit the docs.'),
  _wrote('w1', 'docs/report.md', _m * 40),
  _wrote('w2', 'docs/img/chart.png', _m * 30),
  workflowWrote('wf', name, [
    if (written) ...[
      ('docs/report.md', _m * 3),
      ('audit/summary.md', _m * 8),
      ('audit/coverage.svg', _m * 12),
    ],
  ], state: 'done')..ended = msAgo(_m * 2),
];

/// The app on a chat with [items], the details panel shown, at [size],
/// each file changed as [changed] says (5 minutes ago unless it does).
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester,
  List<Item> items, {
  Size size = const Size(1700, 900),
  DateTime? Function(String path)? changed,
  bool Function(String folder)? there,
}) async {
  showDetails.value = true;
  sidebarHidden.value = true;
  final was = fileChanged;
  final wasThere = folderThere;
  // No file is on disk: a time for each, by how long ago its write was,
  // and every folder there.
  fileChanged = changed ?? (p) => clock().subtract(_m * 5);
  folderThere = there ?? (_) => true;
  addTearDown(() {
    fileChanged = was;
    folderThere = wasThere;
  });
  final c = chat('c', 'claude', 'Report and audit');
  final fake = FakeDaemon([c])
    ..on(
      (input) => switch (input) {
        GetChatRequest() => GetChatResponse(chat: c, items: items),
        _ => null,
      },
    );
  final d = await openApp(tester, fake, size: size);
  return (d, fake);
}

Finder get _rows => find.byType(FileRows);

Finder _inRows(Finder f) => find.descendant(of: _rows, matching: f);

/// The names the widget lists, top to bottom.
List<String> _names() => [
  for (final e in _inRows(find.byType(Text)).evaluate())
    if ((e.widget as Text).data case final s? when s.contains('.')) s,
];

Finder _row(String name) =>
    find.ancestor(of: _inRows(find.text(name)), matching: find.byType(Tap));

String _tip(WidgetTester tester, String name) =>
    tester.widget<Tap>(_row(name).first).tooltip;

void main() {
  setUpAll(loadFonts);

  testWidgets("a workflow's files are rows among the chat's own by when "
      'they changed; one both wrote is one row; each says the run that '
      'wrote it', (tester) async {
    final (d, _) = await _app(tester, _items());
    expect(_names(), ['report.md', 'summary.md', 'coverage.svg', 'chart.png']);
    expect(_inRows(find.text('report.md')), findsOneWidget);
    expect(
      _tip(tester, 'summary.md'),
      'audit/summary.md, 5m ago\nWritten by the workflow audit-docs',
    );
    expect(
      _tip(tester, 'report.md'),
      'docs/report.md, 5m ago\nWritten by the workflow audit-docs',
    );
    expect(_tip(tester, 'chart.png'), 'docs/img/chart.png, 5m ago');
    // No mark: the workflow's glyph is the Diagram kind's and a worktree's.
    expect(_inRows(find.byIcon(Icons.account_tree_outlined)), findsNothing);
    final row = tester.getRect(_row('summary.md').first);
    final kind = tester.getRect(
      find.descendant(
        of: _row('summary.md').first,
        matching: find.text('Markdown'),
      ),
    );
    expect(kind.right, closeTo(row.right - 6, 1));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a run with no name yet is named as its card names it; a '
      'file the chat changed after the run names no run', (tester) async {
    final (d, _) = await _app(tester, [
      ..._items(name: ''),
      _wrote('w3', 'audit/summary.md', _m),
    ]);
    expect(
      _tip(tester, 'coverage.svg'),
      'audit/coverage.svg, 5m ago\nWritten by the workflow wf_wf',
    );
    expect(_tip(tester, 'summary.md'), 'audit/summary.md, 5m ago');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a workflow with no written files (as a daemon before '
      "workflowWrittenApi sends one) lists the chat's own only, none "
      'named as a run', (tester) async {
    final (d, _) = await _app(tester, _items(written: false));
    expect(_names(), ['chart.png', 'report.md']);
    expect(_tip(tester, 'report.md'), 'docs/report.md, 5m ago');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a running workflow's files join the widget as its events "
      'bring them', (tester) async {
    final items = [
      userSays('u', 'Audit the docs.'),
      _wrote('w1', 'docs/report.md', _m * 40),
      workflowWrote('wf', 'audit-docs', const []),
    ];
    final (d, fake) = await _app(tester, items);
    expect(_names(), ['report.md']);
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1),
        item: ItemEvent(
          item: workflowWrote('wf', 'audit-docs', [
            ('audit/summary.md', Duration.zero),
          ]),
          index: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_names(), ['summary.md', 'report.md']);
    expect(_tip(tester, 'summary.md'), contains('the workflow audit-docs'));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a path's and a run's bidi and control characters are "
      "dropped: the row's name, the tooltip's path and the run's name", (
    tester,
  ) async {
    const evil = 'audit/evil\u202Etxt.md';
    const tabbed = 'docs/tab\there\x1b[31m.md';
    final (d, _) = await _app(tester, [
      userSays('u', 'Audit.'),
      _wrote('w1', tabbed, _m * 9),
      workflowWrote('wf', 'aud\u2066it\u0007', [(evil, _m * 3)], state: 'done')
        ..ended = msAgo(_m * 2),
    ]);
    expect(_names(), ['eviltxt.md', 'tab here[31m.md']);
    expect(
      _tip(tester, 'eviltxt.md'),
      'audit/eviltxt.md, 5m ago\nWritten by the workflow audit',
    );
    expect(_tip(tester, 'tab here[31m.md'), 'docs/tab here[31m.md, 5m ago');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the run's card and its Background tasks row name it as the "
      "row's tooltip does, plain", (tester) async {
    final (d, _) = await _app(tester, [
      userSays('u', 'Audit.'),
      workflowWrote('wf', 'aud\u202Eit\nrun', [('audit/a.md', _m * 3)]),
    ]);
    expect(_tip(tester, 'a.md'), endsWith('Written by the workflow audit run'));
    expect(
      find.text('Workflow: audit run', findRichText: true),
      findsOneWidget,
    );
    final tasks = find.ancestor(
      of: find.text('Background tasks'),
      matching: find.byType(PanelWidget),
    );
    expect(
      find.descendant(of: tasks, matching: find.text('audit run')),
      findsOneWidget,
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a long path's tooltip wraps at its width, not the "
      "window's", (tester) async {
    final long = 'docs/${'a' * 280}.md';
    final (d, _) = await _app(tester, [
      userSays('u', 'Write it.'),
      _wrote('w1', long, _m),
    ]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(_rows));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final tip = find.text('$long, 5m ago', findRichText: true);
    expect(tip, findsOneWidget);
    expect(tester.getSize(tip).width, lessThanOrEqualTo(fileTipWidth));
    expect(tester.getSize(tip).height, greaterThan(40)); // it wrapped
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('rows hold still under the pointer while a running '
      'workflow adds files; what came shows once it leaves; a row opened '
      'from the keyboard holds nothing', (tester) async {
    List<(String, Duration)> found(int n) => [
      for (var i = 0; i < n; i++) ('audit/finding-$i.md', _m * (10 + i)),
    ];
    final (d, fake) = await _app(tester, [
      userSays('u', 'Audit the docs.'),
      workflowWrote('wf', 'audit-docs', found(4)),
    ]);
    Future<void> wrote(int seq, String path) async {
      fake.emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(seq),
          item: ItemEvent(
            item: workflowWrote('wf', 'audit-docs', [
              (path, Duration(seconds: seq)),
              ...found(4),
            ]),
            index: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final before = _names();
    expect(before.take(2), ['finding-0.md', 'finding-1.md']);
    final at = tester.getCenter(_row('finding-1.md').first);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    await wrote(2, 'audit/new.md');
    expect(_names(), before);
    expect(tester.getCenter(_row('finding-1.md').first), at);
    await mouse.down(at);
    await mouse.up();
    await tester.pumpAndSettle();
    // The click opened the file under the pointer (the Files pane opening
    // moves the panel from under it).
    expect(d.chats['c']!.shownFile, 'audit/finding-1.md');
    // Gone from the widget, the pointer lets what came show.
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(_names().first, 'new.md');
    // Only the pointer holds them: a row reached from the keyboard and
    // opened with Enter keeps the focus, and the list still follows.
    final row = _row('finding-1.md').first;
    Focus.of(
      tester.element(
        find.descendant(of: row, matching: find.byType(Text)).first,
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(d.chats['c']!.shownFile, 'audit/finding-2.md');
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<FileRows>(),
      isNotNull,
    );
    await wrote(3, 'audit/newer.md');
    expect(_names().first, 'newer.md');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('at 1000 files Show more opens 50, the rest in Artifacts…; '
      'no event or minute stats more than the rows shown', (tester) async {
    List<(String, Duration)> files(int shift) => [
      for (var i = 0; i < 1000; i++)
        ('audit/f$i.md', Duration(minutes: 10, seconds: i + shift)),
    ];
    var stats = 0;
    final (d, fake) = await _app(
      tester,
      [userSays('u', 'Audit.'), workflowWrote('wf', 'audit', files(0))],
      changed: (p) {
        stats++;
        return clock().subtract(_m * 5);
      },
    );
    expect(stats, shownFiles);
    stats = 0;
    await tester.tap(_inRows(find.text('Show more')));
    await tester.pumpAndSettle();
    expect(_names(), hasLength(moreFiles));
    expect(stats, lessThanOrEqualTo(moreFiles));
    for (var seq = 1; seq <= 3; seq++) {
      stats = 0;
      fake.emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(seq),
          item: ItemEvent(
            item: workflowWrote('wf', 'audit', files(-seq)),
            index: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(stats, lessThanOrEqualTo(moreFiles));
    }
    stats = 0;
    await tester.pump(const Duration(minutes: 1));
    expect(stats, lessThanOrEqualTo(moreFiles));
    await tester.ensureVisible(_inRows(find.text('Show all in Artifacts…')));
    await tester.pumpAndSettle();
    await tester.tap(_inRows(find.text('Show all in Artifacts…')));
    await tester.pumpAndSettle();
    expect(find.byType(Palette), findsOneWidget);
    expect(tester.widget<Palette>(find.byType(Palette)).rows, hasLength(1000));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a file no longer there is a muted row that says Gone, with '
      'no pin; the '
      "files of a worktree removed since aren't listed, its folder checked "
      'once, and again after a minute; the count agrees', (tester) async {
    const wt = '/Users/me/worktrees/audit-merged';
    const kept = '/Users/me/worktrees/audit-open';
    // Claude's own worktree, under the chat's folder: named relative to it.
    const inner = '/Users/me/nushi/.claude/worktrees/audit-inner';
    final checked = <String>[];
    var keptGone = false;
    final (d, fake) = await _app(
      tester,
      [
        userSays('u', 'Audit the docs.'),
        _wrote('w1', 'docs/report.md', _m * 40),
        _wrote('w2', 'docs/gone.md', _m * 30),
        workflowWrote('wf', 'audit-docs', [
          ('$wt/audit/a.md', _m * 4),
          ('$wt/audit/b.md', _m * 5),
          ('$wt/c.md', _m * 6),
          ('$kept/audit/d.md', _m * 7),
          ('$inner/e.md', _m * 8),
          ('$inner/notes/f.md', _m * 9),
        ], state: 'done')..ended = msAgo(_m * 2),
      ],
      changed: (p) =>
          p.contains('gone') || p.startsWith(wt) || p.startsWith(inner)
          ? null
          : clock().subtract(_m * 5),
      there: (f) {
        checked.add(f);
        return !f.startsWith(wt) &&
            !f.startsWith(inner) &&
            !(keptGone && f.startsWith(kept));
      },
    );
    expect(_names(), ['d.md', 'gone.md', 'report.md']);
    expect(checked..sort(), [
      inner,
      '$inner/notes',
      '/Users/me/nushi/docs',
      wt,
      '$wt/audit',
      '$kept/audit',
    ]);
    expect(_tip(tester, 'gone.md'), 'docs/gone.md\nNot there any more');
    Text name(String n) => tester.widget<Text>(_inRows(find.text(n)));
    final t = NushiTheme.of(tester.element(_rows)).t;
    expect(name('gone.md').style!.color, t.textMuted);
    expect(name('report.md').style!.color, t.text);
    // Its kind's slot says so in words, muted, and it offers no pin.
    Finder inRow(String n, Finder f) =>
        find.descendant(of: _row(n).first, matching: f);
    expect(inRow('gone.md', find.text('Markdown')), findsNothing);
    final word = tester.widget<Text>(inRow('gone.md', find.text('Gone')));
    expect(word.style!.color, t.textMuted);
    expect(inRow('report.md', find.text('Markdown')), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(_row('gone.md').first));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    expect(
      inRow('gone.md', find.byIcon(Icons.push_pin_outlined)),
      findsNothing,
    );
    await mouse.moveTo(tester.getCenter(_row('report.md').first));
    await tester.pumpAndSettle();
    expect(
      inRow('report.md', find.byIcon(Icons.push_pin_outlined)),
      findsOneWidget,
    );
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    // An event checks no folder again; a minute on, each once more.
    checked.clear();
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(1),
        item: ItemEvent(item: _wrote('w3', 'docs/more.md', _m), index: 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(checked, isEmpty);
    expect(_names(), ['more.md', 'd.md', 'gone.md', 'report.md']);
    // Collapsed, it counts what it lists.
    await tester.tap(find.text('Artifacts'));
    await tester.pumpAndSettle();
    Finder count(String n) => find.descendant(
      of: find.ancestor(
        of: find.text('Artifacts'),
        matching: find.byType(PanelWidget),
      ),
      matching: find.text(n),
    );
    expect(count('4'), findsOneWidget);
    // The other worktree goes too: a minute on, each folder is looked at
    // once more, and the count follows with no rows shown.
    keptGone = true;
    final was = clock;
    clock = () => was().add(_m);
    addTearDown(() => clock = was);
    await tester.pump(_m);
    expect(checked, hasLength(6));
    expect(count('3'), findsOneWidget);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("collapsed, the count follows the minute's look at a "
      'folder on its own, with nothing else building it', (tester) async {
    const wt = '/Users/me/worktrees/audit-merged';
    var gone = false;
    final was = (fileChanged, folderThere, clock);
    fileChanged = (p) => clock().subtract(_m * 5);
    folderThere = (f) => !(gone && f.startsWith(wt));
    final c = ChatState('c', '/Users/me/nushi')
      ..load(
        GetChatResponse(
          items: [
            userSays('u', 'Audit the docs.'),
            _wrote('w1', 'docs/report.md', _m * 40),
            workflowWrote('wf', 'audit-docs', [
              ('$wt/a.md', _m * 4),
            ], state: 'done'),
          ],
          seq: Int64(1),
        ),
      );
    addTearDown(() {
      fileChanged = was.$1;
      folderThere = was.$2;
      clock = was.$3;
    });
    await tester.pumpWidget(themed(artifactsWidget(c)!.summary!));
    expect(find.text('2'), findsOneWidget);
    gone = true;
    clock = () => was.$3().add(_m);
    await tester.pump(_m);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('a chat whose every file is in a removed worktree has no '
      'Artifacts widget', (tester) async {
    final (d, _) = await _app(
      tester,
      [
        userSays('u', 'Audit the docs.'),
        workflowWrote('wf', 'audit-docs', [
          ('/Users/me/worktrees/audit-merged/a.md', _m),
        ], state: 'done'),
      ],
      changed: (p) => null,
      there: (f) => false,
    );
    expect(_rows, findsNothing);
    await closeView(tester, d);
  }, variant: onMac);

  for (final mode in Brightness.values) {
    testWidgets("golden: the widget with a workflow's files and one no "
        'longer there, ${mode.name}', (tester) async {
      final (d, _) = await _app(
        tester,
        [_wrote('w0', 'docs/draft.md', _m * 50), ..._items()],
        changed: (p) =>
            p.endsWith('draft.md') ? null : clock().subtract(_m * 5),
      );
      tester.platformDispatcher.platformBrightnessTestValue = mode;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      await expectLater(
        find.ancestor(of: _rows, matching: find.byType(PanelWidget)),
        matchesGoldenFile('goldens/artifacts_workflow_${mode.name}.png'),
      );
      await closeView(tester, d);
    }, variant: onMac);
  }

  for (final (width, label) in [(1700.0, 'wide'), (860.0, 'narrow')]) {
    renderTest("render: the details panel with a workflow's files, "
        '$label', (tester) async {
      for (final mode in renderThemes) {
        // The chat's own and a workflow's files, a diagram, one no longer
        // there, and a removed worktree's two, which aren't listed.
        const merged = '/Users/me/worktrees/audit-merged';
        final (d, _) = await _app(
          tester,
          [
            _wrote('w0', 'docs/draft.md', _m * 50),
            ..._items(),
            _wrote('w4', 'docs/flow.mmd', _m),
            workflowWrote('wf2', 'triage', [
              ('$merged/triage.md', _m),
              ('$merged/notes/list.md', _m * 2),
            ], state: 'done'),
          ],
          size: Size(width, 900),
          changed: (p) => p.endsWith('draft.md') || p.startsWith(merged)
              ? null
              : clock().subtract(_m * 5),
          there: (f) => !f.startsWith(merged),
        );
        tester.platformDispatcher.platformBrightnessTestValue = mode;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pumpAndSettle();
        expect(find.byType(DetailsPanel), findsOneWidget);
        // Opened, so the gone file's row shows; the worktree's aren't
        // there.
        await tester.tap(_inRows(find.text('Show more')));
        await tester.pumpAndSettle();
        expect(_names(), hasLength(6));
        await render(
          tester,
          find.byType(NushiApp),
          'artifacts_workflow_${label}_${mode.name}',
        );
        await closeView(tester, d);
      }
    }, variant: onMac);
  }
}
