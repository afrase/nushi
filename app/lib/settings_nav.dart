import 'package:flutter/material.dart';

import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Settings' sections, in the order the nav lists them.
enum SettingsSection {
  general('General', Icons.tune),
  terminal('Terminal', Icons.terminal),
  history('Chat history', Icons.history),
  remote('Remote access', Icons.phone_iphone),
  agents('Agents', Icons.smart_toy_outlined),
  mcp('MCP servers', Icons.hub_outlined),
  skills('Skills', Icons.auto_awesome_outlined),
  jira('Jira', Icons.task_alt),
  github('GitHub', Icons.merge_type),
  logs('Logs & advanced', Icons.receipt_long_outlined);

  new(this.title, this.icon);

  final String title;
  final IconData icon;
}

/// Settings' nav: a row per section, [section] selected.
class SettingsNav extends StatelessWidget {
  const new({required this.section, required this.onPick, super.key});

  /// The nav's width.
  static const width = 200.0;

  final SettingsSection section;
  final ValueChanged<SettingsSection> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: t.borderSubtle)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        children: [
          for (final s in SettingsSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Tap(
                key: ValueKey('settings-nav-${s.name}'),
                selected: s == section,
                onTap: () => onPick(s),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      s.icon,
                      size: 15,
                      color: s == section ? t.text : t.textSecondary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(
                          s == section ? t.text : t.textSecondary,
                          weight: s == section ? FontWeight.w500 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
