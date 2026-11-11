import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The links over the sidebar's foot: the views in the chat's place, Jira
/// and GitHub (each again closes it), and Settings, which opens over the
/// window (ADR 0087), as quiet rows; the open view's is filled as the open
/// chat's. MCP servers and Skills are Settings' sections, reached there,
/// from a chat's ⋯ and from the palette.
class SidebarLinks extends StatelessWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget row(
      String label,
      IconData icon,
      VoidCallback onTap, {
      required bool open,
    }) => Tap(
      selected: open,
      fill: open ? t.accentSoft : null, // as the open chat's row
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Icon(icon, size: 16, color: open ? t.text : t.textSecondary),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.ui(
                open ? t.text : t.textSecondary,
                weight: open ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
    // Quiet rows on the window's background, no line over them (ADR 0111).
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sidebar.start, 6, Sidebar.end, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            'Jira',
            Icons.task_alt,
            open: daemon.place is JiraPlace,
            () => daemon.toggle(const JiraPlace()),
          ),
          row(
            'GitHub',
            Icons.merge_type,
            open: daemon.place is GitHubPlace,
            () => daemon.toggle(const GitHubPlace()),
          ),
          // Settings opens over the window, never a place (ADR 0087).
          row(
            'Settings',
            Icons.settings_outlined,
            open: false,
            daemon.openSettings,
          ),
        ],
      ),
    );
  }
}
