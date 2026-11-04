import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_inbox.dart';
import 'package:nushi/github_parts.dart';

import 'fake_daemon.dart';

void main() {
  // A remote may spell its repository in another case than GitHub does:
  // ListGitHubRepos, and a pull request found from a chat's branch, say
  // it the remote's way; the inbox's items GitHub's.
  testWidgets("a remote's case: Start work's clones and an item's chats "
      'still found', (tester) async {
    final fake =
        FakeDaemon([
            chat('c1', 'claude', 'On the branch')
              ..pull = GitHubLink(
                host: 'github.com',
                repo: 'Afrase/Nushi-GH-Test',
                number: 1,
                id: 'PR_1',
                pull: true,
              ),
          ])
          ..answer = (input) => switch (input) {
            ListGitHubReposRequest() => ListGitHubReposResponse(
              repos: [
                GitHubRepo(
                  host: 'github.com',
                  repo: 'Afrase/Nushi-GH-Test',
                  folders: ['/Users/me/nushi-gh-test'],
                ),
              ],
            ),
            _ => null,
          };
    final d = await fake.connect(tester);
    await loadRepos(d);
    final ref = GitHubRef(
      host: 'github.com',
      repo: 'afrase/nushi-gh-test',
      number: 1,
    );
    expect(clonesOf(ref), ['/Users/me/nushi-gh-test']);
    expect(chatsOnItem(d, ref).map((c) => c.id), ['c1']);
    final link = d.chats['c1']!.pull!;
    expect(
      sameRef(
        ref,
        GitHubRef(host: link.host, repo: link.repo, number: link.number),
      ),
      isTrue,
    );
    expect(sameRef(ref, GitHubRef(host: 'github.com', repo: ref.repo)), false);
    d.dispose();
  });
}
