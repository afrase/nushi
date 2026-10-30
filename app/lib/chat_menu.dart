import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/inline_edit.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/worktree.dart';

/// The chat's menu (its ⋯, its sidebar row's right-click): the menu bar's
/// Chat menu, the actions that apply to it now ([chatActions]: Side
/// question, Fork, Send review comments, Stop, Rename, Sleep, Reload, Link
/// pull request…, Archive or Unarchive, MCP servers…, Skills…, Delete…), each
/// with its icon, in groups ([_group]) with a line between them; Delete in
/// red.
List<MenuEntry> chatMenu(
  BuildContext context,
  ChatState chat,
  Daemon daemon, {
  required VoidCallback onRename,
}) {
  final shown = [
    for (final a in chatActions(context, daemon, chat, onRename: onRename))
      if (a.enabled) a,
  ]..sort((a, b) => _group(a.act).compareTo(_group(b.act)));
  return [
    for (final (i, a) in shown.indexed) ...[
      if (i > 0 && _group(a.act) != _group(shown[i - 1].act)) MenuEntry.divider,
      MenuEntry(
        a.short,
        shortcut: a.act.shortcut ?? '',
        onPick: a.run,
        icon: _icon(a.act),
        danger: a.act == Act.delete,
      ),
    ],
  ];
}

/// Where an action goes in the chat's menu: the conversation, the chat
/// itself, what it's linked to and uses, keeping it, deleting it. One the
/// menu doesn't know yet goes with the chat itself.
int _group(Act act) => switch (act) {
  Act.sideChat || Act.fork || Act.sendComments || Act.stop => 0,
  Act.linkPull || Act.cleanUp || Act.mcp || Act.skills => 2,
  Act.archive || Act.unarchive => 3,
  Act.delete => 4,
  _ => 1,
};

IconData? _icon(Act act) => switch (act) {
  Act.sideChat => Icons.forum_outlined,
  Act.fork => Icons.call_split,
  Act.sendComments => Icons.rate_review_outlined,
  Act.stop => Icons.stop_circle_outlined,
  Act.rename => Icons.edit_outlined,
  Act.pin => Icons.push_pin_outlined,
  Act.sleep => Icons.bedtime_outlined,
  Act.reload => Icons.refresh,
  Act.linkPull => Icons.link,
  Act.cleanUp => Icons.cleaning_services_outlined,
  Act.mcp => Icons.hub_outlined,
  Act.skills => Icons.auto_awesome_outlined,
  Act.archive => Icons.archive_outlined,
  Act.unarchive => Icons.unarchive_outlined,
  Act.delete => Icons.delete_outline,
  _ => null,
};

/// Asks before deleting a chat, listing what goes, then deletes it.
Future<void> showDeleteChat(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) => showDialog<void>(
  context: context,
  barrierDismissible: false, // not while it deletes: see _DeleteDialog
  builder: (_) => _DeleteDialog(chat, daemon),
);

/// Stops a chat's agent to free its memory; a message wakes it. Subagents
/// still running in the background stop with it: it asks first.
Future<void> sleepChat(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  if (!await stopsBackground(context, chat, 'Sleep the chat?', 'Sleep')) {
    return;
  }
  if (!context.mounted) return;
  await tryOrShow(
    context,
    () => daemon.client.sleepChat(SleepChatRequest(chatId: chat.id)),
  );
}

/// Asks [title] before stopping [chat]'s agent while subagents it started
/// run in the background, since they stop with it; true when none runs or
/// [action] is pressed.
Future<bool> stopsBackground(
  BuildContext context,
  ChatState chat,
  String title,
  String action,
) async {
  final running = [
    for (final s in subagentsOf(chat.items))
      if (subagentRunning(s)) s.call.agent,
  ];
  if (running.isEmpty) return true;
  final which = running.length == 1
      ? 'Its ${running.single} subagent is'
      : 'Its subagents ${running.join(', ')} are';
  return await confirm(
    context,
    title,
    '$which still running in the background, and will stop with '
    '${chat.agentName}.',
    action,
  );
}

/// Reloads [chat]'s agent, so it picks up changed MCP servers, asking
/// first when that stops subagents running in the background; [say]: a
/// toast says it runs and when it is done (nothing else shows a reload).
Future<void> reloadChat(
  BuildContext context,
  ChatState chat,
  Daemon daemon, {
  bool say = false,
}) async {
  if (!await stopsBackground(context, chat, 'Reload the chat?', 'Reload') ||
      !context.mounted) {
    return;
  }
  Future<void> reload() =>
      daemon.client.reloadChat(ReloadChatRequest(chatId: chat.id));
  if (!say) return await reload();
  await runAndSay(
    context,
    reload,
    running: 'Reloading ${chat.shownTitle}…',
    done: 'Reloaded ${chat.shownTitle}',
  );
}

