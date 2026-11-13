import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/project_rail.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'sidebar_fixture.dart';

// With the project rail wanted, the sidebar is kept wide enough for it, as
// far as the window has room: one dragged to 200 before had no rail, and
// the switch seemed to do nothing.

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  Future<Daemon> open(WidgetTester tester, double width) async {
    viewport(tester, Size(width, 900));
    paneWidths.value = {'sidebar': 200};
    final d = await FakeDaemon(arrangeChats()).connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pump(const Duration(seconds: 1));
    return d;
  }

  double sidebar(WidgetTester tester) =>
      tester.getSize(find.byType(Sidebar)).width;

  testWidgets('a sidebar dragged narrow widens for the rail, and back', (
    tester,
  ) async {
    final d = await open(tester, 1700);
    expect(sidebar(tester), 200);
    expect(find.byType(ProjectRail), findsNothing);

    projectRail.value = true;
    await tester.pump(); // the sidebar widens; then the rail is told it fits
    await tester.pump(const Duration(seconds: 1));
    expect(sidebar(tester), ProjectRail.minSidebar);
    expect(find.byType(ProjectRail), findsOne);
    expect(paneWidths.value['sidebar'], 200); // what was dragged is kept

    sidebarGroupBy.value = GroupBy.date; // no rail: no need for the room
    await tester.pump(const Duration(seconds: 1));
    expect(sidebar(tester), 200);

    sidebarGroupBy.value = GroupBy.project;
    projectRail.value = false;
    await tester.pump(const Duration(seconds: 1));
    expect(sidebar(tester), 200);
    await closeView(tester, d);
  }, variant: macOS);

  testWidgets('a window with no room for it keeps its width for the chats', (
    tester,
  ) async {
    projectRail.value = true;
    final d = await open(tester, 720);
    expect(sidebar(tester), 200);
    expect(find.byType(ProjectRail), findsNothing);
    await closeView(tester, d);
  }, variant: macOS);
}
