import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/message_actions.dart' show fullTime;
import 'package:nushi/plain_text.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage_rows.dart';
import 'package:nushi/widgets.dart';

// Settings › Usage's account limits (ADR 0136): only what an agent
// reported of itself, as last seen, never shown as live.

/// The account limits agents reported, a row each, and that they're as
/// last seen: an agent says them only while one of its chats runs.
class UsageLimits extends StatelessWidget {
  const new(this.limits, {super.key});

  final List<UsageLimit> limits;

  @override
  Widget build(BuildContext context) {
    final agents = {for (final l in limits) agentTitle(l.agent)};
    return SettingsGroup(
      key: const ValueKey('usage-limits'),
      title: 'Limits',
      footer: Text(
        'As ${andList(agents)} last said them: they change only while '
        'one of ${agents.length == 1 ? 'its' : 'their'} chats runs.',
      ),
      children: [for (final l in limits) UsageLimitRow(l)],
    );
  }
}

/// The name of a limit's window as the agent names it ("five_hour").
String limitName(String kind) => switch (kind) {
  'five_hour' => '5-hour',
  'seven_day' => 'Weekly',
  'seven_day_opus' => 'Weekly, Opus',
  'seven_day_sonnet' => 'Weekly, Sonnet',
  'overage' => 'Extra usage',
  '' => 'Limit',
  _ => capital(kind.replaceAll('_', ' ')),
};

/// When a limit resets, seen from [now]: "Resets in 1h 05m" within a day,
/// else its date and time; "Reset Oct 29, 2026, 9:00 AM" once past, as
/// nothing newer was seen since; '' unknown.
String resetWords(int ms, DateTime now) {
  if (ms == 0) return '';
  final at = DateTime.fromMillisecondsSinceEpoch(ms);
  final left = at.difference(now);
  if (left.isNegative) return 'Reset ${fullTime(at)}';
  if (left.inHours < 24) {
    final m = left.inMinutes % 60;
    return left.inHours == 0
        ? 'Resets in ${max(m, 1)}m'
        : 'Resets in ${left.inHours}h ${two(m)}m';
  }
  return 'Resets ${fullTime(at)}';
}

/// An account limit as its agent last reported it ([limit]): the agent
/// and the window, its state in a pill, how much is used on a meter (when
/// the agent said), when it resets, and when it was seen: it changes only
/// while a chat of that agent runs, so it's never shown as live.
class UsageLimitRow extends StatelessWidget {
  const new(this.limit, {super.key});

  final UsageLimit limit;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final now = clock();
    final (word, tone) = switch (limit.status) {
      'allowed' => ('Within the limit', NoteTone.done),
      'allowed_warning' => ('Near the limit', NoteTone.needs),
      'rejected' => ('Limit reached', NoteTone.crashed),
      '' => ('Not said', NoteTone.quiet),
      final s => (capital(s.replaceAll('_', ' ')), NoteTone.quiet),
    };
    final ink = switch (tone) {
      NoteTone.needs => t.needs,
      NoteTone.crashed => t.crashed,
      _ => t.accent,
    };
    final used = limit.hasUtilization() ? limit.utilization : null;
    final seen = limit.seen.toInt();
    final muted = theme.ui(t.textMuted, size: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 7,
        children: [
          Row(
            children: [
              SizedBox(width: 16, child: Center(child: AgentMark(limit.agent))),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${agentTitle(limit.agent)} ${limitName(limit.kind)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text),
                ),
              ),
              const SizedBox(width: 8),
              NotePill(
                word,
                key: ValueKey('usage-limit-${limit.agent}-${limit.kind}'),
                tone: tone,
              ),
              if (used != null) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(used * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: tabular(theme.ui(t.text, weight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
          if (used != null) ShareBar(used, color: ink),
          // When it resets, then when it was seen on a line of its own:
          // a date's own commas aren't run into.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              if (resetWords(limit.resetsAt.toInt(), now) case final r
                  when r.isNotEmpty)
                Text(r, style: muted),
              if (seen == 0)
                Text('when seen unknown', style: muted)
              else
                tooltip(
                  context,
                  fullTime(DateTime.fromMillisecondsSinceEpoch(seen)),
                  Text('as of ${agoAt(seen, now)}', style: muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