/// Archives (or unarchives) a chat. Archiving ends its terminals: when a
/// program runs in one, it asks first, as closing that terminal would.
Future<void> archiveChat(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async {
  if (!chat.archived) {
    if (!await stopsBackground(context, chat, 'Archive the chat?', 'Archive') ||
        !context.mounted) {
      return;
    }
    final terms = await daemon.client.listTerminals(
      ListTerminalsRequest(chatId: chat.id),
    );
    final running = [
      for (final t in terms.terminals)
        if (t.program.isNotEmpty && !t.exited) '“${t.program}”',
    ];
    if (running.isNotEmpty &&
        (!context.mounted ||
            !await confirm(
              context,
              'Archive the chat?',
              'Archiving ends its terminals, and what still runs in them: '
                  '${running.join(', ')}.',
              'Archive',
            ))) {
      return;
    }
  }
  await daemon.client.archiveChat(
    ArchiveChatRequest(chatId: chat.id, archived: !chat.archived),
  );
}

/// Asks before deleting a chat, listing what goes, then deletes it.
class _DeleteDialog extends StatefulWidget {
  const new(this.chat, this.daemon);

  final ChatState chat;
  final Daemon daemon;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  late final Future<PlanDeleteChatResponse> _plan = widget.daemon.client
      .planDeleteChat(PlanDeleteChatRequest(chatId: widget.chat.id))
      .then((p) {
        _worktrees = p.worktrees;
        for (final w in _worktrees) {
          _choices[w.worktree.path] = WorktreeChoices.defaults(w);
        }
        return p;
      });
  var _worktrees = <WorktreePlan>[];
  final _choices = <String, (bool, bool)>{}; // by path: remove, delete branch
  bool _deleting = false;
  String _error = '';

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await _plan;
      final choices = [
        for (final w in _worktrees)
          WorktreeChoices.choice(
            w,
            remove: _choices[w.worktree.path]!.$1,
            branch: _choices[w.worktree.path]!.$2,
          ),
      ];
      await widget.daemon.client.deleteChat(
        DeleteChatRequest(chatId: widget.chat.id, worktrees: choices),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final name = widget.chat.agentName;
    final resume = widget.chat.resume.isEmpty
        ? '$name’s resume'
        : widget.chat.resume;
    final title = widget.chat.title.isEmpty
        ? 'this chat'
        : '“${widget.chat.title}”';
    Widget line(String text, {bool mono = false}) => Padding(
      padding: EdgeInsets.only(top: mono ? 2 : 8, left: mono ? 10 : 0),
      child: Text(
        text,
        style: mono
            ? theme.code(t.textMuted, size: 11.5)
            : theme.ui(t.textSecondary),
      ),
    );
    Iterable<Widget> sessions(PlanDeleteChatResponse p) => [
      for (final s in p.sessions) ...[
        line(s.sessionId, mono: true),
        line(
          s.folder == p.scratchFolder
              ? '  in its scratch folder'
              : '  in ${tildePath(s.folder)}',
          mono: true,
        ),
      ],
    ];
    final dialog = nushiDialog(
      'Delete $title?',
      FutureBuilder(
        future: _plan,
        builder: (context, snap) {
          final p = snap.data;
          if (p == null) {
            return line(
              snap.hasError ? errorText(snap.error!) : 'Checking what goes…',
            );
          }
          final archived = p.sessions.length == 1
              ? 'chat'
              : '${p.sessions.length} sessions';
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line('This deletes, for good:'),
              if (p.deletesHistory &&
                  (knownAgents[widget.chat.agent]?.deleteArchives ??
                      false)) ...[
                line(
                  '• $name archives its history of the '
                  '$archived '
                  '($resume offers to unarchive it):',
                ),
                ...sessions(p),
              ] else if (p.deletesHistory) ...[
                line(
                  p.sessions.length == 1
                      ? '• $name’s history of the chat ($resume '
                            'won’t find it):'
                      : '• $name’s history of its ${p.sessions.length} '
                            'sessions ($resume won’t find them):',
                ),
                ...sessions(p),
              ],
              if (p.scratchFolder.isNotEmpty) ...[
                line('• Its scratch folder and its files:'),
                line(tildePath(p.scratchFolder), mono: true),
              ],
              line('• Nushi’s record of the chat.'),
              if (p.terminals.isNotEmpty) ...[
                line('• Its terminals, and what still runs in them:'),
                for (final term in p.terminals)
                  line(terminalName(term), mono: true),
              ],
              for (final (i, w) in _worktrees.indexed) ...[
                if (i > 0 || widget.chat.worktree == null)
                  line('A worktree it ran in before it moved:')
                else
                  const SizedBox(height: 12),
                WorktreeChoices(
                  plan: w,
                  remove: _choices[w.worktree.path]!.$1,
                  branch: _choices[w.worktree.path]!.$2,
                  onChanged: ({required remove, required branch}) => setState(
                    () => _choices[w.worktree.path] = (remove, branch),
                  ),
                ),
              ],
              if (!p.deletesHistory) ...[
                line(
                  '$name can’t delete its history from here, so it '
                  'stays: $resume still opens',
                ),
                ...sessions(p),
              ],
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error, style: theme.ui(t.crashed)),
                ),
            ],
          );
        },
      ),
      [
        Button(
          label: 'Cancel',
          onPressed: _deleting ? null : () => Navigator.pop(context),
        ),
        FutureBuilder(
          future: _plan,
          builder: (context, snap) => Button(
            label: _deleting ? 'Deleting…' : 'Delete',
            kind: ButtonKind.destructive,
            autofocus: true,
            onPressed: snap.hasData && !_deleting ? _delete : null,
          ),
        ),
      ],
    );
    // Once it deletes, it can't be called off: it stays to say how it went.
    return PopScope(canPop: !_deleting, child: dialog);
  }
}

/// Renames a chat in place (see InlineEdit); [onDone] when it's over.
class RenameField extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onDone,
    super.key,
    this.style,
  });

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onDone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => InlineEdit(
    text: chat.title,
    style: style,
    onDone: (title) {
      if (title != null && title != chat.title) {
        unawaited(
          tryOrShow(
            context,
            () => daemon.client.renameChat(
              RenameChatRequest(chatId: chat.id, title: title),
            ),
          ),
        );
      }
      onDone();
    },
  );
}
