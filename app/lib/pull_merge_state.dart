import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/settings.dart';

/// What the Merge control offers: words only, a direct merge, enabling
/// auto-merge, adding to a merge queue (now, or once it can), or the way out
/// of auto-merge or the queue. Nothing the viewer has no permission for, and
/// no admin bypass (ADR 0069).
enum MergeStep { words, merge, auto, addToQueue, whenReady, autoOn, inQueue }

/// The Merge control's state: what it offers, the merge status card's
/// heading and the one sentence under it (why: what blocks it, or what
/// GitHub lets past), its mood and icon, and whether it can merge (ready:
/// nothing blocks it). A row's Merge… says why too, when it can't go on.
typedef MergeView = ({
  MergeStep step,
  String heading,
  String why,
  Mood mood,
  IconData icon,
  bool ready,
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

/// [b], a block (GitHubMerge.blocks), in a few words: the one table the
/// merge status card's line and a row's Merge… say a block from. [base] is
/// the base branch; [required] the required checks [b] counts (failing or
/// running), 0 when not known (a row's item doesn't say).
String blockWords(String b, {required String base, int required = 0}) {
  final name = plainName(base);
  String checks(String doing) => required == 0
      ? 'checks $doing'
      : '$required required check${required == 1 ? '' : 's'} $doing';
  return switch (b) {
    'draft' => "it's a draft",
    'conflicts' => 'conflicts with $name',
    'checks_failing' => checks('failing'),
    'checks_running' => checks('running'),
    'changes_requested' => 'changes requested',
    'review_required' => 'an approving review required',
    'threads' => 'unresolved conversations',
    'behind' => 'the branch is behind $name',
    'rules' => "a rule of $name's isn't met",
    _ => 'GitHub is still working it out',
  };
}

/// Phrases as one sentence: the first capitalised, a full stop at the end.
String blockSentence(List<String> parts) {
  final s = parts.join(', ');
  return s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}.';
}

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

/// What the Merge control shows of [p]; null when it has none: merged or
/// closed.
MergeView? mergeView(GitHubPull p) {
  if (p.item.state != 'open') return null;
  final m = p.merge;
  MergeView say(
    MergeStep step,
    String heading,
    String why,
    Mood mood,
    IconData icon,
  ) => (
    step: step,
    heading: heading,
    why: why,
    mood: mood,
    icon: icon,
    ready: false,
  );
  if (m.hasEntry()) {
    final e = m.entry;
    return say(
      MergeStep.inQueue,
      'In the merge queue',
      'Position ${e.position}, ${_queueState(e)}.${_eta(e.etaSeconds)}',
      e.state == 'unmergeable' ? Mood.bad : Mood.quiet,
      Icons.playlist_add_check,
    );
  }
  if (m.hasAuto()) {
    return say(
      MergeStep.autoOn,
      'Auto-merge is on',
      'With ${methodWords(m.auto.method)}, turned on by ${m.auto.by}.',
      Mood.ok,
      Icons.bolt,
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
    return (
      step: step,
      heading: 'Ready to merge',
      why: note.isEmpty ? 'All requirements are met.' : note,
      mood: Mood.ok,
      icon: Icons.check,
      ready: true,
    );
  }
  if (blocks.length == 1 && blocks.first == 'unknown') {
    return say(
      MergeStep.words,
      'Checking whether it can merge',
      blockSentence([blockWords('unknown', base: p.base)]),
      Mood.quiet,
      Icons.schedule,
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
  int required(bool Function(GitHubCheck) test) =>
      p.checks.where((c) => c.required && test(c)).length;
  return say(
    step,
    'Merging is blocked',
    blockSentence([
      for (final b in blocks)
        blockWords(
          b,
          base: p.base,
          required: switch (b) {
            'checks_failing' => required((c) => c.failed),
            'checks_running' => required((c) => c.state == 'pending'),
            _ => 0,
          },
        ),
      if (!m.canMerge) 'merging here takes write access',
    ]),
    blocks.contains('conflicts') || blocks.contains('checks_failing')
        ? Mood.bad
        : Mood.warn,
    Icons.block,
  );
}
