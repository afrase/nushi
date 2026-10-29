import 'package:flutter/material.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

export 'package:nushi/pull_lights.dart';

/// A pull request's state as a pill: its icon and word on its color's
/// tint.
class StatePill extends StatelessWidget {
  const new(this.item, {super.key});

  final GitHubItem item;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final (icon, fg, bg) = switch (item.state) {
      'merged' => (Icons.merge_type, t.subagentAccent, t.subagentTint),
      'closed' => (closedIcon, t.crashed, t.crashedSoft),
      _ when item.draft => (Icons.edit_outlined, t.textSecondary, t.selected),
      _ => (Icons.merge, t.done, t.doneSoft),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 1, 8, 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 13, color: fg),
          Text(
            itemState(item),
            style: theme.ui(fg, size: 12, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The page's head: the state pill, `repo#n`, who opened it and when, the
/// title, head › base, commits and the diff's size; [actions] at the
/// right of the first line; then whose move it is ([todo] things block the
/// merge) and the four status lights, each jumping ([onJump]) to its
/// section.
class PullHeader extends StatelessWidget {
  const new({
    required this.pull,
    required this.now,
    required this.todo,
    required this.onJump,
    required this.actions,
    super.key,
    this.threadsTo = PullSection.activity,
  });

  final GitHubPull pull;
  final DateTime now;
  final int todo;
  final ValueChanged<PullSection> onJump;
  final List<Widget> actions;
  final PullSection threadsTo;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget branch(String name) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: box(t.borderSubtle, fill: t.raised, radius: 4),
      child: SelectableText(name, style: theme.code(t.text, size: 11.5)),
    );
    // The buttons beside the first line; under the branches when narrow
    // or many.
    return LayoutBuilder(
      builder: (context, room) =>
          _build(context, room.maxWidth < 700 || actions.length > 4, branch),
    );
  }

  Widget _build(
    BuildContext context,
    bool narrow,
    Widget Function(String) branch,
  ) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final p = pull;
    final it = p.item;
    final small = theme.ui(t.textSecondary, size: 12);
    final move = moveWords(p, todo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatePill(it),
                  Text(
                    '${it.ref.repo}#${it.ref.number}',
                    style: theme.code(t.textSecondary, size: 12),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '·  by '),
                        TextSpan(
                          text: it.author,
                          style: theme.ui(t.text, size: 12),
                        ),
                        if (p.outside)
                          TextSpan(
                            text: ' (outside the repository)',
                            style: theme.ui(t.needs, size: 12),
                          ),
                        TextSpan(text: ', ${agoAt(it.updatedMs.toInt(), now)}'),
                      ],
                    ),
                    style: small,
                  ),
                ],
              ),
            ),
            if (!narrow) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: actions,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          it.title,
          style: theme.ui(t.text, size: 18, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            branch(p.crossRepo ? '${p.headRepo}:${p.head}' : p.head),
            Icon(Icons.chevron_right, size: 14, color: t.textMuted),
            branch(p.base),
            if (p.commits > 0)
              Text(
                '·  ${p.commits} commit${p.commits == 1 ? '' : 's'}',
                style: small,
              ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '·  '),
                  TextSpan(
                    text: '+${p.additions}',
                    style: theme.ui(t.done, size: 12),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: '−${p.deletions}',
                    style: theme.ui(t.crashed, size: 12),
                  ),
                  TextSpan(
                    text:
                        ' in ${p.changedFiles} '
                        'file${p.changedFiles == 1 ? '' : 's'}',
                  ),
                ],
              ),
              style: small,
            ),
          ],
        ),
        if (narrow) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: actions),
        ],
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(move.icon, size: 15, color: moodColor(t, move.mood)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: move.lead,
                      style: theme.ui(
                        t.text,
                        size: 13.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    if (move.rest.isNotEmpty) TextSpan(text: ' ${move.rest}'),
                  ],
                ),
                style: theme.ui(t.textSecondary, size: 13.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) {
            final lights = [
              for (final l in pullLights(p, threadsTo: threadsTo))
                _LightBox(l, onTap: () => onJump(l.to)),
            ];
            // Four across; two by two where they'd be too narrow.
            if (box.maxWidth >= 560) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [for (final l in lights) Expanded(child: l)],
                ),
              );
            }
            return Column(
              spacing: 8,
              children: [
                for (var i = 0; i < 4; i += 2)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        Expanded(child: lights[i]),
                        Expanded(child: lights[i + 1]),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LightBox extends StatelessWidget {
  const new(this.light, {required this.onTap});

  final Light light;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final l = light;
    final color = moodColor(t, l.mood);
    return Tap(
      onTap: onTap,
      tooltip: switch (l.to) {
        PullSection.checks => 'Show the checks',
        PullSection.files => 'Show the files',
        PullSection.todo => 'Show the To do list',
        PullSection.activity => 'Show the activity',
      },
      child: framed(
        border: t.borderSubtle,
        fill: t.raised,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: color, width: 2)),
          ),
          padding: const EdgeInsets.fromLTRB(11, 7, 11, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Text(l.name, style: theme.ui(t.textMuted, size: 11.5)),
              Row(
                spacing: 5,
                children: [
                  Icon(l.icon, size: 14, color: color),
                  Flexible(
                    child: Text(
                      l.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(color, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Text(
                l.sub.isEmpty ? ' ' : l.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.textMuted, size: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
