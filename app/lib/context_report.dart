import 'package:flutter/material.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';
import 'package:nushi/widgets.dart';

/// A list /context gives beside its categories (MCP tools, custom agents,
/// skills, memory files…): its name as the rail words it and its rows,
/// each a name and its tokens (0 when not said).
typedef ContextList = ({String name, List<(String, int)> rows});

/// The lists in /context's answer, [markdown], after its "Estimated usage
/// by category" table: each `### Heading` over a table, in its order, its
/// rows' first cell and last cell's count. Claude's private format, as the
/// daemon reads the categories (ADR 0017); nothing when it isn't there.
List<ContextList> contextLists(String markdown) {
  final (_, sep, rest) = _cut(markdown, '### Estimated usage by category');
  if (sep.isEmpty) return const [];
  final out = <ContextList>[];
  String? name;
  var rows = <(String, int)>[];
  void flush() {
    if (name case final n? when rows.isNotEmpty) {
      out.add((name: n, rows: rows));
    }
    rows = [];
  }

  for (final line in rest.split('\n').skip(1)) {
    final l = line.trim();
    if (l.startsWith('###')) {
      flush();
      name = _sentence(l.substring(3).trim());
      continue;
    }
    if (name == null || !l.startsWith('|')) continue;
    final cells = [
      for (final c
          in l.substring(1, l.endsWith('|') ? l.length - 1 : null).split('|'))
        c.trim(),
    ];
    if (cells.length < 2 || cells.every((c) => c.startsWith('-'))) continue;
    final n = _count(cells.last);
    if (n == null) continue; // the header
    rows.add((cells.first, n));
  }
  flush();
  return out;
}

(String, String, String) _cut(String s, String sep) {
  final i = s.indexOf(sep);
  return i < 0 ? (s, '', '') : (s.substring(0, i), sep, s.substring(i));
}

/// "MCP Tools" as the rail words it: "MCP tools".
String _sentence(String heading) {
  String word(int i, String w) =>
      i == 0 || w == w.toUpperCase() ? w : w.toLowerCase();
  return [for (final (i, w) in heading.split(' ').indexed) word(i, w)]
      .join(' ');
}

/// A count as Claude writes it in its lists: 153, ~480, 2.5k, 1.2m.
int? _count(String s) {
  var v = s.replaceAll('~', '').replaceAll(',', '').toLowerCase();
  var mult = 1.0;
  if (v.endsWith('k')) (mult, v) = (1e3, v.substring(0, v.length - 1));
  if (v.endsWith('m')) (mult, v) = (1e6, v.substring(0, v.length - 1));
  final n = double.tryParse(v);
  return n == null ? null : (n * mult).round();
}

