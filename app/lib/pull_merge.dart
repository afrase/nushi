import 'package:flutter/material.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/pull_merge_dialog.dart';
import 'package:nushi/pull_merge_state.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The Merge control of an open pull request, in its Pull request tab and
/// the details widget: ready, or exactly why it can't merge, and what the
/// viewer may do about it ([mergeView]). Every way in goes through the
/// confirmation (`pull_merge_dialog.dart`); [onChanged] reads the pull
/// request again. While it shows what was kept from before ([stale]) it
/// says what it knew and offers nothing. [compact]: the details widget's,
/// no box, the buttons under the words.
class MergeControl extends StatelessWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.onChanged,
    super.key,
    this.compact = false,
    this.stale = false,
  });

  final Daemon daemon;
  final GitHubPull pull;
  final Future<void> Function() onChanged;
  final bool compact;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    if (mergeView(pull) == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: mergeMethods,
      builder: (context, _, _) => compact
          ? _built(context, narrow: true)
          : LayoutBuilder(
              builder: (context, box) =>
                  _built(context, narrow: box.maxWidth < 560),
            ),
    );
  }

  Widget _built(BuildContext context, {required bool narrow}) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final view = mergeView(pull)!;
    final size = compact ? 12.5 : 13.0;
    final words = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(view.icon, size: 15, color: moodColor(t, view.mood)),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text.rich(
            key: const ValueKey('merge-words'),
            TextSpan(
              children: [
                TextSpan(
                  text: view.lead,
                  style: theme.ui(
                    moodColor(t, view.mood),
                    size: size,
                    weight: FontWeight.w600,
                  ),
                ),
                if (view.rest.isNotEmpty) TextSpan(text: ' ${view.rest}'),
              ],
            ),
            style: theme.ui(t.textSecondary, size: size),
          ),
        ),
      ],
    );
    final actions = stale ? const <Widget>[] : _actions(context, view);
    final body = narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              words,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: actions),
              ],
            ],
          )
        : Row(
            children: [
              Expanded(child: words),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: actions,
                ),
              ],
            ],
          );
    if (compact) return body;
    return Container(
      key: const ValueKey('merge-control'),
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
      decoration: BoxDecoration(
        color: t.raised,
        border: Border.all(color: t.borderSubtle),
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: body,
    );
  }

  /// The methods to pick from, the one picked ticked; picked is remembered
  /// for this repository.
  List<MenuEntry> _methods(String picked) => [
    for (final m in pull.merge.methods)
      MenuEntry(
        methodLabel(m),
        checked: m == picked,
        detail: mergeMethodsOf(pull).contains(m) ? '' : "It can't rebase now",
        onPick: mergeMethodsOf(pull).contains(m)
            ? () => mergeMethods.value = {
                ...mergeMethods.value,
                mergeRepoKey(pull): m,
              }
            : null,
      ),
  ];

  Future<void> _confirm(BuildContext context, MergeAct act, String method) =>
      confirmMerge(
        context,
        daemon,
        pull,
        act,
        method: method,
        onDone: onChanged,
      );

  List<Widget> _actions(BuildContext context, MergeView view) {
    final ref = pull.item.ref;
    final picked = pickedMethod(pull);
    return switch (view.step) {
      MergeStep.words => const [],
      MergeStep.merge => [
        SplitButton(
          label: methodLabel(picked),
          tooltip: 'Asks you first',
          menuTooltip: 'How it merges',
          entries: _methods(picked),
          onPressed: () => _confirm(context, MergeAct.merge, picked),
        ),
      ],
      MergeStep.auto => [
        SplitButton(
          label: 'Enable auto-merge',
          kind: ButtonKind.secondary,
          tooltip:
              'GitHub merges it with ${methodWords(picked)} once it can. '
              'Asks you first',
          menuTooltip: 'How it merges',
          entries: _methods(picked),
          onPressed: () => _confirm(context, MergeAct.auto, picked),
        ),
      ],
      MergeStep.addToQueue => [
        Button(
          label: 'Add to queue',
          kind: ButtonKind.primary,
          tooltip: 'Asks you first',
          onPressed: () => _confirm(context, MergeAct.enqueue, ''),
        ),
      ],
      MergeStep.whenReady => [
        Button(
          label: 'Merge when ready',
          tooltip: 'Joins the merge queue once it can. Asks you first',
          onPressed: () => _confirm(context, MergeAct.whenReady, ''),
        ),
      ],
      MergeStep.autoOn => [
        if (pull.merge.canDisableAuto)
          RunButton(
            label: 'Disable auto-merge',
            running: 'Disabling…',
            run: () async {
              await daemon.client.disableGitHubAutoMerge(
                DisableGitHubAutoMergeRequest(ref: ref),
              );
              await onChanged();
            },
          ),
      ],
      MergeStep.inQueue => [
        if (pull.merge.canMerge)
          RunButton(
            label: 'Remove from queue',
            running: 'Removing…',
            run: () async {
              await daemon.client.dequeueGitHubPull(
                DequeueGitHubPullRequest(ref: ref),
              );
              await onChanged();
            },
          ),
      ],
    };
  }
}
