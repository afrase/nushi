import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/issue_chat.dart';

// A chat's branch on an issue: its key or number, then its title's ASCII
// letters and digits, lowercase, words joined by "-", 40 characters of
// title at most, cut between words. The cases are the daemon's own
// (model.Slug's and jira.Branch's tests), so the names stay as they were.
void main() {
  test('a branch named from an issue', () {
    for (final (prefix, title, want) in [
      (
        'SCRUM-5',
        "ADF sample: what Jira's editor makes",
        'SCRUM-5-adf-sample-what-jira-s-editor-makes',
      ),
      ('A-1', '  Ünïcode — and *marks*!  ', 'A-1-n-code-and-marks'),
      ('A-1', '???', 'A-1'),
      ('A-1', 'long ' * 30, 'A-1-long-long-long-long-long-long-long-long'),
      ('7', 'Add a Mul function', '7-add-a-mul-function'),
      ('7', '', '7'),
      ('7', 'Café: naïve résumé!!', '7-caf-na-ve-r-sum'),
      ('7', 'x${' word' * 20}', '7-x-word-word-word-word-word-word-word'),
      ('7', 'y' * 50, '7-${'y' * 40}'),
    ]) {
      expect(issueBranch(prefix, title), want, reason: '$prefix $title');
    }
  });

  test("a Jira issue's chat: its site, key and summary, and its branch", () {
    final c = IssueChat.jira(
      'acme.atlassian.net',
      JiraIssue(key: 'ACME-12', summary: 'Log in with a passkey'),
    );
    expect(
      (c.site, c.key, c.summary, c.branch, c.worktree),
      (
        'acme.atlassian.net',
        'ACME-12',
        'Log in with a passkey',
        'ACME-12-log-in-with-a-passkey',
        true,
      ),
    );
  });
}
