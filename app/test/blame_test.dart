import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/blame.dart';
import 'package:nushi/blame_gutter.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_tree.dart' show FileList;
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/source_view.dart';
import 'package:nushi/theme/theme.dart';
import 'package:re_editor/re_editor.dart';

import 'blame_cells_test.dart';
import 'change_marks_test.dart' show changeBase, changeShown;
import 'fake_daemon.dart' show FakeDaemon, loadFonts;
import 'file_edit_helpers.dart';
import 'harness.dart';

// Blame in the Files pane (issue #78): who last changed each run of a
// file's lines, in a gutter left of its numbers, in the read-only source
// and the editor; asked only while on, again as the file changes or the
// chat commits; a press opens the commit in Changes, or copies its id.

const _pad = EdgeInsets.fromLTRB(28, 22, 28, 28);

Widget _source({
  String text = changeShown,
  Blamed? blamed,
  String? base,
  bool wrap = true,
  Tokens tokens = Tokens.dark,
  ValueChanged<String>? onOpen,
  double width = 640,
  double height = 380,
  Key? key,
}) => themed(
  tokens: tokens,
  RepaintBoundary(
    key: key,
    child: SizedBox(
      width: width,
      height: height,
      child: SourceView(
        text,
        path: 'main.go',
        base: base,
        wrap: wrap,
        padding: _pad,
        blame: blamed == null
            ? null
            : BlameShown(blamed, onOpen: onOpen ?? (_) {}),
      ),
    ),
  ),
);

Finder _line(String text) => find.textContaining(text, findRichText: true);

/// The chat's folder on main: Commits lists its last commits.
Object? _onMain(Object input) => switch (input) {
  GetFolderStatusRequest() => GetFolderStatusResponse(
    git: true,
    branch: 'main',
    defaultBase: 'main',
  ),
  _ => null,
};

/// The editor on main.go, its blame [blameRuns] (or [blame] in its
/// place), [answer] first for the rest.
Future<(Daemon, FakeDaemon)> _open(
  WidgetTester tester, {
  Object? blame,
  double width = 1700,
  Brightness brightness = Brightness.light,
  Object? Function(Object input)? answer = _onMain,
}) async {
  final (d, fake) = await openEditor(
    tester,
    {'main.go': utf8.encode(changeShown)},
    width: width,
    brightness: brightness,
    answer: answer,
    fileDiffs: {
      '/Users/me/nushi/main.go': FileChange(
        path: 'main.go',
        status: 'modified',
        oldText: changeBase,
      ),
    },
  );
  fake.blames['/Users/me/nushi/main.go'] =
      blame ?? GetBlameResponse(runs: blameRuns);
  return (d, fake);
}

Iterable<GetBlameRequest> _asked(FakeDaemon fake) =>
    fake.calls.whereType<GetBlameRequest>();

Finder get _button => find.byTooltip('Show blame');
Finder get _hide => find.byTooltip('Hide blame');