/// A token count as Claude's rail writes it, to a tenth however large:
/// 314, 2k, 545.5k, 1M.
String fineTokens(int n) {
  String tenth(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  return n < 1000
      ? '$n'
      : n < 1000000
      ? '${tenth(n / 1000)}k'
      : '${tenth(n / 1000000)}M';
}

bool _buffer(ContextCategory c) => c.name == 'Autocompact buffer';

/// How far the context is from its compaction, by [cs]: the free space,
/// when the agent counts a buffer it compacts into; null without one.
int? untilCompact(List<ContextCategory> cs) {
  if (!cs.any(_buffer)) return null;
  final free = cs.where((c) => c.kind == 'free');
  return free.isEmpty ? null : free.first.tokens.toInt();
}

/// What's used of the context and its size: as the agent reported them in
/// [u], else as [cs] count them (what's in it but the free space and the
/// buffer, over all that's in it); null when neither says.
(int, int)? contextUsedOf(Usage u, List<ContextCategory> cs) {
  if (u.contextSize > 0) return (u.contextUsed.toInt(), u.contextSize.toInt());
  final inside = cs.where((c) => c.kind != 'deferred');
  final size = inside.fold(0, (n, c) => n + c.tokens.toInt());
  if (size == 0) return null;
  final used = inside
      .where((c) => c.kind == '' && !_buffer(c))
      .fold(0, (n, c) => n + c.tokens.toInt());
  return (used, size);
}

/// The Context widget's block, as Claude Code's rail draws it: "N% used"
/// and "used / size" on a line, a bar split by kind, then (when the agent
/// said what fills it, [categories]) a row per kind, largest first, with its
/// color, count and share in columns, the buffer and the free space last;
/// the deferred ones dimmed with a dash; [lists], each a row that opens;
/// and "N until auto-compact", with Compact (Claude's Compact session) when
/// there's [onCompact]. Only the line and the bar for an agent that reports
/// a total; nothing for one that reports neither.
class ContextReport extends StatelessWidget {
  const new(
    this.usage, {
    super.key,
    this.categories = const [],
    this.lists = const [],
    this.onCompact,
  });

  final Usage usage;
  final List<ContextCategory> categories;
  final List<ContextList> lists;
  final VoidCallback? onCompact;

  /// The color of a kind, as Claude's rail gives its four largest kinds;
  /// the rest grey, the buffer darker, the free space only a square.
  static Color colorOf(Tokens t, ContextCategory c) => switch (c.name) {
    _ when c.kind == 'free' => t.borderSubtle,
    _ when c.kind == 'deferred' => t.borderStrong,
    'Messages' => t.accent,
    'System tools' => t.claude,
    'Skills' => t.done,
    'System prompt' => t.needs,
    'Autocompact buffer' => t.borderStrong,
    _ => t.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final at = contextUsedOf(usage, categories);
    if (at == null) return const SizedBox.shrink();
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final (used, size) = at;
    final fill = (used / size).clamp(0.0, 1.0);
    final inside = [...categories.where((c) => c.kind == '' && !_buffer(c))]
      ..sort((a, b) => b.tokens.compareTo(a.tokens));
    final rows = [
      ...inside,
      ...categories.where(_buffer),
      ...categories.where((c) => c.kind == 'free'),
    ];
    final later = categories.where((c) => c.kind == 'deferred').toList();
    final until = untilCompact(categories);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${(fill * 100).round()}% used',
                style: theme.ui(fillColor(t, fill, t.text)),
              ),
            ),
            Text(
              '${fineTokens(used)} / ${fineTokens(size)}',
              style: theme.ui(t.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _Bar(
          parts: [
            for (final c in rows)
              if (c.kind != 'free' && c.tokens > 0)
                (colorOf(t, c), c.tokens.toInt() / size),
          ],
          // Without the kinds, the bar is the share used.
          fill: rows.isEmpty ? fill : null,
        ),
        if (rows.isNotEmpty) const SizedBox(height: 8),
        for (final c in rows) _row(theme, c),
        if (later.isNotEmpty) const SizedBox(height: 8),
        for (final c in later) _row(theme, c, dim: true),
        if (lists.isNotEmpty) const SizedBox(height: 8),
        for (final l in lists) _ListRow(l),
        if (until != null) ...[
          const SizedBox(height: 10),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  '${fineTokens(until)} until auto-compact',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.textMuted),
                ),
              ),
              if (onCompact case final compact?)
                Button(
                  // "Compact session" in Claude's rail: too wide beside the
                  // line at Nushi's type (ADR 0092).
                  label: 'Compact',
                  tooltip:
                      'Compact the session: the agent summarizes the '
                      'conversation so far',
                  onPressed: compact,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _row(NushiTheme theme, ContextCategory c, {bool dim = false}) {
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PanelType.rowGap),
      child: Row(
        children: [
          _Square(colorOf(t, c)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // The daemon reads "MCP tools (deferred)" as its kind.
              dim ? '${c.name} (deferred)' : c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(dim ? t.textMuted : t.textSecondary),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              fineTokens(c.tokens.toInt()),
              textAlign: TextAlign.right,
              style: theme.ui(dim ? t.textMuted : t.textSecondary),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              dim ? '—' : '${c.percent.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: theme.ui(dim ? t.textMuted : t.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// A kind's small square of color.
class _Square extends StatelessWidget {
  const new(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

/// A thin bar on a quiet track: [parts] in their colors, each its share of
/// the width (a sliver at least), or one part, [fill] of it, in the
/// text's color.
class _Bar extends StatelessWidget {
  const new({required this.parts, this.fill});

  final List<(Color, double)> parts;
  final double? fill;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: ColoredBox(
          color: t.borderSubtle,
          child: LayoutBuilder(
            builder: (context, box) {
              final all = [
                if (fill case final f?)
                  (fillColor(t, f, t.textSecondary), f)
                else
                  ...parts,
              ];
              final widths = [
                for (final (_, share) in all)
                  (share * box.maxWidth).clamp(1.5, box.maxWidth),
              ];
              final total = widths.fold(0.0, (w, p) => w + p);
              final scale = total > box.maxWidth ? box.maxWidth / total : 1.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (color, _)) in all.indexed)
                    SizedBox(
                      width: widths[i] * scale,
                      child: ColoredBox(color: color),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A list's row: a chevron, its name and how many it has; a click opens
/// its rows (each a name and its tokens) under it.
class _ListRow extends StatefulWidget {
  const new(this.list);

  final ContextList list;

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final l = widget.list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tap(
          onTap: () => setState(() => _open = !_open),
          tint: false,
          padding: const EdgeInsets.symmetric(vertical: PanelType.rowGap),
          child: Row(
            children: [
              SizedBox(width: 10, child: Chevron(open: _open)),
              const SizedBox(width: 10),
              Expanded(child: Text(l.name, style: theme.ui(t.textSecondary))),
              Text('${l.rows.length}', style: theme.ui(t.textMuted)),
            ],
          ),
        ),
        if (_open)
          for (final (name, n) in l.rows)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 0, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(t.textMuted, size: PanelType.detail),
                    ),
                  ),
                  if (n > 0)
                    Text(
                      tokens(n),
                      style: theme.ui(t.textMuted, size: PanelType.detail),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
