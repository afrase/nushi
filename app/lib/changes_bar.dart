import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/diff_box.dart' show oneColumnBelow;
import 'package:nushi/file_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/related_worktrees.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// From this wide the Changes bar has the bar's gaps and gutters.
const double _roomyFrom = 560;

/// How wide the Changes bar must be beside the worktrees' menu for its long
/// labels (the files' line and counts, Send to agent's, Changed: Reload),
/// and for the bar's gaps and gutters with its short ones, with Send to
/// agent ([send]) and Changed ([changed]) beside it: each part at its
/// largest, the menu still readable (related_worktree_comments_test).
({double long, double plain, double roomy}) _needs({
  required bool send,
  required bool changed,
}) => (
  long: 640 + (send ? 170 : 0) + (changed ? 110 : 0),
  // Without the menu: the scopes, the files' line and the buttons take
  // about 380, Send to agent's long label 160 and Changed: Reload 110.
  plain: 380 + (send ? 160 : 0) + (changed ? 110 : 0),
  roomy: max(_roomyFrom, 480 + (send ? 90 : 0) + (changed ? 60 : 0)),
);

/// The file list's least width, beside the diff.
const double changesFilesLeast = 180;

/// The switcher's name for what the chat itself runs in.
const _ownFolder = "Chat's folder";

/// The Changes view's bar: the related worktrees' menu, the [scopes] as a
/// filled control ([scope] picked; ADR 0111), the [files]' count and
/// lines, Changed when the worktree shown is [behind] what was read, Send
/// to agent, and the list's tree or list, the diff side by side or
/// unified, and Reload ([onAgain], off while [reloading]). [stale] what's
/// shown is dimmed under a spinner.
class ChangesBar extends StatelessWidget {
  const new({
    required this.chat,
    required this.scopes,
    required this.scope,
    required this.files,
    required this.stale,
    required this.behind,
    required this.reloading,
    required this.onAgain,
    super.key,
  });

  final ChatState chat;
  final List<Scope> scopes;
  final Scope scope;
  final List<FileChange> files;
  final bool stale;
  final bool behind;
  final bool reloading;
  final VoidCallback onAgain;

