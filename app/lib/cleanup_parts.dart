import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A row to tick: what, its name in code, why it is as it is.
class CleanUpChoice extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
    this.code,
    this.what,
    this.note,
    this.extra,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? code;
  final String? what;
  final String? note;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final on = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            height: 22,
            child: Checkbox(
              value: value,
              visualDensity: VisualDensity.compact,
              onChanged: on ? (v) => onChanged!(v ?? false) : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  label,
                  style: theme.ui(
                    on ? t.text : t.textMuted,
                    weight: FontWeight.w500,
                  ),
                ),
                if (code case final c?)
                  Text(c, style: theme.code(t.textMuted, size: 11.5)),
                if (what case final w?)
                  Text(w, style: theme.ui(t.textSecondary, size: 12)),
                if (note case final n?)
                  Text(n, style: theme.ui(t.needs, size: 12)),
                if (extra case final e?)
                  Padding(padding: const EdgeInsets.only(top: 4), child: e),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The uncommitted changes removing the worktree would lose, and Show the
/// changes.
class DirtyWorktree extends StatelessWidget {
  const new(this.u, {required this.onShow, super.key});

  final GetCleanUpResponse u;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = u.state.changed;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: box(t.findingsBorder, fill: t.findingsTint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 3,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: t.findingsAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  n == 1
                      ? '1 uncommitted file would be lost.'
                      : '$n uncommitted files would be lost.',
                  style: theme.ui(t.text, size: 12.5, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
          for (final c in u.changes)
            Text(c, style: theme.code(t.textSecondary, size: 11.5)),
          if (n > u.changes.length)
            Text(
              'and ${n - u.changes.length} more',
              style: theme.ui(t.textMuted, size: 12),
            ),
          LinkText('Show the changes', size: 12, onTap: onShow),
        ],
      ),
    );
  }
}

/// The chat is mid-turn: clean up when the turn ends, or stop it now.
class MidTurnChoice extends StatelessWidget {
  const new({
    required this.agent,
    required this.stop,
    required this.onChanged,
    super.key,
  });

  final String agent;
  final bool stop;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget choice(String words, {required bool value}) => Tap(
      onTap: () => onChanged(value),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(
        children: [
          Icon(
            stop == value
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 16,
            color: stop == value ? t.accentInk : t.textMuted,
          ),
          const SizedBox(width: 8),
          Text(words, style: theme.ui(t.text, size: 12.5)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: box(t.userBandBorder, fill: t.accentSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$agent is mid-turn here.',
            style: theme.ui(t.text, weight: FontWeight.w500),
          ),
          choice('Clean up when the turn ends', value: false),
          choice('Stop the turn, clean up now', value: true),
        ],
      ),
    );
  }
}
