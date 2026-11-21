import 'package:flutter/material.dart';

import 'package:nushi/place.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Each section's icon in the nav.
extension SectionIcon on SettingsSection {
  IconData get icon => switch (this) {
    .general => Icons.tune,
    .appearance => Icons.palette_outlined,
    .terminal => Icons.terminal,
    .shortcuts => Icons.keyboard_outlined,
    .history => Icons.history,
    .usage => Icons.bar_chart_rounded,
    .remote => Icons.phone_iphone,
    .agents => Icons.smart_toy_outlined,
    .mcp => Icons.hub_outlined,
    .skills => Icons.auto_awesome_outlined,
    .jira => Icons.task_alt,
    .github => Icons.merge_type,
    .logs => Icons.receipt_long_outlined,
  };
}

/// The nav's groups, in order, each its heading and its sections; the
/// last has none (Logs & advanced, set apart). Every section is in one.
const List<(String?, List<SettingsSection>)> settingsGroups = [
  ('App', [.general, .appearance, .terminal, .shortcuts]),
  ('Agents', [.agents, .mcp, .skills, .history, .usage]),
  ('Connections', [.github, .jira, .remote]),
  (null, [.logs]),
];

/// Settings' nav: the modal's title, then the sections in their groups
/// ([settingsGroups]), [section] selected; a section in [connected] (an
/// integration with an account that works) has a solid dot in the done
/// color at its end.
class SettingsNav extends StatelessWidget {
  const new({
    required this.section,
    required this.onPick,
    super.key,
    this.connected = const {},
  });

  /// The nav's width.
  static const width = 200.0;

  final SettingsSection section;
  final ValueChanged<SettingsSection> onPick;
  final Set<SettingsSection> connected;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget heading(String? h) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 8, 4),
      child: h == null
          ? null
          : Text(
              h,
              style: theme.ui(t.textMuted, size: 11.5, weight: FontWeight.w600),
            ),
    );
    Widget row(SettingsSection s) {
      final on = s == section;
      return Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Tap(
          key: ValueKey('settings-nav-${s.name}'),
          selected: on,
          // The open section, as the sidebar's open view (ADR 0111).
          fill: on ? t.accentSoft : null,
          onTap: () => onPick(s),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(s.icon, size: 15, color: on ? t.text : t.textSecondary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(
                    on ? t.text : t.textSecondary,
                    weight: on ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (connected.contains(s))
                tooltip(
                  context,
                  'Connected',
                  Container(
                    key: ValueKey('settings-nav-dot-${s.name}'),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: t.done,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
        children: [
          // The modal's one title: each page has its own name beside it.
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 8, 2),
            child: Text(
              'Settings',
              style: theme.ui(t.text, size: 14, weight: FontWeight.w600),
            ),
          ),
          for (final (h, sections) in settingsGroups) ...[
            heading(h),
            for (final s in sections) row(s),
          ],
        ],
      ),
    );
  }
}
