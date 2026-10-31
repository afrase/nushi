import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_people.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/settings.dart';

/// What the Merge control offers: words only, a direct merge, enabling
/// auto-merge, adding to a merge queue (now, or once it can), or the way out
/// of auto-merge or the queue. Nothing the viewer has no permission for, and
/// no admin bypass (ADR 0069).
enum MergeStep { words, merge, auto, addToQueue, whenReady, autoOn, inQueue }

/// The Merge control's state: what it offers and what it says first.
typedef MergeView = ({
  MergeStep step,
  String lead,
  String rest,
  Mood mood,
  IconData icon,
});

/// A method as a button says it.
String methodLabel(String method) => switch (method) {
  'merge' => 'Create a merge commit',
  'squash' => 'Squash and merge',
  'rebase' => 'Rebase and merge',
  _ => 'Merge',
};

/// A method in a sentence.
String methodWords(String method) => switch (method) {
  'merge' => 'a merge commit',
  'squash' => 'squash',
  'rebase' => 'rebase',
  _ => 'its method',
};

/// The key of [p]'s repository in [mergeMethods].
String mergeRepoKey(GitHubPull p) => '${p.item.ref.host} ${p.item.ref.repo}';

/// The methods [p] can use now: the repository's, without a rebase GitHub
/// says it can't do.
List<String> mergeMethodsOf(GitHubPull p) => [
  for (final m in p.merge.methods)
    if (m != 'rebase' || p.merge.canRebase) m,
];

/// The method the control starts on: the one picked last for this repository
/// if it's still allowed, else the one GitHub says the viewer used last,
/// else the repository's first; '' with none.
String pickedMethod(GitHubPull p) {
  final can = mergeMethodsOf(p);
  for (final m in [
    mergeMethods.value[mergeRepoKey(p)],
    p.merge.defaultMethod,
  ]) {
    if (can.contains(m)) return m!;
  }
  return can.firstOrNull ?? '';
}

/// [p]'s required checks that [test] says of, in words: "1 required check
/// is failing", "2 required checks are running".
String _required(GitHubPull p, bool Function(GitHubCheck) test, String doing) {
  final n = p.checks.where((c) => c.required && test(c)).length;
  return n == 1
      ? '1 required check is $doing.'
      : '$n required checks are $doing.';
}

/// What a block (GitHubMerge.blocks) says.
String _blockWords(GitHubPull p, String block) => switch (block) {
  'draft' => "It's a draft.",
  'conflicts' => 'It conflicts with ${plainName(p.base)}.',
  'checks_failing' => _required(p, (c) => c.failed, 'failing'),
  'checks_running' => _required(p, (c) => c.state == 'pending', 'running'),
  'changes_requested' => 'Changes were requested.',
  'review_required' => 'It needs an approving review.',
  'threads' => "Review threads aren't resolved.",
  'behind' => 'The branch is behind ${plainName(p.base)}.',
  'rules' => "A rule of ${plainName(p.base)}'s isn't met.",
  _ => 'GitHub is working out whether it can merge.',
};

/// A place in the queue's state, in words.
String _queueState(GitHubQueueEntry e) => switch (e.state) {
  'queued' => 'queued',
  'awaiting_checks' => 'waiting for checks',
  'mergeable' => 'about to merge',
  'unmergeable' => "it can't merge",
  'locked' => 'locked',
  _ => 'queued',
};

/// GitHub's estimate of the wait, in words; empty for none.
String _eta(int seconds) =>
    seconds <= 0 ? '' : ' About ${(seconds / 60).ceil()} min left.';

/// What the Merge control says of a pull request that can merge.
const readyWords = 'Ready to merge.';

/// What the Merge control shows of [p]; null when it has none: merged,
/// closed, or from a daemon before the control.
MergeView? mergeView(GitHubPull p) {
  if (p.item.state != 'open' || !p.hasMerge()) return null;
  final m = p.merge;
  MergeView say(
    MergeStep step,
    String lead,
    Mood mood,
    IconData icon, [
    String rest = '',
  ]) => (step: step, lead: lead, rest: rest, mood: mood, icon: icon);
  if (m.hasEntry()) {
    final e = m.entry;
    return say(
      MergeStep.inQueue,
      'In the merge queue.',
      e.state == 'unmergeable' ? Mood.bad : Mood.quiet,
      Icons.playlist_add_check,
      'Position ${e.position}, ${_queueState(e)}.${_eta(e.etaSeconds)}',
    );
  }
  if (m.hasAuto()) {
    return say(
      MergeStep.autoOn,
      'Auto-merge is on.',
      Mood.ok,
      Icons.bolt,
      'With ${methodWords(m.auto.method)}, turned on by ${m.auto.by}.',
    );
  }
  final blocks = m.blocks;
  if (blocks.isEmpty) {
    final base = plainName(p.base);
    final note = [
      if (p.mergeState == 'unstable') '$unstableWords.',
      if (p.item.review == 'changes_requested')
        "Changes were requested, but no rule of $base's enforces it.",
      if (!m.canMerge) 'Merging here takes write access.',
    ].join(' ');
    final step = !m.canMerge
        ? MergeStep.words
        : m.queue
        ? MergeStep.addToQueue
        : mergeMethodsOf(p).isEmpty
        ? MergeStep.words
        : MergeStep.merge;
    return say(step, readyWords, Mood.ok, Icons.check_circle_outline, note);
  }
  if (blocks.length == 1 && blocks.first == 'unknown') {
    return say(
      MergeStep.words,
      'Unknown, still checking.',
      Mood.quiet,
      Icons.schedule,
      _blockWords(p, 'unknown'),
    );
  }
  final canWait =
      m.canMerge &&
      m.canEnableAuto &&
      !blocks.contains('draft') &&
      !blocks.contains('conflicts');
  final step = !canWait
      ? MergeStep.words
      : m.queue
      ? MergeStep.whenReady
      : m.autoAllowed && mergeMethodsOf(p).isNotEmpty
      ? MergeStep.auto
      : MergeStep.words;
  final why = [
    for (final b in blocks) _blockWords(p, b),
    if (!m.canMerge) 'Merging here takes write access.',
  ].join(' ');
  return say(
    step,
    "Can't merge yet.",
    blocks.contains('conflicts') || blocks.contains('checks_failing')
        ? Mood.bad
        : Mood.warn,
    Icons.lock_outline,
    why,
  );
}