  /// The bar's height.
  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final related = chat.related;
    final worktree = related.shown;
    final n = files.length;
    return ListenableBuilder(
      listenable: Listenable.merge([reviews, chat]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final unsent = unsentComments(chat.id).length;
          final menu = related.list.isNotEmpty;
          final needs = _needs(send: unsent > 0, changed: behind);
          // Short labels while the long ones don't fit, beside the
          // worktrees' menu or in a narrow window's pane: the list under
          // it shows the files.
          final short = box.maxWidth < (menu ? needs.long : needs.plain);
          // The bar's gaps and gutters while the row has room for them; a
          // narrow window's Send to agent needs it (ADR 0072).
          final roomy = box.maxWidth >= (short ? needs.roomy : _roomyFrom);
          final counts = LineCounts(
            files.fold(0, (n, f) => n + f.added),
            files.fold(0, (n, f) => n + f.removed),
          );
          // No line under it: the diff's block and the list start under
          // it (ADR 0111). Its ends are the header's, 12 from the pane's
          // edge, where there's room.
          return Container(
            height: ChangesBar.height,
            padding: roomy
                ? const EdgeInsets.symmetric(horizontal: 12)
                : const EdgeInsets.only(left: 8, right: 6),
            // Narrow, the bar is dense: its controls compact (ADR 0122).
            child: ControlScale(
              size: roomy ? ControlSize.regular : ControlSize.compact,
              child: Row(
                spacing: roomy ? NushiTheme.barGap : 10,
                children: [
                  Expanded(
                    child: Row(
                      spacing: roomy ? NushiTheme.barGap : 10,
                      children: [
                        // Flexible in a row of its own (AGENTS.md): it takes
                        // what the rest leaves, its name cut short, so the
                        // bar's buttons stay at its edge.
                        if (menu)
                          Flexible(child: _worktreeMenu(roomy ? 220 : 120)),
                        if (scopes.length > 1)
                          Segmented(
                            value: scope,
                            segments: [for (final s in scopes) (s, s.label)],
                            onChanged: (s) => worktree == null
                                ? chat.scope = s.name
                                : related.pickScope(s.name),
                          ),
                        if (stale)
                          const SizedBox.square(
                            dimension: 12,
                            child: Spinner(),
                          ),
                        if (n > 0 && !short)
                          Text(
                            '$n file${n == 1 ? '' : 's'}',
                            style: theme.ui(t.textSecondary, size: 12),
                          ),
                        // Whole beside the menu, which gives way first; cut
                        // short without one.
                        if (!short && menu)
                          counts
                        else if (!short)
                          Flexible(child: counts),
                      ],
                    ),
                  ),
                  if (behind)
                    tooltip(
                      context,
                      'It changed since this was read: Reload shows it',
                      Text(
                        short ? 'Changed' : 'Changed: Reload',
                        style: theme.ui(t.textSecondary, size: 12),
                      ),
                    ),
                  // As the Pull request tab's Send to agent: reply cards in the
                  // chat's box, to go with the next message; a related
                  // worktree's too, naming it (ADR 0081).
                  if (unsent > 0)
                    Button(
                      label: short
                          ? 'Send ($unsent)'
                          : 'Send to agent ($unsent)',
                      icon: short ? null : Icons.subdirectory_arrow_right,
                      kind: ButtonKind.primary,
                      tooltip:
                          "${short ? 'Send to agent: each' : 'Each'} comment "
                          "as a reply card in the chat's box, to send with "
                          'your next message',
                      onPressed: chat.archived || chat.sessionGone
                          ? null
                          : () => reviewToBox(chat),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    // Closer in a narrow bar: the scopes' control is a few
                    // points wider than the tabs it replaced.
                    spacing: roomy ? NushiTheme.iconGap : 6,
                    children: [
                      ValueListenableBuilder(
                        valueListenable: changesFlat,
                        builder: (context, flat, _) => IconTap(
                          flat ? Icons.account_tree_outlined : Icons.list,
                          tooltip: flat ? 'Show as a tree' : 'Show as a list',
                          size: 15,
                          onTap: () => changesFlat.value = !flat,
                        ),
                      ),
                      // Side by side or unified, for every diff (ADR 0107). In
                      // a view too narrow for a diff of two panes beside the
                      // list at its least width it would change nothing here;
                      // a wider list may still leave the diff one column.
                      if (box.maxWidth >= changesFilesLeast + oneColumnBelow)
                        ValueListenableBuilder(
                          valueListenable: diffUnified,
                          builder: (context, unified, _) => IconTap(
                            unified
                                ? Icons.vertical_split_outlined
                                : Icons.view_agenda_outlined,
                            tooltip: unified
                                ? 'Show side by side'
                                : 'Show unified',
                            size: 15,
                            onTap: () => diffUnified.value = !unified,
                          ),
                        ),
                      IconTap(
                        Icons.refresh,
                        tooltip: 'Reload',
                        size: 15,
                        onTap: reloading ? null : onAgain,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Picks what the view shows: the chat's folder or a related worktree.
  /// A menu, not tabs (ADR 0071): there can be many, and long-named.
  Widget _worktreeMenu(double width) {
    final related = chat.related;
    final picked = related.picked;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: MenuField(
        compact: true,
        tooltip: picked == null
            ? 'Show a related worktree'
            : "Nushi doesn't stage or commit here; comments go to the "
                  "chat's agent",
        label: Text(picked == null ? _ownFolder : worktreeName(picked)),
        entries: [
          MenuEntry(
            _ownFolder,
            checked: picked == null,
            onPick: () => related.pick(null),
          ),
          const MenuEntry.heading('Related worktrees'),
          for (final w in related.ordered)
            MenuEntry(
              worktreeName(w),
              detail: worktreeEnd(w),
              checked: w.path == picked?.path,
              onPick: () => related.pick(w.path),
            ),
        ],
      ),
    );
  }
}
