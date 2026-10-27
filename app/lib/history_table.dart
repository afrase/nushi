import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A size on disk: "840 KB", "12.4 MB", "1.2 GB".
String diskSize(int n) => switch (n) {
  < 1 << 20 => '${(n / 1024).ceil()} KB',
  < 1 << 30 => '${(n / (1 << 20)).toStringAsFixed(1)} MB',
  _ => '${(n / (1 << 30)).toStringAsFixed(1)} GB',
};

/// One chat's copy as Chat history lists it: the daemon's entry and the
/// app's chat, if it still has one.
class HistoryRow {
  new(this.copy, this.chat)
    : title = copy.title.isNotEmpty ? copy.title : chat?.title ?? '',
      bytes = copy.bytes.toInt(),
      last = DateTime.fromMillisecondsSinceEpoch(copy.lastWrittenMs.toInt());

  final TranscriptCopy copy;
  final ChatState? chat;
  final String title;
  final int bytes;
  final DateTime last;

  String get id => copy.chatId;
  String get folder => chat?.folder ?? '';
  String get agent => copy.agent.isNotEmpty ? copy.agent : chat?.agent ?? '';

  /// A copy whose chat Nushi no longer has.
  bool get leftover => chat == null && copy.title.isEmpty;
  bool get archived => chat?.archived ?? false;

  /// Its agent no longer has the session: the copy is all there is.
  bool get gone => chat?.sessionGone ?? false;
}

/// What the list shows.
enum HistoryFilter { all, archived, gone, leftover }

/// What the list is ordered by.
enum HistorySort { size, last, title }

/// [rows] that pass [filter] and whose title or folder has [query],
/// ordered by [sort] ([up]: ascending).
List<HistoryRow> historyView(
  Iterable<HistoryRow> rows, {
  required HistoryFilter filter,
  required String query,
  required HistorySort sort,
  required bool up,
}) {
  final q = query.trim().toLowerCase();
  final out = [
    for (final r in rows)
      if (switch (filter) {
            HistoryFilter.all => true,
            HistoryFilter.archived => r.archived,
            HistoryFilter.gone => r.gone,
            HistoryFilter.leftover => r.leftover,
          } &&
          (q.isEmpty ||
              r.title.toLowerCase().contains(q) ||
              r.folder.toLowerCase().contains(q)))
        r,
  ];
  int by(HistoryRow a, HistoryRow b) => switch (sort) {
    HistorySort.size => a.bytes.compareTo(b.bytes),
    HistorySort.last => a.last.compareTo(b.last),
    HistorySort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
  };
  return out..sort((a, b) => up ? by(a, b) : by(b, a));
}

/// The table's columns after the title: their widths, and whether the
/// value sits at the right; Folder and Agent only in a wide table.
const historyColumns = <(String, double, bool)>[
  ('Folder', 130, false),
  ('Agent', 84, false),
  ('Size', 76, true),
  ('Last used', 88, true),
];

/// Whether a table this wide shows Folder and Agent.
bool historyWide(double width) => width >= 560;

/// The width kept at a row's end for its Clear.
const historyActionWidth = 64.0;

/// A row's height.
const historyRowHeight = 34.0;

/// The cells of a row (or the header): [title] taking what's left, then
/// [cells] at [historyColumns]' widths, then [action]; narrow ([wide]
/// false), neither Folder and Agent nor the action's room.
Widget historyCells(
  Widget title,
  List<Widget> cells,
  Widget action, {
  required bool wide,
}) => Row(
  children: [
    Expanded(child: title),
    for (final (i, (_, width, right)) in historyColumns.indexed)
      if (wide || i >= 2)
        SizedBox(
          width: width,
          child: Align(
            alignment: right ? Alignment.centerRight : Alignment.centerLeft,
            child: cells[i],
          ),
        ),
    if (wide) SizedBox(width: historyActionWidth, child: action),
  ],
);

/// The table's header: Title, Size and Last used order the list (again
/// to turn it around).
class HistoryHeader extends StatelessWidget {
  const new({
    required this.sort,
    required this.up,
    required this.wide,
    required this.onSort,
    super.key,
  });

