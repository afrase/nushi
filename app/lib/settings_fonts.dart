import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/fonts.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';

/// The installed families [ask] answers with, as a font menu lists them
/// ([listedFamilies]) after [bundled]; none when there's no answer.
Future<List<String>> installedFamilies(
  Future<List<String>?> Function() ask, {
  required String bundled,
}) async {
  try {
    return listedFamilies(await ask(), but: bundled);
  } on Exception {
    return const [];
  }
}

/// A font setting's menu ([picked]: a family's name, or null for the
/// bundled one): [bundled] first, then [system] (the system's own font,
/// where a name reaches it) as "System", a line, and [families], the
/// installed ones. A picked family that isn't installed stays listed,
/// saying so: text set in it is drawn in the bundled font meanwhile. The
/// long list gets the menu's filter field.
class FontField extends StatelessWidget {
  const new({
    required this.picked,
    required this.bundled,
    required this.families,
    super.key,
    this.system,
  });

  final ValueNotifier<String?> picked;
  final String bundled;
  final Future<List<String>> families;
  final String? system;

  /// The field's widest: a family's name may be a hundred characters.
  static const maxWidth = 240.0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: picked,
    builder: (context, _) => FutureBuilder(
      future: families,
      builder: (context, found) {
        // The bundled one by name (a hand-edited file's) is the bundled one.
        final now = picked.value == bundled ? null : picked.value;
        final installed = found.data ?? const <String>[];
        MenuEntry family(String name, {String detail = ''}) => MenuEntry(
          name,
          detail: detail,
          checked: now == name,
          onPick: () => picked.value = name,
        );
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: MenuField(
            entries: [
              MenuEntry(
                bundled,
                detail: 'bundled',
                checked: now == null,
                onPick: () => picked.value = null,
              ),
              if (system case final system?)
                MenuEntry(
                  'System',
                  checked: now == system,
                  onPick: () => picked.value = system,
                ),
              MenuEntry.divider,
              // Known only once the list is in: an empty one is no answer.
              if (now != null &&
                  now != system &&
                  installed.isNotEmpty &&
                  !installed.contains(now))
                family(now, detail: 'not installed'),
              for (final f in installed) family(f),
            ],
            label: Text(
              now == null
                  ? bundled
                  : now == system
                  ? 'System'
                  : now,
            ),
          ),
        );
      },
    ),
  );
}

/// Settings › Appearance's Fonts (ADR 0114): the family the app's text is
/// set in, of every installed one and the system's own, and the one code
/// is set in, of the monospaced ones. The terminal's is its own setting.
class FontsGroup extends StatefulWidget {
  const new({super.key});

  @override
  State<FontsGroup> createState() => _FontsGroupState();
}

class _FontsGroupState extends State<FontsGroup> {
  final Future<List<String>> _all = installedFamilies(
    native.fonts.families,
    bundled: NushiTheme.uiFont,
  );
  final Future<List<String>> _monospaced = installedFamilies(
    native.fonts.monospaced,
    bundled: NushiTheme.codeFont,
  );

  @override
  Widget build(BuildContext context) => SettingsGroup(
    title: 'Fonts',
    children: [
      SettingsRow(
        'App font',
        control: FontField(
          key: const ValueKey('app-font'),
          picked: appFont,
          bundled: NushiTheme.uiFont,
          system: native.fonts.system,
          families: _all,
        ),
      ),
      SettingsRow(
        'Code font',
        description:
            'Code in chats, diffs and files. The terminal has its '
            'own.',
        control: FontField(
          key: const ValueKey('code-font'),
          picked: codeFont,
          bundled: NushiTheme.codeFont,
          families: _monospaced,
        ),
      ),
    ],
  );
}
