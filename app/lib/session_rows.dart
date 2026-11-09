import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Why [s], one of [agent]'s sessions, can't be opened, if it can't: its
/// folder is gone, or it's open elsewhere and the agent lets one app at a
/// time write to it ([oneWriter]).
String? whyNotOpen(FoundSession s, String agent, {required bool oneWriter}) =>
    switch (s) {
      _ when s.folderGone => '${tildePath(s.folder)} no longer exists',
      _ when s.openIn.isNotEmpty && oneWriter =>
        '${agentTitle(agent)} lets one app at a time use a session: '
            'close it there first',
      _ => null,
    };

/// A row of SessionList: [s]'s title, then its age, size and folder (the
/// folder when [everyFolder]), and where it's open; dimmed with [why] as
/// its tooltip when it can't be opened. [extra] ends the details (a
/// search's count), [below] goes under them (its excerpt).
class SessionRow extends StatelessWidget {
  const new(
    this.s, {
    required this.selected,
    required this.onTap,
    required this.everyFolder,
    this.why,
    this.extra = '',
    this.below,
    super.key,
  });

  final FoundSession s;
  final bool selected;
  final VoidCallback onTap;
  final bool everyFolder;
  final String? why;
  final String extra;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final when = DateTime.fromMillisecondsSinceEpoch(s.updatedUnixMs.toInt());
    final details = [
      if (s.updatedUnixMs != 0) ago(clock().difference(when), when),
      if (s.messages > 0) '${s.messages} messages',
      if (everyFolder && s.folder.isNotEmpty) folderParts(s.folder).$1,
      if (s.folderGone) 'folder gone',
      if (extra.isNotEmpty) extra,
    ].join(' · ');
    return Tap(
      onTap: why != null ? null : onTap,
      selected: selected,
      tooltip: why ?? '',
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title.isEmpty ? 'Untitled' : s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(why != null ? t.textMuted : t.text),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: details),
                if (s.openIn.isNotEmpty)
                  TextSpan(
                    text: '${details.isEmpty ? '' : ' · '}open in ${s.openIn}',
                    style: TextStyle(color: t.needs),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.textMuted, size: 11.5),
          ),
          ?below,
        ],
      ),
    );
  }
}

/// Whether to open [s], which may be open elsewhere: both would write to
/// its history, so that asks first (it doesn't refuse). An agent that
/// allows one writer never gets here (SessionList doesn't offer it).
Future<bool> mayOpen(BuildContext context, FoundSession s) async =>
    s.openIn.isEmpty ||
    await confirm(
      context,
      'Open it here too?',
      "It's open in ${s.openIn}. Both will write to its history, and neither "
          "sees the other's turns.",
      'Open',
    );
