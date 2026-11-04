import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/settings_theme.dart';

/// Settings › Appearance: Light, Dark or as the system, the chat's width,
/// and the color theme (ADR 0086).
class AppearanceSection extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const SettingsPage(
    title: 'Appearance',
    children: [_Appearance(), ThemeGroup()],
  );
}

/// The appearance: Light, Dark, or as the system is; remembered (the View
/// menu's items set it too). And the chat's width (ADR 0074).
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
      ],
    ),
  );
}