  final HistorySort sort;
  final bool up;
  final bool wide;
  final ValueChanged<HistorySort> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget head(String label, HistorySort? by) {
      final style = theme.ui(
        by == sort ? t.text : t.textSecondary,
        size: 12,
        weight: FontWeight.w500,
      );
      if (by == null) return Text(label, style: style);
      return Tap(
        key: ValueKey('history-sort-${by.name}'),
        onTap: () => onSort(by),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: style),
            if (by == sort)
              Icon(
                up ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: t.textSecondary,
              ),
          ],
        ),
      );
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 8, right: 8),
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: historyCells(
        Align(
          alignment: Alignment.centerLeft,
          child: head('Title', HistorySort.title),
        ),
        [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: head('Folder', null),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: head('Agent', null),
          ),
          head('Size', HistorySort.size),
          head('Last used', HistorySort.last),
        ],
        const SizedBox(),
        wide: wide,
      ),
    );
  }
}

/// A chat's copy in the table: its title (a link to the chat, when Nushi
/// has it), folder, agent, size and when it was last written; Clear under
/// the pointer. A click selects it ([onTap]: ⇧ and ⌘ are the caller's).
class HistoryRowView extends StatefulWidget {
  const new(
    this.row, {
    required this.wide,
    required this.last,
    required this.selected,
    required this.now,
    required this.onTap,
    required this.onOpen,
    required this.onClear,
    super.key,
  });

  final HistoryRow row;
  final bool wide;
  final bool last; // the table's last row: its corners round
  final bool selected;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback? onOpen;
  final VoidCallback onClear;

  @override
  State<HistoryRowView> createState() => _HistoryRowViewState();
}

class _HistoryRowViewState extends State<HistoryRowView> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final r = widget.row;
    final small = theme.ui(t.textSecondary, size: 12);
    final title = r.leftover
        ? Text(
            'A deleted chat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.textMuted),
          )
        : _Title(
            r.title.isEmpty ? 'Untitled' : r.title,
            onTap: widget.onOpen,
            note: r.gone
                ? 'read-only'
                : r.archived
                ? 'archived'
                : null,
          );
    final (name, parent) = r.folder.isEmpty ? ('', '') : folderParts(r.folder);
    final clear = Button(label: 'Clear', onPressed: widget.onClear);
    final cells = historyCells(
      Padding(padding: const EdgeInsets.only(left: 4), child: title),
      [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Tooltip(
            message: r.folder.isEmpty ? '' : '$parent/$name',
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            r.agent.isEmpty ? '' : agentTitle(r.agent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(diskSize(r.bytes), style: small),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: dateTime(r.last),
            child: Text(
              ago(widget.now.difference(r.last), r.last),
              style: small,
            ),
          ),
        ),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: _hover ? clear : const SizedBox(),
      ),
      wide: widget.wide,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: historyRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? t.accentSoft
                : _hover
                ? t.hover
                : null,
            border: widget.last
                ? null
                : Border(bottom: BorderSide(color: t.borderSubtle)),
            borderRadius: widget.last
                ? const BorderRadius.vertical(bottom: Radius.circular(7))
                : null,
          ),
          // Narrow, Clear has no room of its own: it shows over the end
          // of the row.
          child: widget.wide || !_hover
              ? cells
              : Stack(
                  children: [
                    cells,
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.only(left: 8),
                        alignment: Alignment.center,
                        color: Color.alphaBlend(
                          widget.selected ? t.accentSoft : t.hover,
                          t.raised,
                        ),
                        child: clear,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A chat's title that opens it: the link color, underlined under the
/// pointer, on one line; [note] after it, muted.
class _Title extends StatelessWidget {
  const new(this.text, {required this.onTap, this.note});

  final String text;
  final VoidCallback? onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Row(
      children: [
        Flexible(
          child: Pressable(
            onTap: onTap,
            tooltip: onTap == null ? '' : 'Open the chat',
            builder: (context, look) => Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme
                  .ui(look.enabled ? t.link : t.text)
                  .copyWith(
                    decoration: look.hover || look.focus
                        ? TextDecoration.underline
                        : null,
                    decorationColor: t.link,
                  ),
            ),
          ),
        ),
        if (note case final n?) ...[
          const SizedBox(width: 6),
          Text(n, style: theme.ui(t.textMuted, size: 11.5)),
        ],
      ],
    );
  }
}
