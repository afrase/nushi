import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/worktree.dart';

void main() {
  test('deleting asks for force only where work would be lost', () {
    WorktreePlan plan({int changed = 0, int commits = 0}) => WorktreePlan(
      worktree: Worktree(path: '/w'),
      state: WorktreeState(changed: changed, commits: commits),
    );
    expect(WorktreeChoices.defaults(plan()), (true, true));
    expect(WorktreeChoices.defaults(plan(commits: 1)), (true, false));
    expect(WorktreeChoices.defaults(plan(changed: 1)), (false, false));
    // Another chat works in it: the daemon would refuse.
    final shared = plan()..others.add('Fix the build');
    expect(WorktreeChoices.defaults(shared), (false, false));

    final c = WorktreeChoices.choice(
      plan(changed: 2, commits: 1),
      remove: true,
      branch: true,
    );
    expect(
      [
        c.path,
        c.removeWorktree,
        c.forceWorktree,
        c.deleteBranch,
        c.forceBranch,
      ],
      ['/w', true, true, true, true],
    );
    // The branch goes only with the worktree, and clean work needs no force.
    final kept = WorktreeChoices.choice(plan(), remove: false, branch: true);
    expect(
      [kept.removeWorktree, kept.deleteBranch, kept.forceWorktree],
      [false, false, false],
    );
  });
}
