import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

/// The parts of the pull request's page a status light jumps to.
enum PullSection { todo, activity, checks, files }

/// How a status light, or the sentence over them, reads: bad (red), warn
/// (amber), ok (green), or quiet (grey).
enum Mood { bad, warn, ok, quiet }

/// [m]'s color.
Color moodColor(Tokens t, Mood m) => switch (m) {
  Mood.bad => t.crashed,
  Mood.warn => t.needs,
  Mood.ok => t.done,
  Mood.quiet => t.textMuted,
};

/// A pull request's checks counted: failing, running, passed, and the
/// rest (skipped, neutral, cancelled).
({int failing, int running, int passed, int other}) countChecks(GitHubPull p) {
  final failing = p.checks.where((c) => c.failed).length;
  final running = p.checks.where((c) => c.state == 'pending').length;
  final passed = p.checks.where((c) => c.state == 'success').length;
  return (
    failing: failing,
    running: running,
    passed: passed,
    other: p.checks.length - failing - running - passed,
  );
}

/// The reviewers still asked, not reviewed yet.
List<GitHubReviewer> waitingOn(GitHubPull p) => [
  for (final r in p.reviewers)
    if (r.state == 'requested') r,
];

/// Names joined as a sentence says them: "@a", "@a and @b", "@a, @b and
/// @c".
String names(Iterable<String> all) {
  final l = all.toList();
  if (l.length < 2) return l.join();
  return '${l.take(l.length - 1).join(', ')} and ${l.last}';
}

/// One status light: its name, value, a line under it, its mood and icon,
/// and the section it jumps to.
typedef Light = ({
  String name,
  String value,
  String sub,
  Mood mood,
  IconData icon,
  PullSection to,
});

Light _light(
  String name,
  PullSection to,
  Mood mood,
  IconData icon,
  String value, [
  String sub = '',
]) => (name: name, value: value, sub: sub, mood: mood, icon: icon, to: to);

const IconData _bad = Icons.cancel_outlined;
const IconData _ok = Icons.check_circle_outline;
const IconData _wait = Icons.schedule;

/// The four status lights: Checks, Review, Threads and Branch; [threadsTo]
/// is where Threads and Review jump to.
List<Light> pullLights(
  GitHubPull p, {
  PullSection threadsTo = PullSection.activity,
}) {
  final n = countChecks(p);
  final rest = [
    if (n.passed > 0) '${n.passed} passed',
    if (n.running > 0 && n.failing > 0) '${n.running} running',
    if (n.other > 0) '${n.other} skipped',
  ].join(' · ');
  Light checks(Mood m, IconData i, String v, [String s = '']) =>
      _light('Checks', PullSection.checks, m, i, v, s);
  final lights = <Light>[
    if (p.checks.isEmpty)
      checks(Mood.quiet, Icons.remove_circle_outline, 'None', 'None yet')
    else if (n.failing > 0)
      checks(Mood.bad, _bad, '${n.failing} failing', rest)
    else if (n.running > 0)
      checks(Mood.warn, _wait, '${n.running} running', rest)
    else
      checks(
        Mood.ok,
        _ok,
        n.passed == 0 ? 'Skipped' : 'All ${n.passed} passed',
        n.other > 0 ? '${n.other} skipped' : '',
      ),
  ];
  final waiting = waitingOn(p);
  final asked = waiting.isEmpty
      ? ''
      : waiting.any((r) => r.codeOwner)
      ? '${waiting.length == 1 ? 'code owner' : 'code owners'} waiting'
      : '${names(waiting.map((r) => r.team ? '@${r.login}' : r.login))} '
            'waiting';
  List<String> by(String state) => [
    for (final r in p.reviewers)
      if (r.state == state) r.login,
  ];
  String sub(List<String> who) => [
    if (who.isNotEmpty) who.join(', '),
    if (asked.isNotEmpty) asked,
  ].join(' · ');
  Light review(Mood m, IconData i, String v, String s) =>
      _light('Review', threadsTo, m, i, v, s);
  final approved = by('approved');
  lights.add(switch (p.item.review) {
    'changes_requested' => review(
      Mood.bad,
      _bad,
      'Changes requested',
      sub(by('changes_requested')),
    ),
    'review_required' => review(
      Mood.warn,
      _wait,
      'Review required',
      sub(approved),
    ),
    _ when approved.isNotEmpty || p.item.review == 'approved' => review(
      waiting.isEmpty ? Mood.ok : Mood.warn,
      _ok,
      'Approved',
      sub(approved),
    ),
    _ => review(
      Mood.quiet,
      Icons.rate_review_outlined,
      waiting.isEmpty ? 'None yet' : 'Asked',
      waiting.isEmpty ? 'No reviewers asked' : asked,
    ),
  });
  final open = p.threads.where((x) => !x.resolved).length;
  final resolved = p.threads.length - open;
  lights.add(
    _light(
      'Threads',
      threadsTo,
      open > 0 ? Mood.warn : Mood.ok,
      Icons.forum_outlined,
      open > 0
          ? '$open unresolved'
          : p.threads.isEmpty
          ? 'None'
          : 'All resolved',
      open > 0 && resolved > 0
          ? '$resolved resolved'
          : p.threads.isEmpty
          ? 'No review threads'
          : '${p.threads.length} in all',
    ),
  );
  final base = p.base;
  Light branch(Mood m, IconData i, String v, String s) =>
      _light('Branch', PullSection.files, m, i, v, s);
  lights.add(switch (p.item.state) {
    'merged' => branch(Mood.ok, Icons.merge_type, 'Merged', 'Into $base'),
    'closed' => branch(Mood.quiet, closedIcon, 'Closed', 'Not merged'),
    _ when hasConflicts(p) => branch(Mood.bad, _bad, 'Conflicts', 'With $base'),
    _ when p.mergeState == 'behind' => branch(
      Mood.warn,
      Icons.history,
      'Behind $base',
      'Update the branch',
    ),
    _ when p.mergeable == 'mergeable' => branch(
      Mood.ok,
      _ok,
      'No conflicts',
      'Merges into $base',
    ),
    _ => branch(Mood.quiet, _wait, 'Checking…', 'Whether it merges'),
  });
  return lights;
}

