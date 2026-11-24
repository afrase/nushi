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

/// A row of the sidebar's footer.
Finder _footer(String label) =>
    find.descendant(of: find.byType(Sidebar), matching: find.text(label));

void main() {
  setUpAll(loadFonts);

  // Every section, both themes, a wide window, a small one and a narrow
  // one (720, where the window's layout narrows); the general section,
  // wide, is the settings' window golden (with the sidebar hidden, which
  // has its own), the others renders.
  for (final (size, sizeName) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(900, 700), 'small'),
    (const Size(720, 900), 'narrow'),
  ]) {
    for (final (brightness, theme) in [
      (Brightness.dark, 'dark'),
      (Brightness.light, 'light'),
    ]) {
      for (final s in SettingsSection.values) {
        final golden = sizeName == 'wide' && s == SettingsSection.general;
        if (lightCopy(brightness) && !golden) continue;
        testWidgets('${s.name}, $sizeName, $theme', (tester) async {
          if (golden) sidebarHidden.value = true;
          native.speller = FakeSpeller({}); // the Mac's: it has one
          final d = await pumpSettingsApp(
            tester,
            settingsFake(),
            s,
            size: size,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
          expectTextInside(tester, size.width);
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
        }, variant: onMac);
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
  }, variant: onMac);

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
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNull);
    expect(d.place, const ChatPlace());
    expect(find.byType(SettingsView), findsNothing);
    await press(tester, LogicalKeyboardKey.comma, cmd: true);
    expect(d.settingsOpen, const SettingsAt(SettingsSection.jira));
    await press(tester, LogicalKeyboardKey.comma, cmd: true);
    expect(find.byType(SettingsView), findsNothing);
    await press(tester, LogicalKeyboardKey.comma, cmd: true);
    await tester.tap(find.byTooltip('Close\u2002Esc'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsNothing);
    d.dispose();
  }, variant: onMac);

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
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(d.settingsOpen, isNull);
    d.dispose();
  }, variant: onMac);

  testWidgets('deep links: a chat’s MCP servers… and Skills… open their '
      'sections for its folder; the footer’s Settings opens it and is never '
      'marked; Agents marks a row; Settings opened over GitHub shuts back '
      'to it', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      // The GitHub view it opens over: an inbox with nothing in it.
      settingsFake()..on(
        (input) => input is ListGitHubInboxRequest
            ? ListGitHubInboxResponse(atMs: msAgo(Duration.zero))
            : null,
      ),
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
        matching: find.byTooltip('Close\u2002Esc'),
      ),
    );
    await tester.pumpAndSettle();
    expect(d.place, const GitHubPlace());
    d.dispose();
  }, variant: onMac);

  testWidgets("two changes inside one round trip don't undo each other", (
    tester,
  ) async {
    final fake = settingsFake();
    final held = Completer<SetSettingsResponse>();
    fake.on(
      (input) =>
          input is SetSettingsRequest && !held.isCompleted ? held.future : null,
    );
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.general);
    final change = tester
        .widget<GeneralSection>(find.byType(GeneralSection))
        .settings
        .change;
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
    var down = false;
    var asked = 0;
    fake.on((input) {
      if (input is GetSettingsRequest && asked++ == 0) {
        throw ConnectException(Code.unavailable, 'no daemon');
      }
      if (input is PingRequest && down) {
        throw ConnectException(Code.unavailable, 'no daemon');
      }
      return null;
    });
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

  testWidgets('the nav: its one title, the sections in their groups in '
      'order, a dot on each integration that works', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.general,
    );
    // Every section once.
    expect([
      for (final (_, g) in settingsGroups) ...g,
    ], unorderedEquals(SettingsSection.values));
    // The nav's words, top to bottom: the title, then each heading and its
    // sections.
    final nav = find.byType(SettingsNav);
    final words = [
      for (final e
          in find.descendant(of: nav, matching: find.byType(Text)).evaluate())
        (tester.getRect(find.byWidget(e.widget)).top, (e.widget as Text).data!),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    expect(
      [for (final (_, w) in words) w],
      [
        'Settings',
        'App',
        'General',
        'Appearance',
        'Terminal',
        'Keyboard shortcuts',
        'Agents',
        'Agents',
        'MCP servers',
        'Skills',
        'Chat history',
        'Usage',
        'Connections',
        'GitHub',
        'Jira',
        'Remote access',
        'Logs & advanced',
      ],
    );
    // Logs & advanced is set apart from Remote access, under no heading.
    expect(words.last.$1 - words[words.length - 2].$1, greaterThan(40));
    // One title in the modal, the nav's: no bar of its own over the page.
    expect(
      find.descendant(
        of: find.byType(SettingsView),
        matching: find.text('Settings'),
      ),
      findsOne,
    );
    final page = tester.getRect(find.text('General').last);
    final modal = tester.getRect(find.byKey(const ValueKey('settings-modal')));
    expect(page.top - modal.top, lessThan(30));
    // Nothing known yet this launch: no dot, and nothing asked for one.
    expect(find.byKey(const ValueKey('settings-nav-dot-github')), findsNothing);
    expect(find.byKey(const ValueKey('settings-nav-dot-jira')), findsNothing);
    // GitHub's host is signed in, Jira said who the site's token is: once
    // each page found so, both dotted, and still on the next opening.
    for (final s in ['github', 'jira', 'general']) {
      await tester.tap(find.byKey(ValueKey('settings-nav-$s')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('settings-nav-dot-github')), findsOne);
    expect(find.byKey(const ValueKey('settings-nav-dot-jira')), findsOne);
    expect(find.byKey(const ValueKey('settings-nav-dot-remote')), findsNothing);
    d.closeSettings();
    await tester.pumpAndSettle();
    d.openSettings(section: SettingsSection.general);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-nav-dot-github')), findsOne);
    expect(find.byKey(const ValueKey('settings-nav-dot-jira')), findsOne);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('720 wide, Remote access stacks what would squeeze: the '
      'relay field under its label, a phone’s buttons under its words', (
    tester,
  ) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.remote,
      size: const Size(720, 900),
    );
    final label = tester.getRect(find.text('Relay'));
    final field = tester.getRect(
      find.descendant(
        of: find.byType(SettingsView),
        matching: find.byType(TextField),
      ),
    );
    expect(label.height, lessThan(20), reason: 'one line');
    expect(field.top, greaterThan(label.bottom));
    expect(field.left, closeTo(label.left, 1));
    final words = tester.getRect(find.textContaining('Notifications off'));
    expect(words.height, lessThan(20), reason: 'one line');
    expect(tester.getRect(find.text('Revoke')).top, greaterThan(words.bottom));
    expectTextInside(tester, 720);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Phones says why its buttons are off', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.remote,
    );
    // Remote access off, the phone's notifications off: both said.
    expect(find.textContaining('Turn on Remote access to pair'), findsOne);
    expect(
      find.textContaining('A test notification needs the phone’s'),
      findsOne,
    );
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('900 wide, they stay beside', (tester) async {
    final d = await pumpSettingsApp(
      tester,
      settingsFake(),
      SettingsSection.remote,
      size: const Size(900, 900),
    );
    final label = tester.getRect(find.text('Relay'));
    final field = tester.getRect(
      find.descendant(
        of: find.byType(SettingsView),
        matching: find.byType(TextField),
      ),
    );
    expect(field.center.dy, closeTo(label.center.dy, 2));
    expect(field.width, 300);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('opening Settings asks GitHub and Jira nothing: their pages '
      'do, as they show', (tester) async {
    final fake = settingsFake();
    final asked = <String>[];
    fake.on((input) {
      if (input is ListGitHubHostsRequest ||
          input is ListJiraSitesRequest ||
          input is CheckJiraSiteRequest) {
        asked.add(input.runtimeType.toString());
      }
      return null;
    });
    final d = await pumpSettingsApp(tester, fake, SettingsSection.appearance);
    expect(asked, isEmpty);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a Jira site whose token Jira turns down has no dot, though '
      'listed without a problem', (tester) async {
    final fake = settingsFake();
    var works = true;
    fake.on(
      (input) => input is CheckJiraSiteRequest && !works
          ? throw ConnectException(
              Code.unauthenticated,
              'Jira turned the token down',
            )
          : null,
    );
    final d = await pumpSettingsApp(tester, fake, SettingsSection.jira);
    expect(find.byKey(const ValueKey('settings-nav-dot-jira')), findsOne);
    // The token revoked: the next check takes the dot away.
    works = false;
    await tester.tap(find.byKey(const ValueKey('settings-nav-general')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-nav-jira')));
    await tester.pumpAndSettle();
    expect(find.text('Not connected'), findsOne);
    expect(find.byKey(const ValueKey('settings-nav-dot-jira')), findsNothing);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('no dot on an integration without a working account, and one '
      'once its page finds it', (tester) async {
    final fake = settingsFake();
    var hosts = <GitHubHost>[];
    fake.on(
      (input) => switch (input) {
        ListGitHubHostsRequest() => ListGitHubHostsResponse(hosts: hosts),
        ListJiraSitesRequest() => ListJiraSitesResponse(
          sites: [JiraSite(id: 'acme.atlassian.net', problem: 'Token expired')],
        ),
        _ => null,
      },
    );
    final d = await pumpSettingsApp(tester, fake, SettingsSection.general);
    expect(find.byKey(const ValueKey('settings-nav-dot-github')), findsNothing);
    expect(find.byKey(const ValueKey('settings-nav-dot-jira')), findsNothing);
    hosts = [GitHubHost(host: 'github.com', login: 'octo', source: 'gh')];
    await tester.tap(find.byKey(const ValueKey('settings-nav-github')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-nav-dot-github')), findsOne);
    await closeView(tester, d);
  }, variant: onMac);
}
