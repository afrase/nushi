import 'package:flutter/material.dart';

import 'package:nushi/history_table.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Chat history's filters, with their counts (Deleted chats only when
/// there are some), and its search; the search under the filters when
/// narrow.
class HistoryToolbar extends StatelessWidget {
  const new({
    required this.search,
    required this.filter,
    required this.counts,
    required this.onFilter,
    super.key,
  });

  final TextEditingController search;
  final HistoryFilter filter;
  final Map<HistoryFilter, int> counts;
  final ValueChanged<HistoryFilter> onFilter;

  static const Map<HistoryFilter, String> _labels = {
    HistoryFilter.all: 'All',
    HistoryFilter.archived: 'Archived',
    HistoryFilter.gone: 'Read-only',
    HistoryFilter.leftover: 'Deleted chats',
  };

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final field = SizedBox(
      height: 26,
      child: TextField(
        controller: search,
        style: theme.ui(t.text, size: 12),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search titles and folders',
          prefixIcon: Icon(Icons.search, size: 14, color: t.textMuted),
          prefixIconConstraints: const BoxConstraints(minWidth: 26),
        ),
      ),
    );
    final filters = Segmented(
      value: filter,
      segments: [
        for (final f in HistoryFilter.values)
          if (f != HistoryFilter.leftover || counts[f]! > 0)
            (f, '${_labels[f]}  ${counts[f]}'),
      ],
      onChanged: onFilter,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 600
            ? Row(
                children: [
                  filters,
                  const Spacer(),
                  SizedBox(width: 220, child: field),
                ],
              )
            : Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: filters,
                  ),
                  field,
                ],
              ),
      ),
    );
  }
}

/// Under the table while rows are picked: how many and their size, and
/// clearing them together.
class HistorySelectionBar extends StatelessWidget {
  const new(
    this.picked, {
    required this.onDeselect,
    required this.onClear,
    super.key,
  });

  final List<HistoryRow> picked;
  final VoidCallback onDeselect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = picked.length;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              '$n selected · '
              '${diskSize(picked.fold(0, (s, r) => s + r.bytes))}',
              style: theme.ui(t.text),
            ),
          ),
          Button(label: 'Deselect', onPressed: onDeselect),
          Button(
            label: 'Clear $n ${n == 1 ? 'copy' : 'copies'}…',
            kind: ButtonKind.destructive,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

/// The table while the daemon hasn't answered: rows that are coming.
class HistoryLoading extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    Widget bar(double width) => Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: t.borderSubtle,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Semantics(
      key: const ValueKey('history-loading'),
      label: 'Loading',
      child: SettingsGroup(
        children: [
          for (var i = 0; i < 6; i++)
            SizedBox(
              height: historyRowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    bar(const [220.0, 160.0, 260.0][i % 3]),
                    const Spacer(),
                    bar(48),
                    const SizedBox(width: 24),
                    bar(56),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
