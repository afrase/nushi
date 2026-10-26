import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/commits.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The choices for how long copies are kept after they were last written,
/// in days; 0: for good.
const _keepFor = {0: 'Never', 30: '30 days', 90: '90 days', 365: '365 days'};

String _chats(int n) => n == 1 ? 'chat' : 'chats';

/// How many chats' copies show before "Show all".
const _rows = 5;

/// A size on disk: "840 KB", "12.4 MB", "1.2 GB".
String diskSize(int n) => switch (n) {
  < 1 << 20 => '${(n / 1024).ceil()} KB',
  < 1 << 30 => '${(n / (1 << 20)).toStringAsFixed(1)} MB',
  _ => '${(n / (1 << 30)).toStringAsFixed(1)} GB',
};

/// Settings' Transcripts: whether Nushi keeps its own read-only copy of
/// each chat's transcript (ADR 0047), what the copies take, chat by chat,
/// and clearing them: one, all, those older than some days, or on their
/// own after a while. [settings] is the daemon's (null until it said);
/// [onChange] changes them.
class TranscriptsSection extends StatefulWidget {
  const new({
    required this.client,
    required this.settings,
    required this.onChange,
    super.key,
  });

  final NushiServiceClient client;
  final Settings? settings;
  final Future<void> Function(void Function(Settings)) onChange;

  @override
  State<TranscriptsSection> createState() => _TranscriptsSectionState();
}

class _TranscriptsSectionState extends State<TranscriptsSection> {
  ListTranscriptsResponse? _list; // once the daemon said
  bool _all = false; // every chat's row shows
  final _older = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _older.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.client.listTranscripts(
        ListTranscriptsRequest(),
      );
      if (mounted) setState(() => _list = list);
    } on Object {
      // An older daemon: the sizes stay out.
    }
  }

  Future<void> _clear(ClearTranscriptsRequest req) async {
    await widget.client.clearTranscripts(req);
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

  Future<void> _clearAll() async {
    final total = _list?.totalBytes.toInt() ?? 0;
    if (await confirm(
      context,
      'Clear every copy?',
      "Deletes Nushi's copies of ${_list?.copies.length ?? 0} chats' "
          'transcripts (${diskSize(total)}). Chats go on, their history '
          'from their agents alone; a chat whose session its agent deleted '
          'goes with its copy.',
      'Clear all',
    )) {
      await _clear(ClearTranscriptsRequest(all: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final set = widget.settings;
    final list = _list;
    final value = theme.ui(t.text);
    final secondary = theme.ui(t.textSecondary);
    final copies = list?.copies ?? const <TranscriptCopy>[];
    final shown = _all ? copies : copies.take(_rows).toList();
    final days = set?.transcriptDays ?? 0;
    final now = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Transcripts',
              style: theme.ui(t.text, weight: FontWeight.w600),
            ),
            const Spacer(),
            if (set != null && set.hasKeepTranscripts())
              SizedBox(
                height: 20,
                child: FittedBox(
                  child: Switch(
                    value: set.keepTranscripts,
                    onChanged: (on) => tryOrShow(context, () => _keep(on)),
                  ),
                ),
              ),
          ],
        ),
        Text(
          "Nushi's own read-only copy of each chat, for the history its "
          'agent no longer replays. Never sent to an agent.',
          style: theme.ui(t.textSecondary, size: 12),
        ),
        if (set != null && set.hasTranscriptDays())
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text('Delete copies older than', style: secondary),
                const SizedBox(width: 10),
                Menu(
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
                  child: Text(_keepFor[days] ?? '$days days', style: value),
                ),
              ],
            ),
          ),
        if (list != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                copies.isEmpty
                    ? 'No copies'
                    : '${diskSize(list.totalBytes.toInt())} in '
                          '${copies.length} ${_chats(copies.length)}',
                style: value,
              ),
              const Spacer(),
              if (copies.isNotEmpty)
                Button(
                  label: 'Clear all',
                  onPressed: () => tryOrShow(context, _clearAll),
                ),
            ],
          ),
          for (final c in shown)
            _CopyRow(
              c,
              now: now,
              onClear: () => tryOrShow(
                context,
                () => _clear(ClearTranscriptsRequest(chatIds: [c.chatId])),
              ),
            ),
          if (copies.length > shown.length)
            Align(
              alignment: Alignment.centerLeft,
              child: Button(
                label: 'Show all ${copies.length}',
                onPressed: () => setState(() => _all = true),
              ),
            ),
          if (copies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Text('Clear copies older than', style: secondary),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 24,
                    child: TextField(
                      controller: _older,
                      style: value,
                      textAlign: TextAlign.end,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('days', style: secondary),
                  const SizedBox(width: 10),
                  Button(
                    label: 'Clear',
                    onPressed: () {
                      final n = int.tryParse(_older.text) ?? 0;
                      if (n < 1) return;
                      unawaited(
                        tryOrShow(
                          context,
                          () =>
                              _clear(ClearTranscriptsRequest(olderThanDays: n)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// One chat's copy: its title, size and last use, and Clear.
class _CopyRow extends StatelessWidget {
  const new(this.copy, {required this.now, required this.onClear});

  final TranscriptCopy copy;
  final DateTime now;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final when = DateTime.fromMillisecondsSinceEpoch(
      copy.lastWrittenMs.toInt(),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 8),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Text(
              copy.title.isEmpty ? 'A deleted chat' : copy.title,
              style: theme.ui(copy.title.isEmpty ? t.textMuted : t.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: 'Last used ${dateTime(when)}',
            child: Text(
              '${diskSize(copy.bytes.toInt())} · '
              '${ago(now.difference(when), when)}',
              style: theme.ui(t.textSecondary, size: 12),
            ),
          ),
          Button(label: 'Clear', onPressed: onClear),
        ],
      ),
    );
  }
}
