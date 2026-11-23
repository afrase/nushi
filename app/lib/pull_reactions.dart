import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_mark.dart' show emojiFonts;
import 'package:nushi/widgets.dart';

/// GitHub's eight reactions, in its picker's order: the daemon's name
/// for each, its emoji and its words.
const reactionKinds = <(String, String, String)>[
  ('thumbs_up', '👍', '+1'),
  ('thumbs_down', '👎', '-1'),
  ('laugh', '😄', 'laugh'),
  ('hooray', '🎉', 'hooray'),
  ('confused', '😕', 'confused'),
  ('heart', '❤️', 'heart'),
  ('rocket', '🚀', 'rocket'),
  ('eyes', '👀', 'eyes'),
];

/// Where a reaction goes: the daemon, the pull request's host, and what
/// reads the pull request again once it's on GitHub.
typedef Reacting = ({
  Daemon daemon,
  String host,
  Future<void> Function() onChanged,
});

/// What a pill's tooltip says: "You and 2 others reacted with +1".
String reactedWords(GitHubReaction r) {
  final words =
      reactionKinds.where((k) => k.$1 == r.content).firstOrNull?.$3 ??
      r.content;
  final n = r.count;
  if (!r.mine) return '$n reacted with $words';
  if (n == 1) return 'You reacted with $words';
  return 'You and ${n - 1} ${n == 2 ? 'other' : 'others'} reacted with $words';
}

/// [shown] with the user's [kind] added or taken away, GitHub's order
/// kept.
List<GitHubReaction> toggled(List<GitHubReaction> shown, String kind) {
  final by = {for (final r in shown) r.content: r};
  final was = by[kind];
  if (was != null && was.mine) {
    by[kind] = GitHubReaction(content: kind, count: was.count - 1);
  } else {
    by[kind] = GitHubReaction(
      content: kind,
      count: (was?.count ?? 0) + 1,
      mine: true,
    );
  }
  return [
    for (final (k, _, _) in reactionKinds)
      if (by[k] case final r? when r.count > 0) r,
  ];
}

/// A comment's reactions under it, as GitHub shows them: the smiley that
/// opens the picker of GitHub's eight first (it never moves), then a pill
/// for each kind used, its emoji and count, the user's own filled in the
/// accent with the accent's ring. A click on a pill or in the picker adds
/// the user's or takes it away, at once, then on GitHub; put back with
/// GitHub's words if it refuses. No avatars: the tooltip says how many.
class Reactions extends StatefulWidget {
  const new(this.subject, this.reactions, {required this.reacting, super.key});

  /// The comment's, review's or pull request's node id.
  final String subject;
  final List<GitHubReaction> reactions;
  final Reacting reacting;

  @override
  State<Reactions> createState() => _ReactionsState();
}

class _ReactionsState extends State<Reactions> {
  late List<GitHubReaction> _shown = widget.reactions;
  int _writing = 0;

  @override
  void didUpdateWidget(Reactions old) {
    super.didUpdateWidget(old);
    // GitHub's word, once nothing of the user's is on its way.
    if (_writing == 0) _shown = widget.reactions;
  }

  Future<void> _toggle(String kind) async {
    final was = _shown;
    final mine = was.any((r) => r.content == kind && r.mine);
    setState(() => _shown = toggled(was, kind));
    _writing++;
    final r = widget.reacting;
    try {
      await r.daemon.client.reactGitHub(
        ReactGitHubRequest(
          host: r.host,
          subject: widget.subject,
          content: kind,
          remove: mine,
        ),
      );
      _writing--;
      unawaited(r.onChanged());
    } on Object catch (e) {
      _writing--;
      if (!mounted) return;
      setState(() => _shown = was);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reacting.daemon.daemonApi < reactionsApi) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Picker(_shown, onPick: (k) => unawaited(_toggle(k))),
        for (final r in _shown)
          _Pill(r, onTap: () => unawaited(_toggle(r.content))),
      ],
    );
  }
}

/// An emoji as text, in the system's emoji font.
Widget _emoji(NushiTheme theme, String kind, double size) => Text(
  reactionKinds.where((k) => k.$1 == kind).firstOrNull?.$2 ?? '?',
  style: theme.ui(theme.t.text, size: size).thenFonts(emojiFonts),
);

/// One kind's pill: its emoji and count; the user's own in the accent's
/// soft fill, its ring and its ink, so it can't be missed.
class _Pill extends StatelessWidget {
  const new(this.r, {required this.onTap});

  final GitHubReaction r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final round = BorderRadius.circular(NushiTheme.pill);
    return Semantics(
      selected: r.mine,
      child: Container(
        foregroundDecoration: r.mine
            ? BoxDecoration(
                border: Border.all(color: t.accentInk),
                borderRadius: round,
              )
            : null,
        child: Tap(
          onTap: onTap,
          radius: NushiTheme.pill,
          fill: r.mine ? t.accentSoft : t.lifted,
          tooltip: reactedWords(r),
          padding: const EdgeInsets.fromLTRB(8, 2, 9, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              _emoji(theme, r.content, 13),
              Text(
                '${r.count}',
                style: theme.ui(
                  r.mine ? t.accentInk : t.textSecondary,
                  size: 12,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The smiley that opens GitHub's eight, the user's own of them filled.
class _Picker extends StatelessWidget {
  const new(this.shown, {required this.onPick});

  final List<GitHubReaction> shown;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final mine = {
      for (final r in shown)
        if (r.mine) r.content,
    };
    return Menu(
      filter: false,
      entries: [
        MenuEntry.row(
          (close) => Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                for (final (kind, _, words) in reactionKinds)
                  Tap(
                    key: ValueKey('react $kind'),
                    selected: mine.contains(kind),
                    fill: mine.contains(kind) ? t.accentSoft : null,
                    tooltip: words,
                    padding: const EdgeInsets.all(5),
                    onTap: () {
                      close();
                      onPick(kind);
                    },
                    child: _emoji(theme, kind, 17),
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, open) => IconTap(
        Icons.add_reaction_outlined,
        size: 15,
        tooltip: 'Add reaction',
        onTap: open,
      ),
    );
  }
}
