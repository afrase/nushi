import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/history_parts.dart';
import 'package:nushi/history_table.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings_general.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The choices for how long copies are kept after they were last written,
/// in days; 0: for good.
const _keepFor = {0: 'Never', 30: '30 days', 90: '90 days', 365: '365 days'};

String _chats(int n) => n == 1 ? 'chat' : 'chats';

/// Settings › Chat history: whether Nushi keeps its own read-only copy of
/// each chat's transcript (ADR 0047), what they take, and a table of
/// them, built as it scrolls (the daemon lists them all at once: 5,000
/// list in about 0.15 s): sorted, searched, filtered, picked one by one
/// or by range, cleared one at a time or together. [settings] is the
/// daemon's (null until it said).
class HistorySection extends StatefulWidget {
  const new({
    required this.daemon,
    required this.settings,
    required this.onChange,
    super.key,
  });

  final Daemon daemon;
  final Settings? settings;
  final SettingsChange onChange;

  @override
  State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<HistorySection> {
  ListTranscriptsResponse? _list; // once the daemon said
  String? _error; // why it didn't, until it does
  bool _slow = false; // no answer after 150 ms: rows that are coming
  late final Timer _slowTimer;
  HistoryFilter _filter = HistoryFilter.all;
  HistorySort _sort = HistorySort.size;
  bool _up = false;
  final _search = TextEditingController();
  final _selected = <String>{};
  String? _anchor; // where a ⇧-click's range starts
  List<HistoryRow> _view = []; // as shown, in order

  // The rows, their counts and the view as last made, and from what: a
  // click (picking rows) builds again without making and sorting 5,000
  // rows anew. The rows read the daemon's chats, so they're made again
  // once it changed.
  List<HistoryRow> _rows = [];
  Map<HistoryFilter, int> _counts = {};
  ListTranscriptsResponse? _rowsOf;
  bool _chatsChanged = false;
  Object? _viewOf;

  void _daemonChanged() => _chatsChanged = true;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _slow = true);
    });
    unawaited(_load());
    _search.addListener(() => setState(() {}));
    widget.daemon.addListener(_daemonChanged);
  }

  @override
  void dispose() {
    widget.daemon.removeListener(_daemonChanged);
    _slowTimer.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.daemon.client.listTranscripts(
        ListTranscriptsRequest(),
      );
      if (!mounted) return;
      setState(() {
        _list = list;
        _error = null;
        final ids = {for (final c in list.copies) c.chatId};
        _selected.retainWhere(ids.contains);
      });
    } on Object catch (e) {
      // Said in the table's place, not rows coming for good.
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  Future<void> _clear(ClearTranscriptsRequest req) async {
    await widget.daemon.client.clearTranscripts(req);
    await _load();
  }

  /// Turning copies off asks what becomes of those there are.
  Future<void> _keep(bool on) async {
    final total = _list?.totalBytes.toInt() ?? 0;
    if (on || total == 0) {
      await widget.onChange((s) => s.keepTranscripts = on);
      return;
    }
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => nushiDialog(
        'Stop keeping transcripts?',
        Text(
          "Nushi's copies take ${diskSize(total)}. Kept, they still show "
          'what agents no longer replay. A chat whose session its agent '
          'deleted is kept only for its copy: deleting the copies removes '
          'it.',
        ),
        [
          Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
          Button(
            label: 'Delete copies',
            kind: ButtonKind.destructive,
            onPressed: () => Navigator.pop(context, true),
          ),
          Button(
            label: 'Keep copies',
            kind: ButtonKind.primary,
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (delete == null) return;
    await widget.onChange((s) => s.keepTranscripts = false);
    if (delete) await _clear(ClearTranscriptsRequest(all: true));
  }

  /// Clears [rows]' copies once asked ([all]: every copy there is).
  Future<void> _clearMany(List<HistoryRow> rows, {bool all = false}) async {
    final bytes = rows.fold(0, (n, r) => n + r.bytes);
    final n = rows.length;
    final whose = n == 1 ? "chat's" : "chats'";
    if (!await confirm(
      context,
      all ? 'Clear every copy?' : 'Clear $n ${n == 1 ? 'copy' : 'copies'}?',
      "Deletes Nushi's copies of $n $whose transcripts "
      '(${diskSize(bytes)}). Chats go on, their history from their '
      'agents alone; a chat whose session its agent deleted goes with '
      'its copy.',
      all ? 'Clear all' : 'Clear',
      destructive: true,
    )) {
      return;
    }
    await _clear(
      all
          ? ClearTranscriptsRequest(all: true)
          : ClearTranscriptsRequest(chatIds: [for (final r in rows) r.id]),
    );
    if (mounted) {
      setState(
        () => all
            ? _selected.clear()
            : _selected.removeAll([for (final r in rows) r.id]),
      );
    }
  }

  /// A click on a row: it alone, ⌘ adds or takes it away, ⇧ the range
  /// from the last one clicked.
  void _tap(HistoryRow row) {
    final keys = HardwareKeyboard.instance;
    setState(() {
      final from = _view.indexWhere((r) => r.id == _anchor);
      if (keys.isShiftPressed && from >= 0) {
        final to = _view.indexOf(row);
        final (a, b) = from < to ? (from, to) : (to, from);
        _selected
          ..clear()
          ..addAll([for (final r in _view.sublist(a, b + 1)) r.id]);
        return;
      }
      if (keys.isMetaPressed) {
        if (!_selected.remove(row.id)) _selected.add(row.id);
      } else if (_selected.length == 1 && _selected.contains(row.id)) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..add(row.id);
      }
      _anchor = row.id;
    });
  }

  void _sortBy(HistorySort by) => setState(() {
    // Again: the other way round. Sizes and dates start with the largest
    // and newest, titles from A.
    _up = by == _sort ? !_up : by == HistorySort.title;
    _sort = by;
  });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final set = widget.settings;
    final list = _list;
    if (!identical(list, _rowsOf) || _chatsChanged) {
      _rowsOf = list;
      _chatsChanged = false;
      final rows = _rows = [
        for (final c in list?.copies ?? const <TranscriptCopy>[])
          HistoryRow(c, widget.daemon.chats[c.chatId]),
      ];
      _counts = {
        HistoryFilter.all: rows.length,
        HistoryFilter.archived: rows.where((r) => r.archived).length,
        HistoryFilter.gone: rows.where((r) => r.gone).length,
        HistoryFilter.leftover: rows.where((r) => r.leftover).length,
      };
    }
    final (rows, counts) = (_rows, _counts);
    // A filter left with nothing to show (its rows cleared) goes.
    final filter = counts[_filter] == 0 ? HistoryFilter.all : _filter;
    final viewOf = (rows, filter, _search.text, _sort, _up);
    if (viewOf != _viewOf) {
      _viewOf = viewOf;
      _view = historyView(
        rows,
        filter: filter,
        query: _search.text,
        sort: _sort,
        up: _up,
      );
    }
    final view = _view;
    final picked = [
      for (final r in view)
        if (_selected.contains(r.id)) r,
    ];
    final days = set?.transcriptDays ?? 0;
    return SettingsPage(
      title: 'Chat history',
      slivers: [
        SliverLayoutBuilder(
          builder: (context, c) {
            final wide = historyWide(c.crossAxisExtent);
            if (list == null) {
              return SliverToBoxAdapter(
                child: switch (_error) {
                  final e? => SettingsGroup(
                    children: [
                      SettingsRow(
                        "Couldn't list the copies",
                        description: e,
                        descriptionColor: NushiTheme.of(context).t.crashed,
                        control: RunButton(label: 'Try again', run: _load),
                      ),
                    ],
                  ),
                  null when _slow => const HistoryLoading(),
                  null => const SizedBox(),
                },
              );
            }
            if (view.isEmpty) {
              return SliverToBoxAdapter(
                child: SettingsGroup(
                  children: [
                    SettingsRow(
                      rows.isEmpty ? 'No copies yet' : 'No chats match',
                    ),
                  ],
                ),
              );
            }
            final now = clock();
            return DecoratedSliver(
              decoration: box(t.borderSubtle, fill: t.raised, radius: 8),
              sliver: SliverMainAxisGroup(
                slivers: [
                  PinnedHeaderSliver(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                      child: HistoryHeader(
                        sort: _sort,
                        up: _up,
                        wide: wide,
                        onSort: _sortBy,
                      ),
                    ),
                  ),
                  SliverFixedExtentList.builder(
                    itemExtent: historyRowHeight,
                    itemCount: view.length,
                    itemBuilder: (context, i) {
                      final r = view[i];
                      final row = HistoryRowView(
                        r,
                        key: ValueKey('history-${r.id}'),
                        wide: wide,
                        last: i == view.length - 1,
                        selected: _selected.contains(r.id),
                        now: now,
                        onTap: () => _tap(r),
                        onOpen: r.chat == null
                            ? null
                            : () => widget.daemon.select(r.id),
                        // At once, unless the copy is all there is: then
                        // the chat goes with it, which is asked first.
                        onClear: () => tryOrShow(
                          context,
                          () => r.gone
                              ? _clearMany([r])
                              : _clear(
                                  ClearTranscriptsRequest(chatIds: [r.id]),
                                ),
                        ),
                      );
                      return row;
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
      bottom: picked.isEmpty
          ? null
          : HistorySelectionBar(
              picked,
              onDeselect: () => setState(_selected.clear),
              onClear: () => tryOrShow(context, () => _clearMany(picked)),
            ),
      children: [
        SettingsGroup(
          children: [
            if (set != null && set.hasKeepTranscripts())
              SettingsRow(
                'Keep transcripts',
                description:
                    "Nushi's own read-only copy of each chat, for the history "
                    'its agent no longer replays. Never sent to an agent.',
                control: SettingsSwitch(
                  value: set.keepTranscripts,
                  onChanged: (on) => tryOrShow(context, () => _keep(on)),
                ),
              ),
            if (list != null)
              SettingsRow(
                'Copies',
                description: rows.isEmpty
                    ? 'None'
                    : '${diskSize(list.totalBytes.toInt())} in '
                          '${rows.length} ${_chats(rows.length)}',
                control: Button(
                  label: 'Clear all…',
                  kind: ButtonKind.destructive,
                  onPressed: rows.isEmpty
                      ? null
                      : () => tryOrShow(
                          context,
                          () => _clearMany(rows, all: true),
                        ),
                ),
              ),
            if (set != null && set.hasTranscriptDays())
              SettingsRow(
                'Delete copies older than',
                description: 'By when a copy was last written; checked hourly.',
                control: MenuField(
                  entries: [
                    for (final MapEntry(:key, :value) in {
                      ..._keepFor,
                      days: _keepFor[days] ?? '$days days',
                    }.entries)
                      MenuEntry(
                        value,
                        checked: key == days,
                        onPick: () => tryOrShow(
                          context,
                          () => widget.onChange((s) => s.transcriptDays = key),
                        ),
                      ),
                  ],
                  label: Text(_keepFor[days] ?? '$days days'),
                ),
              ),
          ],
        ),
        if (rows.isNotEmpty)
          HistoryToolbar(
            search: _search,
            filter: filter,
            counts: counts,
            onFilter: (f) => setState(() => _filter = f),
          ),
      ],
    );
  }
}
