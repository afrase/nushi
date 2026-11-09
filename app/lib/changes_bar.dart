import 'package:flutter/material.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/diff_box.dart' show oneColumnBelow;
import 'package:nushi/file_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/related_worktrees.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// From this wide the Changes bar has the bar's gaps and gutters.
const double _roomyFrom = 560;

/// The file list's least width, beside the diff.
const double changesFilesLeast = 180;

/// The switcher's name for what the chat itself runs in.
const _ownFolder = "Chat's folder";

/// The Changes view's bar: the related worktrees' menu, the [scopes]' tabs
/// ([scope] picked), the [files]' count and lines, Changed when the
/// worktree shown is [behind] what was read, Send to agent, and the
/// list's tree or list, the diff side by side or unified, and Reload
/// ([onAgain], off while [reloading]). [stale] what's shown is dimmed under
/// a spinner.
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
          // The bar's gaps and gutters while the row has room for them; a
          // narrow window's Send to agent needs it (ADR 0072).
          final roomy = box.maxWidth >= _roomyFrom;
          final unsent = unsentComments(chat.id).length;
          // A narrow bar with the worktrees' menu and Send to agent: the menu
          // narrower, and Send to agent by its short name, without the icon.
          final short = !roomy && related.list.isNotEmpty && unsent > 0;
          return Container(
            height: 36,
            // The tabs' own 3 points bring their line to the gutter.
            padding: roomy
                ? const EdgeInsets.only(
                    left: NushiTheme.gutter - 3,
                    right: NushiTheme.gutter,
                  )
                : const EdgeInsets.only(left: 8, right: 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.borderSubtle)),
            ),
            child: Row(
              spacing: roomy ? NushiTheme.barGap : 10,
              children: [
                // Not Flexible: beside the Expanded it would take half the
                // free width (AGENTS.md).
                if (related.list.isNotEmpty)
                  _worktreeMenu(
                    roomy
                        ? 220
                        : (box.maxWidth * (short ? 0.15 : 0.2)).clamp(72, 120),
                  ),
                if (scopes.length > 1)
                  PlainTabs(
                    value: scope,
                    tabs: [for (final s in scopes) (s, s.label)],
                    onChanged: (s) => worktree == null
                        ? chat.scope = s.name
                        : related.pickScope(s.name),
                    fill: true,
                  ),
                if (stale)
                  const SizedBox.square(dimension: 12, child: Spinner()),
                // A narrow bar gives this line's room to the menu: the list
                // under it shows the files.
                if (n > 0 && (roomy || related.list.isEmpty))
                  Text(
                    '$n file${n == 1 ? '' : 's'}',
                    style: theme.ui(t.textSecondary, size: 12),
                  ),
                Expanded(
                  // Changed takes a narrow bar's room: the list has the counts.
                  child: behind && !roomy
                      ? const SizedBox.shrink()
                      : LineCounts(
                          files.fold(0, (n, f) => n + f.added),
                          files.fold(0, (n, f) => n + f.removed),
                        ),
                ),
                if (behind)
                  Tooltip(
                    message: 'It changed since this was read: Reload shows it',
                    child: Text(
                      roomy ? 'Changed: Reload' : 'Changed',
                      style: theme.ui(t.textSecondary, size: 12),
                    ),
                  ),
                // As the Pull request tab's Send to agent: reply cards in the
                // chat's box, to go with the next message; a related
                // worktree's too, naming it (ADR 0081).
                if (unsent > 0)
                  Button(
                    label: short ? 'Send ($unsent)' : 'Send to agent ($unsent)',
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
                  spacing: roomy ? NushiTheme.iconGap : 10,
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
