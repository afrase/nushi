import 'dart:io';

import 'package:flutter/material.dart';

import 'package:nushi/alerts_settings.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_updates.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/web_views.dart';
import 'package:nushi/widgets.dart';

/// Changes the daemon's settings: the function given applied to them.
typedef SettingsChange = Future<void> Function(void Function(Settings));

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

/// Settings › General: when idle chats sleep, whether the composer checks
/// spelling, where a chat's links open (with the app's own web views), the
/// Mac's notifications, whether the daemon checks for updates, and whether
/// it starts at login (the packaged app's, for the usual data folder).
/// [settings] is the daemon's, null until it said.
class GeneralSection extends StatelessWidget {
  const new({
    required this.daemon,
    required this.settings,
    required this.onChange,
    super.key,
  });

  final Daemon daemon;
  final Settings? settings;
  final SettingsChange onChange;

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'General',
    children: [
      if (settings?.sleepAfterMinutes case final sleep?)
        SettingsGroup(
          title: 'Chats',
          children: [
            SettingsRow(
              'Sleep idle chats',
              description:
                  "An idle chat's agent stops; the next message wakes it.",
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
                        () => onChange((s) => s.sleepAfterMinutes = key),
                      ),
                    ),
                ],
                label: Text(
                  sleep == 0 ? 'Never' : 'After ${_sleepLabel(sleep)}',
                ),
              ),
            ),
          ],
        ),
      if (speller != null) const _Spelling(),
      if (webEmbedded) const _Links(),
      const NotificationsGroup(),
      if (settings case final s? when s.hasCheckUpdates())
        UpdatesGroup(daemon: daemon, settings: s, onChange: onChange),
      // Start at login starts the usual data folder's daemon.
      if (native.install.daemon != null &&
          Platform.environment['NUSHI_DATA'] == null)
        const StartAtLogin(),
    ],
  );
}

/// Whether the composer checks spelling, where there's a checker: the app's
/// own preference, not the daemon's (ADR 0083).
class _Spelling extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: checkSpelling,
    builder: (context, on, _) => SettingsGroup(
      title: 'Composer',
      children: [
        SettingsRow(
          'Check spelling while typing',
          description: 'Typos get a dotted underline; click one to fix it.',
          control: SettingsSwitch(
            value: on,
            onChanged: (v) => checkSpelling.value = v,
          ),
        ),
      ],
    ),
  );
}

/// Whether a chat's links to this Mac or the local network open in a
/// browser tab beside it (ADR 0094): the app's own preference, on at first.
class _Links extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: linksInBrowserTab,
    builder: (context, on, _) => SettingsGroup(
      title: 'Browser',
      children: [
        SettingsRow(
          'Open local links in built-in browser',
          description:
              'Links in a chat to this Mac or your local network, such as a '
              'dev server, open in a browser tab beside it. Other sites open '
              'in your browser.',
          control: SettingsSwitch(
            value: on,
            onChanged: (v) => linksInBrowserTab.value = v,
          ),
        ),
      ],
    ),
  );
}
