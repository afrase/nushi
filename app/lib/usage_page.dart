import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/sidebar_groups.dart' show twinParents;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage_chart.dart';
import 'package:nushi/usage_limits.dart';
import 'package:nushi/usage_parts.dart';
import 'package:nushi/usage_range.dart';
import 'package:nushi/usage_rows.dart';
import 'package:nushi/widgets.dart';

/// Settings › Usage (ADR 0136): what the agents' turns used over a span
/// of days ([usageRange]), as the daemon summed it: the totals, the
/// account limits an agent reported (only when one did), a chart by day,
/// the breakdowns by agent, model and project, and the costliest chats,
/// which open on a click. Asked for when the page opens and when the span
/// changes; nothing polls. The Mac's only: the phone has no such page.
class UsageSection extends StatefulWidget {
  const new({required this.daemon, super.key});

  final Daemon daemon;

  @override
  State<UsageSection> createState() => _UsageSectionState();
}

class _UsageSectionState extends State<UsageSection> {
  GetUsageResponse? _got; // the last answer, kept while another is asked
  String? _error; // why the last ask failed, until one doesn't
  bool _slow = false; // and has been for a moment: it says so
  Timer? _slowTimer;
  int _asks = 0; // which ask is the latest: an older answer is dropped

  // The usage asked for while the daemon was gone.
  late final _again = LoadAgain(widget.daemon, () {
    if (mounted) unawaited(_load());
  });

  Daemon get daemon => widget.daemon;

  bool get _api => daemon.daemonApi >= usageApi;

  @override
  void initState() {
    super.initState();
    if (_api) unawaited(_load());
  }

  @override
  void dispose() {
    _again.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _again.cancel();
    final ask = ++_asks;
    _slowTimer?.cancel();
    _slowTimer = Timer(Waits.loading, () {
      if (mounted && ask == _asks) setState(() => _slow = true);
    });
    try {
      final got = await daemon.client.getUsage(
        usageRange.value.request(clock()),
      );
      if (!mounted || ask != _asks) return;
      setState(() {
        _got = got;
        _error = null;
      });
    } on Object catch (e) {
      if (!mounted || ask != _asks) return;
      setState(() => _error = errorText(e));
      _again.failed(e);
    } finally {
      if (mounted && ask == _asks) {
        _slowTimer?.cancel();
        setState(() => _slow = false);
      }
    }
  }

  void _pick(UsageRange r) {
    if (r == usageRange.value) return;
    setState(() => usageRange.value = r);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final muted = theme.ui(theme.t.textMuted, size: 12);
    if (!_api) {
      return const SettingsPage(
        title: 'Usage',
        children: [
          UsageNote(
            key: ValueKey('usage-old-daemon'),
            'Usage shows once the daemon restarts into this version: it '
            'started before Nushi was updated',
          ),
        ],
      );
    }
    final got = _got;
    return SettingsPage(
      title: 'Usage',
      actions: [
        if (_slow && got != null) Text('Reading…', style: muted),
        Segmented(
          key: const ValueKey('usage-range'),
          value: usageRange.value,
          segments: [for (final r in UsageRange.values) (r, r.label)],
          onChanged: _pick,
        ),
      ],
      children: [
        if (_error case final e?)
          SettingsGroup(
            children: [
              SettingsRow(
                "Couldn't read usage",
                description: e,
                descriptionColor: theme.t.crashed,
                control: RunButton(label: 'Try again', run: _load),
              ),
            ],
          ),
        if (got == null)
          if (_slow && _error == null)
            Text('Reading…', key: const ValueKey('usage-reading'), style: muted)
          else
            const SizedBox()
        else
          ..._report(context, got),
      ],
    );
  }

