import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/files_bar.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/source_editor.dart';

import 'fake_daemon.dart' show loadFonts;
import 'file_edit_helpers.dart';
import 'harness.dart';
import 'panes_app.dart';

// Full windows of the Files pane's options to look at, as Claude desktop
// has them (ADR 0123): its ⋯, the tree on each side or hidden, preview
// tabs, indent guides, whitespace, tab sizes, scrolling past the end and
// the tree button's tooltip, in both themes. Written only with
// NUSHI_RENDERS set; never compared.

/// The renders' names' start: Linux's say so.
String get _at =>
    defaultTargetPlatform == TargetPlatform.linux ? 'fo_linux' : 'fo';

const PanesOpen _files = (
  side: false,
  files: true,
  subagent: false,
  command: false,
  previews: 0,
  browser: 0,
);

/// Go, indented with tabs, long enough to scroll.
final String _go = [
  tabbed,
  for (var i = 0; i < 40; i++)
    'func step$i() {\n\tif ready {\n\t\tpour($i)\n\t}\n}\n',
].join('\n');

Finder get _more => find.descendant(
  of: find.byType(FilesBar),
  matching: find.byTooltip('More'),
);

Finder get _treeButton => find.descendant(
  of: find.byType(FilesBar),
  matching: find.byWidgetPredicate(
    (w) => w is IconTap && w.line == LineIcon.fileTree,
  ),
);

void main() {
  setUpAll(loadFonts);

  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    for (final width in [1700.0, 720.0]) {
      final w = width.toInt();
      renderTest('the panes and the menu, $w, $theme', (tester) async {
        final (d, _) = await panesApp(
          tester,
          width: width,
          details: false,
          brightness: brightness,
          open: _files,
        );
        final c = d.chats['c']!
          ..openInFiles('PLAN.md')
          ..openInFiles('auth/redirect.go')
          ..openInFiles('NOTES.md', keep: false);
        await tester.pumpAndSettle();
        final app = find.byType(NushiApp);
        await render(tester, app, '${_at}_${w}_preview_tab_$theme');

        await tester.tap(_more);
        await tester.pumpAndSettle();
        await render(tester, app, '${_at}_${w}_menu_$theme');
        await tester.tap(find.text('File tree position'));
        await tester.pumpAndSettle();
        await render(tester, app, '${_at}_${w}_menu_position_$theme');
        await tester.tap(find.text('Left'));
        await tester.pumpAndSettle();
        await render(tester, app, '${_at}_${w}_tree_left_$theme');

        filesTreeSide.value = TreeSide.automatic;
        filesTree.value = false;
        await tester.pumpAndSettle();
        await render(tester, app, '${_at}_${w}_tree_hidden_$theme');
        filesTree.value = true;
        c.files.tabs.value.toList().forEach(c.files.close);
        await tester.pumpAndSettle();
        await render(tester, app, '${_at}_${w}_blank_$theme');

        // The tree button's tooltip, the pointer on it.
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(_treeButton));
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.textContaining('Hide file tree', findRichText: true),
          findsOneWidget,
        );
        await render(tester, app, '${_at}_${w}_tooltip_$theme');
        await mouse.removePointer();

        await tester.tap(_more);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tab size'));
        await tester.pumpAndSettle();
        await render(tester, app, '${_at}_${w}_menu_tab_size_$theme');
        await closeView(tester, d);
      }, variant: macAndLinux);

      renderTest('a source: guides, whitespace, tab sizes, past its end, '
          '$w, $theme', (tester) async {
        final (d, _) = await openEditor(
          tester,
          {'main.go': utf8.encode(_go)},
          width: width,
          brightness: brightness,
          folder: [FolderEntry(name: 'main.go', kind: 'file')],
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        final app = find.byType(NushiApp);
        await render(tester, app, 'fo_${w}_guides_$theme');
        showWhitespace.value = true;
        await tester.pumpAndSettle();
        await render(tester, app, 'fo_${w}_whitespace_$theme');
        showWhitespace.value = false;
        for (final size in [2, 8]) {
          tabSize.value = size;
          await tester.pumpAndSettle();
          await render(tester, app, 'fo_${w}_tab_size_${size}_$theme');
        }
        tabSize.value = 4;
        scrollPastEnd.value = true;
        await tester.pumpAndSettle();
        final down = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(SourceEditor),
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w is Scrollable &&
                          w.axisDirection == AxisDirection.down,
                    ),
                  )
                  .first,
            )
            .position;
        down.jumpTo(down.maxScrollExtent);
        await tester.pumpAndSettle();
        await render(tester, app, 'fo_${w}_past_end_$theme');
        await endEditor(tester, d);
      }, variant: onMac);
    }
  }
}