Future<void> _turnOn(WidgetTester tester) async {
  await tester.tap(_button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  group('the source', () {
    for (final wrap in [true, false]) {
      testWidgets('the code moves once, by the gutter, wrapped $wrap', (
        tester,
      ) async {
        await tester.pumpWidget(_source(wrap: wrap));
        final plain = tester.getTopLeft(_line('func greet(name')).dx;
        await tester.pumpWidget(_source(wrap: wrap, blamed: Blamed.nothing));
        final waiting = tester.getTopLeft(_line('func greet(name')).dx;
        expect(waiting - plain, blameRoom + blameGap);
        await tester.pumpWidget(_source(wrap: wrap, blamed: blamed));
        expect(tester.getTopLeft(_line('func greet(name')).dx, waiting);
        // An entry a run, on its first line, beside it.
        expect(find.byType(BlameEntry), findsNWidgets(6));
        final greet = tester.getTopLeft(_line('// greet says')).dy;
        final entry = tester.getTopLeft(find.byType(BlameEntry).at(2)).dy;
        expect(entry, closeTo(greet, 1));
      });
    }

    for (final wrap in [true, false]) {
      testWidgets('a narrow pane: ages alone, the width set by the pane '
          'only, wrapped $wrap', (tester) async {
        // The full gutter would leave the code under blameCodeLeast below
        // 552 wide, whatever the file.
        final long = [for (var i = 0; i < 10000; i++) 'line $i'].join('\n');
        for (final (width, room) in [
          (400.0, blameAgeRoom),
          (551.0, blameAgeRoom),
          (552.0, blameRoom),
        ]) {
          for (final (text, first) in [
            (changeShown, 'func greet(name'),
            (long, 'line 0'),
          ]) {
            await tester.pumpWidget(
              _source(text: text, wrap: wrap, width: width),
            );
            final plain = tester.getTopLeft(_line(first)).dx;
            await tester.pumpWidget(
              _source(
                text: text,
                wrap: wrap,
                width: width,
                blamed: Blamed.nothing,
              ),
            );
            expect(
              tester.getTopLeft(_line(first)).dx - plain,
              room + blameGap,
              reason: '$width wide, ${text.length} long',
            );
            expect(
              tester.getSize(find.byType(BlameCellView).first).width,
              room,
            );
          }
        }
        await tester.pumpWidget(
          _source(wrap: wrap, width: 400, blamed: blamed),
        );
        final x = tester.getTopLeft(_line('func greet(name')).dx;
        await tester.drag(_line('func greet(name'), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byType(BlameCellView).first).dx, 28);
        expect(tester.getTopLeft(_line('func greet(name')).dx, x);
        // The name is in the hover.
        final tip = tester.widget<Tap>(
          find.descendant(
            of: find.byType(BlameEntry).at(2),
            matching: find.byType(Tap),
          ),
        );
        expect(tip.tooltip, contains('Margaret Featherstonehaugh-Applegate'));
      });
    }

    testWidgets("an entry's hover says the commit; a press opens it", (
      tester,
    ) async {
      final opened = <String>[];
      await tester.pumpWidget(_source(blamed: blamed, onOpen: opened.add));
      final tip = tester.widget<Tap>(
        find.descendant(
          of: find.byType(BlameEntry).at(2),
          matching: find.byType(Tap),
        ),
      );
      expect(
        tip.tooltip,
        'Greet by name\n'
        'Margaret Featherstonehaugh-Applegate\n'
        '2026-10-29 09:00\n'
        'b16b00b',
      );
      await tester.tap(find.byType(BlameEntry).at(2));
      expect(opened, [blameGreet]);
      // Lines not committed have no commit to open.
      await tester.tap(find.byType(BlameEntry).last);
      expect(opened, [blameGreet]);
    });

    for (final wrap in [true, false]) {
      testWidgets('10,000 lines: only those in view are built, wrapped '
          '$wrap', (tester) async {
        final text = [for (var i = 0; i < 10000; i++) 'line $i'].join('\n');
        final runs = [
          for (var i = 0; i < 10000; i++)
            blameRun(
              i + 1,
              1,
              i.isEven ? blameStart : blameGreet,
              i.isEven ? 'Ada' : 'Bo',
              const Duration(days: 3),
              'Line',
            ),
        ];
        await tester.pumpWidget(
          _source(text: text, blamed: Blamed(runs, text), wrap: wrap),
        );
        expect(find.byType(BlameCellView).evaluate().length, lessThan(40));
        await tester.drag(_line('line 3'), const Offset(0, -20000));
        await tester.pumpAndSettle();
        expect(find.byType(BlameCellView).evaluate().length, lessThan(40));
        expect(find.byType(BlameEntry), findsWidgets);
      });
    }

    for (final (name, tokens) in [
      ('light', Tokens.light),
      ('dark', Tokens.dark),
    ]) {
      testWidgets('the gutter beside change marks, $name', (tester) async {
        await tester.pumpWidget(
          _source(
            blamed: blamed,
            base: changeBase,
            tokens: tokens,
            width: 560,
            height: 300,
            key: const Key('blame'),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('blame')),
          matchesGoldenFile('goldens/blame_gutter_$name.png'),
        );
      });

      testWidgets('the narrow gutter, ages alone, $name', (tester) async {
        await tester.pumpWidget(
          _source(
            blamed: blamed,
            base: changeBase,
            tokens: tokens,
            width: 420,
            height: 300,
            key: const Key('blame'),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('blame')),
          matchesGoldenFile('goldens/blame_gutter_narrow_$name.png'),
        );
      });
    }
  });

  group('the Files pane', () {
    testWidgets('off at first: asked only once turned on, its gutter in '
        'the editor; off again, gone', (tester) async {
      final (d, fake) = await _open(tester);
      expect(_asked(fake), isEmpty);
      expect(find.byType(EditorBlame), findsNothing);
      final x = tester.getTopLeft(find.byType(DefaultCodeLineNumber)).dx;
      final button = tester.getCenter(_button);

      await _turnOn(tester);
      expect(_asked(fake).single.folder, '/Users/me/nushi');
      expect(_asked(fake).single.path, 'main.go');
      expect(find.byType(EditorBlame), findsOneWidget);
      expect(find.byType(BlameEntry), findsNWidgets(6));
      expect(
        tester.getTopLeft(find.byType(DefaultCodeLineNumber)).dx - x,
        blameRoom + blameGap,
      );
      // The button stays where it was, lit.
      expect(tester.getCenter(_hide), button);
      expect(chatC(d).files.blamed.value, {'main.go'});

      await tester.tap(_hide);
      await tester.pumpAndSettle();
      expect(find.byType(EditorBlame), findsNothing);
      expect(tester.getTopLeft(find.byType(DefaultCodeLineNumber)).dx, x);
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets("a narrow window: the editor's gutter shows ages alone", (
      tester,
    ) async {
      final (d, _) = await _open(tester, width: 720);
      final x = tester.getTopLeft(find.byType(DefaultCodeLineNumber)).dx;
      await _turnOn(tester);
      expect(find.byType(BlameEntry), findsNWidgets(6));
      expect(
        tester.getTopLeft(find.byType(DefaultCodeLineNumber)).dx - x,
        blameAgeRoom + blameGap,
      );
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets('asked again as the file changes or the chat commits, '
        'never while off', (tester) async {
      final (d, fake) = await _open(tester);
      fake.putFile('main.go', utf8.encode('$changeShown// more\n'));
      chatC(d).committed();
      await tester.pumpAndSettle();
      expect(_asked(fake), isEmpty);

      await _turnOn(tester);
      expect(_asked(fake), hasLength(1));
      fake.putFile('main.go', utf8.encode('$changeShown// and more\n'));
      await tester.pumpAndSettle();
      expect(_asked(fake), hasLength(2));
      chatC(d).committed();
      await tester.pumpAndSettle();
      expect(_asked(fake), hasLength(3));
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets('an unsaved line reads as not committed once typing '
        'pauses', (tester) async {
      final (d, _) = await _open(tester);
      await _turnOn(tester);
      final e = editOf(d);
      e.controller.selection = const CodeLineSelection.collapsed(
        index: 0,
        offset: 0,
      );
      await typeIn(tester, e, '// top\n');
      await tester.pump(Waits.typing);
      await tester.pump();
      await tester.pump();
      final blame = tester.widget<EditorBlame>(find.byType(EditorBlame));
      expect(blame.cells.value.first.run, isNull);
      expect(blame.cells.value[1].commit, blameStart);
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets('a rendered file: Blame shows its source, and going back '
        'to the rendering turns Blame off', (tester) async {
      final (d, fake) = await openEditor(
        tester,
        {'README.md': utf8.encode('# Notes\n\nSome words.\n')},
        open: ['README.md'],
        readOnly: {'README.md'},
      );
      fake.blames['/Users/me/nushi/README.md'] = GetBlameResponse(
        runs: [
          blameRun(1, 3, blameStart, 'Ada', const Duration(days: 3), 'Notes'),
        ],
      );
      await _turnOn(tester);
      expect(chatC(d).files.blamed.value, {'README.md'});
      expect(find.byType(BlameEntry), findsOneWidget);
      expect(_asked(fake), hasLength(1));

      await tester.tap(find.byType(SourceButton));
      await tester.pumpAndSettle();
      expect(chatC(d).files.blamed.value, isEmpty);
      expect(_hide, findsNothing);
      expect(_button, findsOneWidget);
      chatC(d).committed();
      await tester.pumpAndSettle();
      expect(_asked(fake), hasLength(1));
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets('JSON shown reformatted: no blame, said in the path row, '
        'and no empty gutter', (tester) async {
      final (d, fake) = await openEditor(
        tester,
        {'data.json': utf8.encode('{"a":1,"b":[1,2,3]}\n')},
        open: ['data.json'],
        readOnly: {'data.json'},
      );
      fake.blames['/Users/me/nushi/data.json'] = GetBlameResponse(
        runs: [
          blameRun(1, 1, blameStart, 'Ada', const Duration(days: 3), 'Data'),
        ],
      );
      final before = tester.getTopLeft(_line('"a"'));
      await _turnOn(tester);
      expect(
        find.descendant(
          of: find.byType(PathLine),
          matching: find.text('Shown reformatted: no blame'),
        ),
        findsOneWidget,
      );
      expect(find.byType(BlameEntry), findsNothing);
      expect(tester.getTopLeft(_line('"a"')), before);
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets('"Blaming…" while it takes a moment', (tester) async {
      final answer = Completer<Object>();
      final (d, _) = await _open(tester, blame: answer.future);
      await tester.tap(_button);
      await tester.pump();
      expect(find.text('Blaming…'), findsNothing);
      await tester.pump(Waits.slow);
      expect(find.text('Blaming…'), findsOneWidget);
      answer.complete(GetBlameResponse(runs: blameRuns));
      await tester.pumpAndSettle();
      expect(find.text('Blaming…'), findsNothing);
      expect(find.byType(BlameEntry), findsNWidgets(6));
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets('no blame says why, in the path row', (tester) async {
      final (d, _) = await _open(
        tester,
        blame: GetBlameResponse(noneReason: 'untracked'),
      );
      await _turnOn(tester);
      expect(
        find.descendant(
          of: find.byType(PathLine),
          matching: find.text('Not committed yet'),
        ),
        findsOneWidget,
      );
      expect(find.byType(BlameEntry), findsNothing);
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets('a daemon without GetBlame: no Blame', (tester) async {
      final (d, _) = await _open(tester);
      d.daemonApi = blameApi - 1;
      final files = chatC(d).files;
      files.close(files.shown.value!);
      await tester.pumpAndSettle();
      chatC(d).openInFiles('main.go');
      await tester.pumpAndSettle();
      expect(_button, findsNothing);
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets("a press opens the commit in Changes' Commits", (tester) async {
      final (d, _) = await _open(
        tester,
        answer: (input) => switch (input) {
          ListCommitsRequest() => ListCommitsResponse(
            commits: [
              Commit(
                hash: blameGreet,
                short: 'b16b00b',
                subject: 'Greet by name',
              ),
            ],
          ),
          _ => _onMain(input),
        },
      );
      await _turnOn(tester);
      await tester.tap(find.byType(BlameEntry).at(2));
      await tester.pumpAndSettle();
      final c = chatC(d);
      expect(c.tab.value, ChatTab.changes);
      expect(c.scope, 'commits');
      expect(c.openCommit, isNull); // Changes took it
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets("one Commits doesn't list: its id copied, and said", (
      tester,
    ) async {
      final copied = clipboardCopies(tester);
      final (d, _) = await _open(tester);
      await _turnOn(tester);
      await tester.tap(find.byType(BlameEntry).first);
      await tester.pumpAndSettle();
      expect(copied, [blameStart]);
      expect(
        find.text('Copied c0ffee1: Changes’ Commits doesn’t list it'),
        findsOneWidget,
      );
      expect(chatC(d).tab.value, ChatTab.chat);
      await tester.pump(const Duration(seconds: 5));
      await endEditor(tester, d);
    }, variant: onMac);

    testWidgets("Changes' file menu: Blame opens the file with Blame on", (
      tester,
    ) async {
      final (d, fake) = await _open(
        tester,
        answer: (input) => switch (input) {
          GetDiffRequest(:final path, names: false)
              when path.isEmpty && input.base.isEmpty =>
            GetDiffResponse(
              files: [
                FileChange(
                  path: 'main.go',
                  status: 'modified',
                  oldText: changeBase,
                  newText: changeShown,
                  added: 3,
                  removed: 2,
                ),
              ],
            ),
          _ => _onMain(input),
        },
      );
      final c = chatC(d);
      c.tab.value = ChatTab.changes;
      await tester.pumpAndSettle();
      final row = find
          .descendant(
            of: find.byType(FileList),
            matching: find.textContaining('main.go', findRichText: true),
          )
          .first;
      await tester.tap(row, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blame'));
      await tester.pumpAndSettle();
      expect(c.tab.value, ChatTab.chat);
      expect(c.files.blamed.value, {'main.go'});
      expect(_asked(fake), hasLength(1));
      expect(find.byType(EditorBlame), findsOneWidget);
      await endEditor(tester, d);
    }, variant: onMac);
  });

  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    for (final width in [1700.0, 720.0]) {
      final w = width.toInt();
      renderTest('renders: Blame off and on, its hover, $w, $theme', (
        tester,
      ) async {
        final (d, _) = await _open(
          tester,
          width: width,
          brightness: brightness,
        );
        final app = find.byType(NushiApp);
        await render(tester, app, 'blame_${w}_off_$theme');
        await _turnOn(tester);
        expectTextInside(tester, width);
        await render(tester, app, 'blame_${w}_on_$theme');
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(BlameEntry).at(2)));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Greet by name'), findsOneWidget);
        await render(tester, app, 'blame_${w}_hover_$theme');
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        await mouse.removePointer();
        await endEditor(tester, d);
      }, variant: onMac);
    }
  }
}
