import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/mcp.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_general.dart';
import 'package:nushi/settings_nav.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/skills.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';
import 'spell_harness.dart' show FakeSpeller;

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

  // Every section, both themes, a wide window and a small one; the general
  // section, wide, is the settings' window golden (with the sidebar hidden,
  // which has its own), the others renders.
  for (final (size, sizeName) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(900, 700), 'small'),
  ]) {
    for (final (brightness, theme) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      for (final s in SettingsSection.values) {
        testWidgets('${s.name}, $sizeName, $theme', (tester) async {
          final golden = sizeName == 'wide' && s == SettingsSection.general;
          if (golden) sidebarHidden.value = true;
          native.speller = FakeSpeller({}); // the Mac's: it has one
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
          final name = 'settings_${s.name}_${sizeName}_$theme';
          if (golden) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/$name.png'),
            );
          } else {
            await render(tester, find.byType(MaterialApp), name);
          }
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
    // The modal's width less the nav's and the gutters (ADR 0087).
    expect(group.width, lessThanOrEqualTo(SettingsPage.maxWidth));
    expect(group.width, greaterThan(680));
    expect(tester.getRect(find.text('Terminal').last).left, group.left);
    d.dispose();
  }, variant: macOS);

  testWidgets('the nav picks a section; Esc and Close shut it; ⌘, comes '
      'back to the last one and shuts it again', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    await tester.tap(find.byKey(const ValueKey('settings-nav-jira')));
    await tester.pumpAndSettle();
    expect(d.settingsOpen, const SettingsAt(SettingsSection.jira));
    expect(find.text('acme.atlassian.net'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(d.settingsOpen, isNull);
    expect(d.place, const ChatPlace());
    expect(find.byType(SettingsView), findsNothing);
    await _key(tester, LogicalKeyboardKey.comma, meta: true);
    expect(d.settingsOpen, const SettingsAt(SettingsSection.jira));
    await _key(tester, LogicalKeyboardKey.comma, meta: true);
    expect(find.byType(SettingsView), findsNothing);
    await _key(tester, LogicalKeyboardKey.comma, meta: true);
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
    final search = find.descendant(
      of: find.byType(SettingsView),
      matching: find.byType(TextField),
    );
    await tester.tap(search);
    await tester.enterText(search, 'rel');
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.escape);
    expect(d.settingsOpen, isNull);
    d.dispose();
  }, variant: macOS);

  testWidgets('deep links: a chat’s MCP servers… and Skills… open their '
      'sections for its folder; the footer’s Settings opens it and is never '
      'marked; Agents marks a row; Settings opened over GitHub shuts back '
      'to it', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    d.select('c'); // in /Users/me/site; picking a chat shuts Settings
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNull);
    expect(_footer('MCP servers'), findsNothing); // Settings' sections now
    expect(_footer('Skills'), findsNothing);
    d.showMcp(d.selected!.folder); // as its ⋯'s MCP servers… does
    await tester.pumpAndSettle();
    expect(d.settingsOpen, const SettingsAt(SettingsSection.mcp));
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
    expect(d.settingsOpen, const SettingsAt(SettingsSection.skills));
    expect(
      tester.widget<SkillsView>(find.byType(SkillsView)).folder,
      '/Users/me/site',
    );
    d.closeSettings();
    await tester.pumpAndSettle();
    // The footer's Settings opens it, and isn't marked as the place.
    await tester.tap(_footer('Settings'));
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNotNull);
    expect(d.place, const ChatPlace());
    expect(
      tester
          .widget<Tap>(
            find.ancestor(of: _footer('Settings'), matching: find.byType(Tap)),
          )
          .selected,
      isFalse,
    );
    d.closeSettings();
    await tester.pumpAndSettle();

    d.openSettings(section: SettingsSection.agents, agent: 'codex');
    await tester.pumpAndSettle();
    expect(
      d.settingsOpen,
      const SettingsAt(SettingsSection.agents, agent: 'codex'),
    );
    d
      ..closeSettings()
      ..go(const GitHubPlace());
    await tester.pumpAndSettle();
    d.openSettings(section: SettingsSection.github);
    await tester.pumpAndSettle();
    expect(d.settingsOpen, const SettingsAt(SettingsSection.github));
    expect(d.place, const GitHubPlace());
    await tester.tap(
      find.descendant(
        of: find.byType(SettingsView),
        matching: find.byTooltip('Close (esc)'),
      ),
    );
    await tester.pumpAndSettle();
    expect(d.place, const GitHubPlace());
    d.dispose();
  }, variant: macOS);

  testWidgets("two changes inside one round trip don't undo each other", (
    tester,
  ) async {
    final fake = settingsFake();
    final held = Completer<SetSettingsResponse>();
    final inner = fake.answer!;
    fake.answer = (input) => input is SetSettingsRequest && !held.isCompleted
        ? held.future
        : inner(input);
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.general);
    final change = tester
        .widget<GeneralSection>(find.byType(GeneralSection))
        .onChange;
    final first = change((s) => s.sleepAfterMinutes = 60);
    final second = change((s) => s.debugLog = true);
    await tester.pump();
    expect(fake.setSettings, hasLength(1)); // the second waits
    held.complete(SetSettingsResponse());
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
    final last = fake.setSettings.last;
    expect((last.sleepAfterMinutes, last.debugLog), (60, true));
    await closeView(tester, d);
  });

  testWidgets('settings not read while the daemon was away are asked for '
      'once it is back', (tester) async {
    final fake = settingsFake();
    final inner = fake.answer!;
    var down = false;
    var asked = 0;
    fake.answer = (input) {
      if (input is GetSettingsRequest && asked++ == 0) {
        throw ConnectException(Code.unavailable, 'no daemon');
      }
      if (input is PingRequest && down) {
        throw ConnectException(Code.unavailable, 'no daemon');
      }
      return inner(input);
    };
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.general);
    expect(find.text('Sleep idle chats'), findsNothing); // needs the settings
    down = true;
    await tester.pump(const Duration(seconds: 2));
    expect(d.connected, isFalse);
    down = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(d.connected, isTrue);
    expect(asked, 2);
    expect(find.text('Sleep idle chats'), findsOneWidget);
    await closeView(tester, d);
  });
}