const IconData closedIcon = Icons.do_not_disturb_on_outlined;
const IconData _lock = Icons.lock_outline;

/// The sentence over the lights: whose move it is. [todo] is how many
/// things block the merge (the To do list's items).
({String lead, String rest, Mood mood, IconData icon}) moveWords(
  GitHubPull p,
  int todo,
) {
  ({String lead, String rest, Mood mood, IconData icon}) say(
    String lead,
    Mood mood,
    IconData icon, [
    String rest = '',
  ]) => (lead: lead, rest: rest, mood: mood, icon: icon);
  final it = p.item;
  final waiting = waitingOn(p);
  final asked = names(waiting.map((r) => '@${r.login}'));
  final has = waiting.length == 1 ? 'has' : 'have';
  final things = todo == 1 ? '1 thing blocks' : '$todo things block';
  final n = countChecks(p);
  if (it.state == 'merged') {
    return say('Merged.', Mood.ok, Icons.merge_type, 'Into ${p.base}.');
  }
  if (it.state == 'closed') {
    return say('Closed.', Mood.quiet, closedIcon, 'Without merging.');
  }
  if (it.draft) {
    return say(
      'Draft.',
      Mood.quiet,
      Icons.edit_outlined,
      todo > 0
          ? '$things the merge; mark it ready for review when it is.'
          : 'Mark it ready for review when it is.',
    );
  }
  if (todo > 0) {
    return say(
      'Your move.',
      Mood.warn,
      _lock,
      '$things the merge.'
          '${waiting.isEmpty ? '' : ' After them, $asked $has to approve.'}',
    );
  }
  if (n.running > 0) {
    return say(
      'Waiting on checks.',
      Mood.quiet,
      _wait,
      '${n.running} running.'
          '${waiting.isEmpty ? '' : ' Then $asked $has to approve.'}',
    );
  }
  if (waiting.isNotEmpty) {
    return say(
      'Waiting on $asked.',
      Mood.quiet,
      _wait,
      waiting.any((r) => r.codeOwner)
          ? 'Approval required as code owner.'
          : 'Review requested.',
    );
  }
  if (it.review == 'changes_requested') {
    return say('Your move.', Mood.warn, _lock, 'Changes requested.');
  }
  return switch (p.mergeState) {
    'clean' || 'has_hooks' => say('Ready to merge.', Mood.ok, _ok),
    // GitHub's "unstable": it can merge, with checks not passing that
    // its base doesn't require.
    'unstable' => say('Ready to merge.', Mood.ok, _ok, '$unstableWords.'),
    'behind' => say(
      'Your move.',
      Mood.warn,
      _lock,
      'The branch is behind ${p.base}.',
    ),
    'blocked' => say(
      'Blocked.',
      Mood.warn,
      _lock,
      "A rule of ${p.base}'s isn't met yet.",
    ),
    'dirty' => say(
      'Your move.',
      Mood.bad,
      _lock,
      'It conflicts with ${p.base}.',
    ),
    _ => say('Checking whether it can merge…', Mood.quiet, _wait),
  };
}

/// What an "unstable" merge state says beside Ready to merge.
const unstableWords = 'Checks not passing (not required)';

/// Whether the pull request conflicts with its base: GitHub says so in
/// either of two fields, and may say it in one before the other.
bool hasConflicts(GitHubPull p) =>
    p.mergeable == 'conflicting' || p.mergeState == 'dirty';
