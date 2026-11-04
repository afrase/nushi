import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'sidebar_fixture.dart';

// The whole window with the sidebar arranged each way, to look at (`make
// renders TEST=test/sidebar_arrange_render_test.dart`); each also checks
// that no text runs off the window and that the sidebar's buttons sit at
// its header's right end.

void main() {
  setUpAll(loadFonts);

  Future<Daemon> window(
    WidgetTester tester,
    double width,
    Brightness brightness,
  ) async {
    viewport(tester, Size(width, 760), brightness: brightness);
    paneWidths.value = {};
    final d = await FakeDaemon(arrangeChats()).connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pump(const Duration(seconds: 1));
    expectTextInside(tester, width);
    final sidebar = tester.getRect(find.byType(Sidebar));
    final arrange = tester.getRect(
      find.byTooltip(RegExp('^Arrange the sidebar')),
    );
    final hide = tester.getRect(
      find.byTooltip(RegExp('^(Hide|Show) the sidebar')),
    );
    expect(arrange.right, lessThanOrEqualTo(hide.left));
    expect(hide.right, closeTo(sidebar.right - 10, 1));
    return d;
  }

  for (final width in [1700.0, 720.0]) {
    for (final brightness in Brightness.values) {
      final name = '${width.toInt()}_${brightness.name}';
      for (final group in GroupBy.values) {
        testWidgets('the sidebar grouped by ${group.label}, $name', (
          tester,
        ) async {
          sidebarGroupBy.value = group;
          sidebarSections.value = const [
            Section(id: 's1', name: 'Reviews', chats: ['b']),
          ];
          if (group != GroupBy.project) {
            sidebarShows.value = {...defaultRowParts, RowPart.time};
          }
          final d = await window(tester, width, brightness);
          await render(
            tester,
            find.byType(NushiApp),
            'arrange_${group.name}_$name',
          );
          await closeView(tester, d);
        }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
      }

      testWidgets('the Arrange menu open, Group by shown, $name', (
        tester,
      ) async {
        final d = await window(tester, width, brightness);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(100, 200));
        await tester.pump();
        await tester.tap(find.byTooltip(RegExp('^Arrange the sidebar')));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.textContaining('Group by').last);
        await tester.pump(const Duration(milliseconds: 300));
        expectTextInside(tester, width);
        await render(tester, find.byType(NushiApp), 'arrange_menu_$name');
        await mouse.removePointer();
        await closeView(tester, d);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  }
}
