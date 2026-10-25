import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'file_tree.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// A branch's commits, newest first: subject, short hash, how long ago,
/// `+n −m`. A click picks one; a shift-click picks the range from the
/// first pick to it ([onPick] says which and whether to extend).
class CommitList extends StatelessWidget {
  const new({
    super.key,
    required this.commits,
    required this.picked,
    required this.onPick,
  });

  static const rowHeight = 44.0;

  final List<Commit> commits;
  final (int, int)? picked; // the first and last index picked
  final void Function(int index, {required bool extend}) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final now = DateTime.now();
    return ListView.builder(
      itemExtent: rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      itemCount: commits.length,
      itemBuilder: (context, i) {
        final c = commits[i];
        final p = picked;
        final when = DateTime.fromMillisecondsSinceEpoch(
          c.unixSeconds.toInt() * 1000,
        );
        return Tap(
          onTap: () =>
              onPick(i, extend: HardwareKeyboard.instance.isShiftPressed),
          selected: p != null && i >= p.$1 && i <= p.$2,
          tooltip: c.subject,
          padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                c.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.text),
              ),
              Row(
                children: [
                  Text(c.short, style: theme.code(t.textMuted, size: 11)),
                  Expanded(
                    child: Text(
                      '  ${ago(now.difference(when), when)}',
                      maxLines: 1,
                      style: theme.ui(t.textMuted, size: 11.5),
                    ),
                  ),
                  LineCounts(c.added, c.removed),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// How long ago [when] was ([age]): "just now", "5m ago", "3h ago",
/// "2d ago", then the date.
String ago(Duration age, DateTime when) => switch (age) {
  _ when age.inMinutes < 1 => 'just now',
  _ when age.inHours < 1 => '${age.inMinutes}m ago',
  _ when age.inDays < 1 => '${age.inHours}h ago',
  _ when age.inDays < 30 => '${age.inDays}d ago',
  _ => '${when.year}-${_two(when.month)}-${_two(when.day)}',
};

String _two(int n) => '$n'.padLeft(2, '0');
