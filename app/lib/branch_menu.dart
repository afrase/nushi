import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/worktree.dart';

/// The Environment widget's Branch row, a menu (ADR 0016's amendment of
/// steps 392–393).
/// In a repository's own folder: its local branches, the newest commit
/// first (a filter past ten), the current one checked, and "New branch…";
/// picking one switches the folder to it (SwitchBranch), saying plainly
/// why when it can't. In a worktree: the repository's worktrees by
/// branch, the current one checked; picking one moves the chat there.
/// [list] is what ListBranches last said (null while it's asked);
/// [onOpen] asks again as the menu opens. [onSwitched] after a switch,
/// [onChanges] shows the Changes view.
class BranchMenu extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.branch,
    required this.list,
    super.key,
    this.onOpen,
    this.onSwitched,
    this.onChanges,
  });

  final ChatState chat;
  final Daemon daemon;
  final String branch;
  final ListBranchesResponse? list;
  final VoidCallback? onOpen;
  final VoidCallback? onSwitched;
  final VoidCallback? onChanges;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    // Within the row's height, as the name alone was: the field's tint
    // overhangs it.
    return IntrinsicWidth(
      child: SizedBox(
        height: 16,
        child: OverflowBox(maxHeight: 24, child: _field(context, theme, t)),
      ),
    );
  }

  Widget _field(BuildContext context, NushiTheme theme, Tokens t) {
    return MenuField(
      compact: true,
      onOpen: onOpen,
      // The whole name, which a narrow panel cuts.
      tooltip: switch (chat.worktree) {
        final wt? => '$branch\nA worktree at ${tildePath(wt.path)}',
        null => branch,
      },
      entries: branchEntries(context),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chat.worktree != null) ...[
            Icon(worktreeIcon, size: 13, color: t.textSecondary),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              branch,
              style: theme.code(t.text, size: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// The menu's rows.
  List<MenuEntry> branchEntries(BuildContext context) {
    final list = this.list;
    if (list == null) return const [MenuEntry('Loading…')];
    // Mid-turn: the rows show, unavailable, under why.
    final working = chat.busy || chat.waiting || chat.archived;
    final why = chat.archived
        ? 'Archived'
        : 'Once the agent is done: it’s working in this folder';
    if (chat.worktree != null) {
      if (list.worktrees.isEmpty) return const [MenuEntry('No worktrees')];
      return [
        if (working) MenuEntry.heading(why),
        for (final w in list.worktrees)
          MenuEntry(
            w.branch.isEmpty ? 'detached HEAD' : w.branch,
            detail: worktreePlace(w, list),
            tooltip: tildePath(w.path),
            checked: w.current,
            onPick: w.current
                ? () {}
                : working
                ? null
                : () => openWorktree(context, chat, daemon, w),
          ),
      ];
    }
    return [
      if (working) MenuEntry.heading(why),
      for (final b in list.branches)
        MenuEntry(
          b.name,
          detail: b.name != branch && b.worktree.isNotEmpty
              ? 'in a worktree'
              : '',
          tooltip: b.name != branch && b.worktree.isNotEmpty
              ? 'Checked out at ${tildePath(b.worktree)}'
              : '',
          checked: b.name == branch,
          onPick: b.name == branch
              ? () {}
              : working
              ? null
              : () => unawaited(_pick(context, b)),
        ),
      MenuEntry.divider,
      MenuEntry(
        'New branch…',
        onPick: working ? null : () => unawaited(_newBranch(context)),
      ),
    ];
  }

  Future<void> _pick(BuildContext context, GitBranch b) async {
    if (b.worktree.isNotEmpty) {
      await _inWorktree(context, b.name, b.worktree);
    } else {
      await _switch(context, b.name);
    }
  }

  /// Switches the folder to [name] (a new branch with [create]), or says
  /// why not: another worktree has it, uncommitted changes, or other chats
  /// that go along (asked once).
  Future<void> _switch(
    BuildContext context,
    String name, {
    bool create = false,
    bool others = false,
  }) => tryOrShow(context, () async {
    final r = await daemon.client.switchBranch(
      SwitchBranchRequest(
        chatId: chat.id,
        branch: name,
        newBranch: create,
        withOthers: others,
      ),
    );
    if (!context.mounted) return;
    if (r.switched) {
      onSwitched?.call();
    } else if (r.worktree.isNotEmpty) {
      await _inWorktree(context, name, r.worktree);
    } else if (r.changed > 0) {
      final files = r.changed == 1 ? '1 file' : '${r.changed} files';
      final show = await confirm(
        context,
        'Uncommitted changes',
        '$branch has $files with uncommitted changes. Commit them (or '
            'stash them yourself), then switch to $name.',
        'Show changes',
      );
      if (show) onChanges?.call();
    } else if (r.others.isNotEmpty) {
      final one = r.others.length == 1;
      final names = r.others.map((t) => '“$t”').join(', ');
      final go = await confirm(
        context,
        one
            ? 'Another chat works in this folder'
            : '${r.others.length} other chats work in this folder',
        '$names ${one ? 'is' : 'are'} in this folder too, so switching to '
            '$name moves ${one ? 'it' : 'them'} as well. Each agent is told '
            'with its next message.',
        'Switch',
      );
      if (go && context.mounted) {
        await _switch(context, name, create: create, others: true);
      }
    }
  });

  /// A branch another worktree has checked out: open that worktree.
  Future<void> _inWorktree(
    BuildContext context,
    String name,
    String path,
  ) async {
    final open = await confirm(
      context,
      '$name is in a worktree',
      'Git checks out a branch in one place at a time, and $name is '
          'checked out at ${tildePath(path)}. Open that worktree to work on '
          'it: the chat moves there.',
      'Open its worktree',
    );
    if (open && context.mounted) {
      final w = list?.worktrees.where((w) => w.path == path).firstOrNull;
      await openWorktree(
        context,
        chat,
        daemon,
        w ?? GitWorktree(path: path, branch: name),
      );
    }
  }

  Future<void> _newBranch(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NewBranchDialog(from: branch),
    );
    if (name != null && context.mounted) {
      await _switch(context, name, create: true);
    }
  }
}

/// Where a worktree is, for its row: "the repository" for the main one,
/// else its folder (inside the repository, relative to it), and locked.
String worktreePlace(GitWorktree w, ListBranchesResponse list) {
  final repo = list.worktrees.where((w) => w.main).firstOrNull?.path ?? '';
  final place = w.main
      ? 'the repository'
      : repo.isNotEmpty && w.path.startsWith('$repo/')
      ? w.path.substring(repo.length + 1)
      : tildePath(w.path);
  return w.locked ? '$place · locked' : place;
}

/// Moves [chat] into the worktree [w] that's there, asking first when it
/// has messages (its session is forked there, as for any move).
Future<void> openWorktree(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
  GitWorktree w,
) async {
  final name = w.branch.isEmpty ? folderParts(w.path).$1 : w.branch;
  if (!chat.fresh) {
    final own = chat.worktree;
    final stays = own != null && !own.found
        ? ' Its own worktree and branch ${own.branch} stay, with their '
              'work; Delete offers to remove them.'
        : '';
    final move = await confirm(
      context,
      w.main ? 'Move to the repository?' : 'Move to the worktree of $name?',
      'The chat goes on in ${tildePath(w.path)}, on $name; its agent is '
          'told with the next message. Uncommitted changes stay where they '
          'are.$stays',
      'Move',
    );
    if (!move || !context.mounted) return;
  }
  await tryOrShow(context, () => daemon.moveChat(chat, w.path));
}

/// The Environment widget's Worktree row for a chat outside a worktree: its
/// value "None", and a menu of [onNew] ("New worktree…", when given), a
/// divider, then the repository's other worktrees by branch; picking one
/// moves the chat there. Mid-turn, as the Branch row: the value shows and
/// the rows are unavailable, under why. [list] is what ListBranches last
/// said; [onOpen] asks again.
class WorktreeMenu extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.list,
    super.key,
    this.onNew,
    this.onOpen,
  });

  final ChatState chat;
  final Daemon daemon;
  final ListBranchesResponse? list;
  final VoidCallback? onNew;
  final VoidCallback? onOpen;

  /// The repository's worktrees but the chat's own folder.
  List<GitWorktree> get others => [
    ...?list?.worktrees.where((w) => !w.current),
  ];

  @override
  Widget build(BuildContext context) => IntrinsicWidth(
    // Within the row's height, as the Branch row: the tint overhangs it.
    child: SizedBox(
      height: 16,
      child: OverflowBox(
        maxHeight: 24,
        child: MenuField(
          compact: true,
          onOpen: onOpen,
          entries: worktreeEntries(context),
          label: const Text('None'),
        ),
      ),
    ),
  );

  /// The menu's rows.
  List<MenuEntry> worktreeEntries(BuildContext context) {
    final list = this.list;
    final others = this.others;
    final working = chat.busy || chat.waiting;
    return [
      if (working)
        const MenuEntry.heading(
          'Once the agent is done: it’s working in this folder',
        ),
      if (onNew case final add?) ...[
        MenuEntry('New worktree…', onPick: working ? null : add),
        if (list == null || others.isNotEmpty) MenuEntry.divider,
      ],
      if (list == null)
        const MenuEntry('Loading…')
      else
        for (final w in others)
          MenuEntry(
            w.branch.isEmpty ? 'detached HEAD' : w.branch,
            detail: worktreePlace(w, list),
            tooltip: tildePath(w.path),
            onPick: working
                ? null
                : () => unawaited(openWorktree(context, chat, daemon, w)),
          ),
    ];
  }
}

/// The name of a new branch, from the folder's [from]; the daemon checks
/// it as git does.
class NewBranchDialog extends StatefulWidget {
  const new({required this.from, super.key});

  final String from;

  @override
  State<NewBranchDialog> createState() => _NewBranchDialogState();
}

class _NewBranchDialogState extends State<NewBranchDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _new => _name.text.trim();

  void _create() {
    if (_new.isNotEmpty) Navigator.pop(context, _new);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return nushiDialog(
      'New branch',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            style: theme.code(t.text),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
          ),
          Text(
            'From ${widget.from}; uncommitted changes go along.',
            style: theme.ui(t.textMuted, size: 12),
          ),
        ],
      ),
      [
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        Button(
          label: 'Create',
          kind: ButtonKind.primary,
          onPressed: _new.isEmpty ? null : _create,
        ),
      ],
    );
  }
}
