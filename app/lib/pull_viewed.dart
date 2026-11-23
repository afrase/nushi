import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Which of a pull request's files the user marked viewed, as GitHub keeps
/// it for them (their Files changed's Viewed checkboxes): read when the
/// Files tab shows and when the head moves (a push makes some "changed
/// since last view"), set at once on a click and written to GitHub, put
/// back if GitHub refuses it.
class PullViewed extends ChangeNotifier {
  new(this.daemon, this.pull);

  final Daemon daemon;

  /// The pull request, as last read.
  GitHubPull pull;

  /// The paths viewed; null until GitHub said, or from a daemon before
  /// [viewedApi].
  Set<String>? viewed;

  /// The paths viewed before a change since: unticked, GitHub's "Changed
  /// since last view".
  Set<String> changed = const {};

  bool get _can => daemon.daemonApi >= viewedApi;

  /// Asks GitHub.
  Future<void> load() async {
    if (!_can) return;
    final head = pull.headOid;
    try {
      final r = await daemon.client.getGitHubViewed(
        GetGitHubViewedRequest(ref: pull.item.ref),
      );
      if (head != pull.headOid) return; // another head is asked for
      viewed = r.viewed.toSet();
      changed = r.changed.toSet();
      notifyListeners();
    } on Object {
      // Without them the files show unticked, as they would on GitHub
      // until it answered.
    }
  }

  /// Marks [path] viewed or not; GitHub's refusal is thrown, what showed
  /// put back.
  Future<void> set(String path, {required bool on}) async {
    final was = (viewed, changed);
    viewed = {...?viewed}..removeWhere((p) => p == path);
    if (on) viewed!.add(path);
    changed = {...changed}..remove(path);
    notifyListeners();
    try {
      await daemon.client.setGitHubViewed(
        SetGitHubViewedRequest(
          host: pull.item.ref.host,
          pull: pull.item.id,
          path: path,
          viewed: on,
        ),
      );
    } on Object {
      viewed = was.$1;
      changed = was.$2;
      notifyListeners();
      rethrow;
    }
  }
}

/// "1 / 4 files viewed" over the Files tab's list, with a bar of as much,
/// as GitHub's Files changed says it.
class ViewedCount extends StatelessWidget {
  const new({required this.viewed, required this.total, super.key});

  final int viewed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 5,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$viewed / $total',
                  style: theme.ui(t.text, size: 12, weight: FontWeight.w600),
                ),
                const TextSpan(text: ' files viewed'),
              ],
            ),
            style: theme.ui(t.textSecondary, size: 12),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(NushiTheme.tag),
            child: SizedBox(
              height: 4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (viewed > 0)
                    Expanded(
                      flex: viewed,
                      child: ColoredBox(color: t.done),
                    ),
                  if (total > viewed)
                    Expanded(
                      flex: total - viewed,
                      child: ColoredBox(color: t.line),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The picked file's head over its diff, as GitHub's file header: a
/// chevron that folds it, its path, its lines added and removed, "Changed
/// since last view" when so, and the Viewed checkbox at its end. A file
/// ticked viewed folds; its chevron opens it again, still viewed. The box
/// keeps its place and size either way.
class FileHead extends StatelessWidget {
  const new({
    required this.file,
    required this.viewed,
    required this.changed,
    required this.open,
    required this.onFold,
    required this.onViewed,
    super.key,
  });

  final FileChange file;
  final bool viewed;
  final bool changed;
  final bool open;
  final VoidCallback onFold;

  /// Null where the daemon can't mark it (before [viewedApi]).
  final ValueChanged<bool>? onViewed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final f = file;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
      child: Row(
        children: [
          IconTap.drawn(
            (size, color) => AnimatedRotation(
              turns: open ? 0 : -0.25,
              duration: Motion.quick,
              child: Icon(Icons.expand_more, size: size, color: color),
            ),
            tooltip: open ? 'Fold' : 'Show the diff',
            onTap: onFold,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    f.oldPath.isEmpty ? f.path : '${f.oldPath} → ${f.path}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.code(t.text, size: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text('+${f.added}', style: theme.ui(t.done, size: 11.5)),
                Text(' −${f.removed}', style: theme.ui(t.crashed, size: 11.5)),
                if (changed) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: t.needsSoft,
                      borderRadius: BorderRadius.circular(NushiTheme.pill),
                    ),
                    child: Text(
                      'Changed since last view',
                      style: theme.ui(t.needs, size: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onViewed case final set?)
            ViewedBox(viewed: viewed, onChanged: set),
        ],
      ),
    );
  }
}

/// GitHub's Viewed checkbox: a box and its word, filled in the accent's
/// soft fill once ticked, the same size either way.
class ViewedBox extends StatelessWidget {
  const new({required this.viewed, required this.onChanged, super.key});

  final bool viewed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Semantics(
      checked: viewed,
      child: Tap(
        onTap: () => onChanged(!viewed),
        fill: viewed ? t.accentSoft : t.raised,
        tooltip: viewed ? 'Viewed: untick to show it again' : 'Mark viewed',
        padding: const EdgeInsets.fromLTRB(4, 2, 9, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 22,
              child: Transform.scale(
                scale: 0.72,
                child: ExcludeFocus(
                  child: Checkbox(
                    value: viewed,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => onChanged(v ?? false),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'Viewed',
              style: theme.ui(
                viewed ? t.text : t.textSecondary,
                size: 12,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// In a folded file's diff's place: one line saying so, on code's sunk
/// surface as the diff would be.
class FoldedDiff extends StatelessWidget {
  const new({required this.viewed, super.key});

  final bool viewed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.codeBlock,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Text(
        viewed
            ? 'Viewed. Its diff is folded: the chevron shows it.'
            : 'Folded: the chevron shows it.',
        style: theme.ui(t.textMuted, size: 12),
      ),
    );
  }
}