  /// The page for [r]: nothing yet, nothing in the span, or its figures.
  List<Widget> _report(BuildContext context, GetUsageResponse r) {
    if (r.earliest == 0) {
      return [
        const UsageNote(
          key: ValueKey('usage-none'),
          'Nothing yet: usage is counted from now, turn by turn',
        ),
        if (r.limits.isNotEmpty) UsageLimits(r.limits),
      ];
    }
    final range = usageRange.value;
    final used = r.totals.turns > 0 || tokensOf(r.totals) > 0;
    final measure = UsageMeasure.mostSpent(r.totals);
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    final earliest = DateTime.fromMillisecondsSinceEpoch(r.earliest.toInt());
    return [
      if (used)
        UsageTotalsCard(r, measure)
      else
        UsageNote(
          key: const ValueKey('usage-quiet'),
          range == UsageRange.all
              ? 'Nothing used'
              : 'Nothing used in the last ${range.label}',
        ),
      if (r.limits.isNotEmpty) UsageLimits(r.limits),
      if (used) ...[
        SettingsGroup(
          title: measure.costs ? 'Spend by day' : 'Tokens by day',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 18, 8),
              child: UsageDayChart(
                days: r.days,
                first: range.from(now) ?? _first(earliest, today),
                today: today,
                measure: measure,
              ),
            ),
          ],
        ),
        _breakdown(
          'By agent',
          r.agents,
          measure,
          label: agentTitle,
          lead: AgentMark.new,
        ),
        _breakdown(
          'By model',
          r.models,
          measure,
          label: (k) => k.isEmpty ? 'Not named' : plainName(k),
          muted: (k) => k.isEmpty,
        ),
        _projects(r.folders, measure),
        _chats(r.chats, measure),
      ],
      UsageFootnote(earliest, costs: measure.costs),
    ];
  }

  /// The chart's first day for All: the first turn's, a week back at
  /// least, so a few days' bars aren't each half the chart.
  DateTime _first(DateTime earliest, DateTime today) {
    final week = DateTime(today.year, today.month, today.day - 6);
    return earliest.isBefore(week)
        ? DateTime(earliest.year, earliest.month, earliest.day)
        : week;
  }

  /// A breakdown's group: a row for each of [groups], the most first.
  Widget _breakdown(
    String title,
    List<UsageGroup> groups,
    UsageMeasure measure, {
    required String Function(String key) label,
    Widget Function(String key)? lead,
    String Function(String key)? tip,
    bool Function(String key)? muted,
  }) {
    final sorted = _ranked(groups, measure);
    final top = sorted.isEmpty ? 0.0 : measure.of(sorted.first.totals);
    return SettingsGroup(
      title: title,
      actions: [UsageColumnsHead(measure)],
      children: [
        for (final g in sorted)
          UsageBarRow(
            label: label(g.key),
            totals: g.totals,
            measure: measure,
            top: top,
            lead: lead?.call(g.key),
            tip: tip?.call(g.key) ?? '',
            muted: muted?.call(g.key) ?? false,
          ),
      ],
    );
  }

  /// By project: each folder by the name the sidebar gives it, its
  /// parent's after it where two share a name, its path under the
  /// pointer.
  Widget _projects(List<UsageGroup> folders, UsageMeasure measure) {
    final twins = twinParents([for (final f in folders) f.key]);
    return _breakdown(
      'By project',
      folders,
      measure,
      label: (f) => switch ((f, twins[f])) {
        ('', _) => 'No folder',
        (_, final twin?) => '${folderParts(f).$1} · $twin',
        _ => folderParts(f).$1,
      },
      tip: (f) => f.isEmpty ? '' : tildePath(f),
      muted: (f) => f.isEmpty,
    );
  }

  /// The costliest chats, as the daemon ranked them; one that's still
  /// here opens on a click, leaving Settings.
  Widget _chats(List<UsageChat> chats, UsageMeasure measure) => SettingsGroup(
    title: measure.costs ? 'Costliest chats' : 'Chats that used the most',
    children: [
      for (final c in chats)
        UsageChatRow(
          c,
          measure: measure,
          onOpen: daemon.chats.containsKey(c.chatId)
              ? () => daemon.select(c.chatId)
              : null,
        ),
    ],
  );
}

/// [groups] by [measure], the most first, then by tokens.
List<UsageGroup> _ranked(List<UsageGroup> groups, UsageMeasure measure) =>
    [...groups]..sort((a, b) {
      final by = measure.of(b.totals).compareTo(measure.of(a.totals));
      return by != 0 ? by : tokensOf(b.totals).compareTo(tokensOf(a.totals));
    });
