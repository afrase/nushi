import 'package:flutter/material.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_fonts.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_theme.dart';
import 'package:nushi/sidebar_view.dart';

/// Settings › Appearance: Light, Dark or as the system, the chat's width,
/// the app's and code's fonts (ADR 0114), whether the preview shows
/// whitespace, and the color theme (ADR 0086).
class AppearanceSection extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const SettingsPage(
    title: 'Appearance',
    children: [_Appearance(), FontsGroup(), _Preview(), ThemeGroup()],
  );
}

/// How a file's source shows in the preview: whether its whitespace is
/// marked (ADR 0096). An app preference; View › Show Whitespace too.
class _Preview extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: showWhitespace,
    builder: (context, on, _) => SettingsGroup(
      title: 'Preview',
      children: [
        SettingsRow(
          'Show whitespace',
          description:
              'Spaces show as faint dots and tabs as arrows in a file’s '
              'source.',
          control: SettingsSwitch(
            value: on,
            onChanged: (v) => showWhitespace.value = v,
          ),
        ),
      ],
    ),
  );
}

/// The appearance: Light, Dark, or as the system is; remembered (the View
/// menu's items set it too). And the chat's width (ADR 0074), and whether
/// the sidebar has its project rail (ADR 0112; off at first).
class _Appearance extends StatelessWidget {
  const new();

  static const Map<ThemeMode, String> _names = {
    ThemeMode.system: 'As the system',
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
  };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: appearance,
    builder: (context, mode, _) => SettingsGroup(
      children: [
        SettingsRow(
          'Appearance',
          control: MenuField(
            entries: [
              for (final MapEntry(:key, :value) in _names.entries)
                MenuEntry(
                  value,
                  checked: key == mode,
                  onPick: () => appearance.value = key,
                ),
            ],
            label: Text(_names[mode]!),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: chatFullWidth,
          builder: (context, full, _) => SettingsRow(
            'Chat width',
            control: MenuField(
              entries: [
                MenuEntry(
                  'Centered',
                  checked: !full,
                  onPick: () => chatFullWidth.value = false,
                ),
                MenuEntry(
                  'Full width',
                  checked: full,
                  onPick: () => chatFullWidth.value = true,
                ),
              ],
              label: Text(full ? 'Full width' : 'Centered'),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([projectRail, sidebarGroupBy, railFits]),
          builder: (context, _) => SettingsRow(
            'Project rail',
            description: _railNote(),
            control: SettingsSwitch(
              value: projectRail.value,
              onChanged: (v) => projectRail.value = v,
            ),
          ),
        ),
      ],
    ),
  );
}

/// What Project rail says: what it is, or, while it's on and not shown,
/// why not (the sidebar grouped by something else, or the window too
/// narrow for it), which
/// a switch that changed nothing left unsaid.
String _railNote() => switch (projectRail.value) {
  true when sidebarGroupBy.value != GroupBy.project =>
    'Shows while chats are grouped by project.',
  true when !railFits.value => 'Shows in a wider window.',
  _ => 'A column of project tiles beside the chats.',
};
