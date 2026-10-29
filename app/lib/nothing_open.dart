import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/logo.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The pane with no chat open (the first run's): New chat (⌘N) and Open
/// a folder… (which picks one, then asks which agent), and under them the
/// recent folders, a new chat each: the chats' (none yet: the folders the
/// default agent's sessions were found in, as a terminal left them).
/// While no agent can start, where to set one up.
class NothingOpen extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  State<NothingOpen> createState() => _NothingOpenState();
}

class _NothingOpenState extends State<NothingOpen> {
  List<String> _sessionFolders = const [];

  @override
  void initState() {
    super.initState();
    if (widget.daemon.chats.isEmpty) {
      widget.daemon.client.listAgentSessions(ListAgentSessionsRequest()).then((
        r,
      ) {
        if (!mounted) return;
        setState(
          () => _sessionFolders = {
            for (final s
                in r.sessions.toList()
                  ..sort((a, b) => b.updatedUnixMs.compareTo(a.updatedUnixMs)))
              if (!s.folderGone && s.folder.isNotEmpty) s.folder,
          }.toList(),
        );
      }, onError: (_) {}).ignore();
    }
  }

  Future<void> _openFolder() async {
    final folder = await getDirectoryPath(confirmButtonText: 'Open');
    if (folder == null || !mounted) return;
    await newChat(context, widget.daemon, folder);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: agentList,
    builder: (context, agents, _) => _pane(context, agents),
  );

  Widget _pane(BuildContext context, Map<String, Agent> agents) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final d = widget.daemon;
    final none = agents.isNotEmpty && !agents.values.any((a) => a.ready);
    final recent = {
      ...recentFolders(d.chats.values),
      ..._sessionFolders,
    }.take(5).toList();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Logo(color: t.borderStrong),
            const SizedBox(height: 16),
            if (none)
              SetUpLine(
                'Set up an agent in ',
                onTap: () => d.openSettings(section: SettingsSection.agents),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Button(
                    label: 'New chat',
                    kind: ButtonKind.primary,
                    icon: Icons.add,
                    hint: Act.newChat.shortcut,
                    onPressed: () => newChat(context, d, ''),
                  ),
                  Button(
                    label: 'Open a folder…',
                    icon: Icons.folder_open_outlined,
                    onPressed: _openFolder,
                  ),
                ],
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  'Recent folders',
                  style: theme.ui(
                    t.textSecondary,
                    size: 12,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                for (final f in recent)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        LinkText(
                          folderParts(f).$1,
                          tooltip: 'A new chat in $f',
                          onTap: () => newChat(context, d, f),
                        ),
                        Text(
                          tildePath(folderParts(f).$2),
                          style: theme.ui(t.textMuted, size: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
