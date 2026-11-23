import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/settings.dart';

import 'harness.dart';
import 'panes_app.dart';

// The Files pane squeezed (ADR 0123): in a narrow window the panes lie over
// the transcript and narrow alike, well under their least, so the pane's
// rows fold what they can't hold, and nothing overflows down to 100.

/// The errors reported while [body] runs, as text.
Future<List<String>> _errors(Future<void> Function() body) async {
  final errors = <String>[];
  final was = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.toString());
  try {
    await body();
  } finally {
    FlutterError.onError = was;
  }
  return errors;
}

/// What [error] says went wrong, and where.
String _what(String error) => error
    .split('\n')
    .where((l) => l.contains('overflowed') || l.contains('.dart:'))
    .take(2)
    .join(' ');

/// [d]'s chat c's Files pane alone, [width] wide, with Expand.
Future<void> _pane(WidgetTester tester, Daemon d, double width) async {
  await tester.pumpWidget(
    themed(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 500,
          child: FilesPane(
            chat: d.chats['c']!,
            daemon: d,
            onClose: () {},
            onExpand: () {},
          ),
        ),
      ),
      banner: false,
    ),
  );
  await tester.pumpAndSettle();
}

/// The files open in each case: none, one, two.
const _opens = <List<String>>[
  [],
  ['PLAN.md'],
  ['PLAN.md', 'NOTES.md'],
];

/// The tree as each case has it: on its side, or hidden.
const _trees = <(bool, TreeSide)>[
  (true, TreeSide.right),
  (true, TreeSide.left),
  (false, TreeSide.automatic),
];

/// Steps the pane from 500 down to 100 in each case, and gives the errors,
/// each with where it happened.
Future<List<String>> _sweep(WidgetTester tester) async {
  final (d, _) = await panesApp(tester, width: 1700);
  viewport(tester, const Size(600, 600));
  final c = d.chats['c']!;
  final found = <String>[];
  for (final (shown, side) in _trees) {
    for (final open in _opens) {
      filesTree.value = shown;
      filesTreeSide.value = side;
      c.files.tabs.value.toList().forEach(c.files.close);
      open.forEach(c.openInFiles);
      for (var w = 500.0; w >= 100; w -= 10) {
        final errors = await _errors(() => _pane(tester, d, w));
        final at = 'tree $shown ${side.name}, ${open.length} open, $w';
        found.addAll([for (final e in errors) '$at: ${_what(e)}']);
      }
    }
  }
  await closeView(tester, d);
  return found;
}

void main() {
  // The top row and the second (files_top_row.dart, files_bar.dart) fold
  // with the rest: an overflow in either is one of this sweep's errors,
  // named by its file.
  testWidgets('nothing in the pane overflows: the top row, the second, '
      'the tree’s rows', (tester) async {
    expect(await _sweep(tester), isEmpty);
  }, variant: macAndLinux);

  testWidgets('squeezed, the source button is in the ⋯', (tester) async {
    final (d, _) = await panesApp(tester, width: 1700);
    viewport(tester, const Size(600, 600));
    filesTree.value = false;
    d.chats['c']!.openInFiles('PLAN.md');
    await _pane(tester, d, 140);
    expect(find.byTooltip('View source'), findsNothing);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View source'));
    await tester.pumpAndSettle();
    expect(d.chats['c']!.files.sources, contains('PLAN.md'));
    await closeView(tester, d);
  }, variant: macAndLinux);
}
