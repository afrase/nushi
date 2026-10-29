import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/skills.dart';

import 'fake_daemon.dart';
import 'settings_harness.dart';

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool meta = false,
}) async {
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

/// A row of the sidebar's footer.
Finder _footer(String label) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(label));

void main() {
  setUpAll(loadFonts);
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

  // Every section, both themes, a wide window and a small one.
  for (final (size, sizeName) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(900, 700), 'small'),
  ]) {
    for (final (brightness, theme) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      for (final s in SettingsSection.values) {
        testWidgets('golden: ${s.name}, $sizeName, $theme', (tester) async {
          final d = await pumpSettingsApp(
            tester,
            settingsFake(),
            s,
            size: size,
            brightness: brightness,
          );
          expect(
            tester.getSize(find.byType(SettingsNav)).width,
            SettingsNav.width,
          );
          expectControlsAtEdge(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/settings_${s.name}_${sizeName}_$theme.png',
            ),
          );
          d.dispose();
        }, variant: macOS);
      }
    }
  }

  testWidgets('rows: controls at the group’s edge, the content beside the '
      'nav', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    d.openSettings(section: SettingsSection.terminal);
    await tester.pumpAndSettle();
    expect(expectControlsAtEdge(tester), 2); // font and size
    // The content's column is left-aligned beside the nav, its labels
    // inside the group's padding.
    final group = tester.getRect(find.byType(SettingsGroup).first);
    final nav = tester.getRect(find.byType(SettingsNav));
    expect(tester.getRect(find.text('Font')).left, group.left + 14);
    expect(group.left - nav.right, SettingsPage.gutter);
    expect(group.width, SettingsPage.maxWidth);
    expect(tester.getRect(find.text('Terminal').last).left, group.left);
    d.dispose();
  }, variant: macOS);

  testWidgets('the nav picks a section; Esc and Close leave; ⌘, comes back '
      'to the last one', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    await tester.tap(find.byKey(const ValueKey('settings-nav-jira')));
    await tester.pumpAndSettle();
    expect(d.settings, SettingsSection.jira);
    expect(find.text('acme.atlassian.net'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(d.settings, isNull);
    expect(find.byType(SettingsView), findsNothing);
    await _key(tester, LogicalKeyboardKey.comma, meta: true);
    expect(d.settings, SettingsSection.jira);
    await tester.tap(find.byTooltip('Close (esc)'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsNothing);
    d.dispose();
  }, variant: macOS);

  testWidgets('Esc with the focus in a field inside still leaves', (
    tester,
  ) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.skills,
    );
    await tester.tap(find.byType(TextField)); // the search
    await tester.enterText(find.byType(TextField), 'rel');
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.escape);
    expect(d.settings, isNull);
    d.dispose();
  }, variant: macOS);

  testWidgets('deep links: a chat’s MCP servers… and Skills… open their '
      'sections for its folder; the footer’s Settings opens and closes it; '
      'Agents marks a row; Settings opened from GitHub closes back to it', (
    tester,
  ) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    d.select('c'); // in /Users/me/site
    await tester.pumpAndSettle();
    expect(_footer('MCP servers'), findsNothing); // Settings' sections now
    expect(_footer('Skills'), findsNothing);
    d.showMcp(d.selected!.folder); // as its ⋯'s MCP servers… does
    await tester.pumpAndSettle();
    expect(d.settings, SettingsSection.mcp);
    expect(find.byType(McpView), findsOneWidget);
    expect(
      tester.widget<McpView>(find.byType(McpView)).folder,
      '/Users/me/site',
    );
    d.closeSettings();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills…', findRichText: true));
    await tester.pumpAndSettle();
    expect(d.settings, SettingsSection.skills);
    expect(
      tester.widget<SkillsView>(find.byType(SkillsView)).folder,
      '/Users/me/site',
    );
    // The footer's Settings, open, leaves it; again, opens it.
    await tester.tap(_footer('Settings'));
    await tester.pumpAndSettle();
    expect(d.settings, isNull);
    await tester.tap(_footer('Settings'));
    await tester.pumpAndSettle();
    expect(d.settings, isNotNull);
    d.closeSettings();
    await tester.pumpAndSettle();

    d.openSettings(section: SettingsSection.agents, agent: 'codex');
    await tester.pumpAndSettle();
    expect(d.markedAgent, 'codex');

    d.showGitHub(open: true);
    await tester.pumpAndSettle();
    d.openSettings(section: SettingsSection.github);
    await tester.pumpAndSettle();
    expect(d.githubOpen, isFalse);
    d.closeSettings();
    await tester.pumpAndSettle();
    expect(d.githubOpen, isTrue);
    d.dispose();
  }, variant: macOS);
}
