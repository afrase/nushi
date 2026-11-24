import 'dart:io';

import 'package:flutter/material.dart';

import 'package:nushi/alerts_settings.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_settings.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_updates.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/web_views.dart';
import 'package:nushi/widgets.dart';

/// The choices for when idle chats sleep, in minutes; 0: never.
const _sleepAfter = {
  0: 'Never',
  15: '15 minutes',
  30: '30 minutes',
  60: '1 hour',
  120: '2 hours',
  300: '5 hours',
};

String _sleepLabel(int m) => _sleepAfter[m] ?? '$m minute${m == 1 ? '' : 's'}';

/// Settings › General: the chats' group (when idle chats sleep, whether
/// the composer checks spelling, whether Enter starts a line or sends,
/// where a chat's local links open), the
/// notifications, then whether the daemon starts at login with the
/// updates. Its daemon rows show once [settings] came.
class GeneralSection extends StatelessWidget {
  const new({required this.daemon, required this.settings, super.key});

  final Daemon daemon;
  final DaemonSettings settings;

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'General',
    children: [
      _ChatsGroup(settings),
      const NotificationsGroup(),
      // Start at login starts the usual data folder's daemon, not chats:
      // it heads the updates' group, which it joins once the system says
      // whether it's on.
      if (native.install.daemon != null &&
          Platform.environment['NUSHI_DATA'] == null)
        StartAtLogin(group: _startup)
      else
        _startup(const []),
    ],
  );

  /// The group of how Nushi starts and updates: [login] (Start at login's
  /// rows) then the updates' once the daemon said; either alone if the
  /// other has none.
  Widget _startup(List<Widget> login) => ValueListenableBuilder(
    valueListenable: settings,
    builder: (context, set, _) => switch (set) {
      final s? when s.hasCheckUpdates() => UpdatesGroup(
        daemon: daemon,
        settings: settings,
        login: login,
      ),
      _ when login.isNotEmpty => SettingsGroup(
        title: 'Startup',
        children: login,
      ),
      _ => const SizedBox.shrink(),
    },
  );
}

/// Settings › General's first group, one card of the chat's settings that
/// were each a group of one row: when idle chats sleep (the daemon's, once
/// it said), spelling (the app's own preference, where there's a checker;
/// ADR 0083), whether Enter starts a line in the boxes that send (ADR
/// 0147), local links in a browser tab beside the chat (ADR 0094;
/// where there are web views).
class _ChatsGroup extends StatelessWidget {
  const new(this.settings);

  final DaemonSettings settings;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: settings,
    builder: (context, set, _) => _group(context, set),
  );

  Widget _group(BuildContext context, Settings? set) {
    final rows = [
      if (set?.sleepAfterMinutes case final sleep?)
        SettingsRow(
          'Sleep idle chats',
          description: 'The agent stops; your next message wakes it.',
          control: MenuField(
            entries: [
              for (final MapEntry(:key, :value) in {
                ..._sleepAfter,
                sleep: _sleepLabel(sleep),
              }.entries)
                MenuEntry(
                  value,
                  checked: key == sleep,
                  onPick: () => tryOrShow(
                    context,
                    () => settings.change((s) => s.sleepAfterMinutes = key),
                  ),
                ),
            ],
            label: Text(sleep == 0 ? 'Never' : 'After ${_sleepLabel(sleep)}'),
          ),
        ),
      if (speller != null)
        ValueListenableBuilder(
          valueListenable: checkSpelling,
          builder: (context, on, _) => SettingsRow(
            'Check spelling while typing',
            description: 'Typos get a dotted underline.',
            control: SettingsSwitch(
              value: on,
              onChanged: (v) => checkSpelling.value = v,
            ),
          ),
        ),
      ValueListenableBuilder(
        valueListenable: enterStartsLine,
        builder: (context, on, _) => SettingsRow(
          'Enter starts a new line',
          description: 'Send with $cmdEnterLabel or the Send button.',
          control: SettingsSwitch(
            value: on,
            onChanged: (v) => enterStartsLine.value = v,
          ),
        ),
      ),
      if (webEmbedded)
        ValueListenableBuilder(
          valueListenable: linksInBrowserTab,
          builder: (context, on, _) => SettingsRow(
            'Open local links in built-in browser',
            description: 'Dev servers open in a tab beside the chat.',
            control: SettingsSwitch(
              value: on,
              onChanged: (v) => linksInBrowserTab.value = v,
            ),
          ),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return SettingsGroup(title: 'Chats', children: rows);
  }
}
