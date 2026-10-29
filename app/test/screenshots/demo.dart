import 'package:fixnum/fixnum.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// Made-up demo data for the README's screenshots: Lumen, an imaginary
/// open-source static site generator, its people and its tracker. Nothing
/// here is a real project, person or token.

/// The time every age counts from.
final demoNow = DateTime.now();

Int64 ago(Duration d) => Int64(demoNow.subtract(d).millisecondsSinceEpoch);

const demoRepo = 'lumen-dev/lumen';
const demoHome = '/Users/me/src/lumen';
const demoTree = '$demoHome/.worktrees/quiet-heron';
const demoBranch = 'feed-cursor';

/// A chat as the daemon lists it, [age] minutes old.
Chat demoChat(
  String id,
  String agent,
  String title, {
  String folder = demoHome,
  int age = 0,
  ChatStatus? status,
  int pin = 0,
  bool done = false,
  Worktree? worktree,
  GitHubLink? pull,
  String jiraSite = '',
  String jiraKey = '',
}) => Chat(
  id: id,
  agent: agent,
  title: title,
  folder: folder,
  createdUnixMs: ago(Duration(minutes: age)),
  status: status ?? ChatStatus(canFork: true, canRewind: true),
  pin: pin,
  done: done,
  worktree: worktree,
  pull: pull,
  jiraSite: jiraSite,
  jiraKey: jiraKey,
);

final demoWorktree = Worktree(
  repo: demoHome,
  path: demoTree,
  branch: demoBranch,
  base: 'main',
);

final demoLink = GitHubLink(
  host: 'github.com',
  repo: demoRepo,
  number: 218,
  id: 'PR_218',
  pull: true,
);

/// The hero's chat: mid-turn, in a worktree, with a pull request.
final Chat heroChat = demoChat(
  'feed',
  'claude',
  'Paginate the feed',
  folder: demoTree,
  worktree: demoWorktree,
  pull: demoLink,
  jiraSite: 'lumen.example.net',
  jiraKey: 'LUM-142',
  status: ChatStatus(
    busy: true,
    started: ago(const Duration(minutes: 3, seconds: 12)),
    canFork: true,
    canRewind: true,
    canAskContext: true,
    background: 1,
  ),
);

/// Every chat in the sidebar: two projects, a pin, each state once.
List<Chat> demoChats() => [
  heroChat,
  demoChat(
    'rss',
    'codex',
    'Atom feed drops the summary',
    age: 40,
    status: ChatStatus(waiting: true, canFork: true),
  ),
  demoChat('img', 'claude', 'Resize images at build time', age: 95)
    ..done = true,
  demoChat(
    'theme',
    'pig',
    'Dark theme for the default layout',
    age: 300,
    status: ChatStatus(asleep: true),
  ),
  demoChat(
    'docs',
    'ante',
    'Rewrite the quickstart',
    folder: '/Users/me/src/lumen-docs',
    age: 30,
  ),
  demoChat(
    'i18n',
    'omp',
    'Translate the CLI messages',
    folder: '/Users/me/src/lumen-docs',
    age: 600,
    status: ChatStatus(asleep: true),
  ),
  demoChat('release', 'claude', 'Release notes for 0.9', age: 20, pin: 1),
];

Item _tool(
  String id,
  String kind,
  String title, {
  String status = 'completed',
  String parent = '',
  List<String> paths = const [],
  List<FileChange> diffs = const [],
  String tool = '',
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: kind,
  title: title,
  status: status,
  parent: parent,
  paths: paths,
  diffs: diffs,
  tool: tool,
);

const _postsOld = '''
// ListPosts returns every published post, newest first.
func (s *Store) ListPosts(ctx context.Context) ([]Post, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, slug, title, published FROM posts
		 WHERE draft = 0 ORDER BY published DESC`)
	if err != nil {
		return nil, err
	}
	return scanPosts(rows)
}
''';

const _postsNew = '''
// ListPosts returns up to limit published posts, newest first, starting
// after the cursor (empty for the first page), and the next page's cursor.
func (s *Store) ListPosts(ctx context.Context, after Cursor, limit int) ([]Post, Cursor, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, slug, title, published FROM posts
		 WHERE draft = 0 AND (published, id) < (?, ?)
		 ORDER BY published DESC, id DESC LIMIT ?`,
		after.Published, after.ID, limit+1)
	if err != nil {
		return nil, Cursor{}, err
	}
	posts, err := scanPosts(rows)
	if err != nil || len(posts) <= limit {
		return posts, Cursor{}, err
	}
	last := posts[limit-1]
	return posts[:limit], Cursor{Published: last.Published, ID: last.ID}, nil
}
''';

/// The hero chat's transcript: a turn under way, an Explore subagent
/// running beside it.
final heroItems = <Item>[
  Item(
    id: 'u1',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text:
        'The home feed loads every post at once and takes 4 s on a big '
        'site. Paginate it with a cursor, 20 a page, and keep the reader’s '
        'place across reloads. Tests too.',
    rewindable: true,
  ),
  Item(
    id: 't1',
    kind: ItemKind.ITEM_KIND_THOUGHT,
    text:
        'An offset would skip posts when a new one is published between '
        'pages, so a keyset cursor on (published, id).',
    status: 'completed',
  ),
  _tool('r1', 'read', 'Read', paths: ['internal/feed/handler.go']),
  _tool('g1', 'search', 'grep "ListPosts("'),
  _tool('r2', 'read', 'Read', paths: ['internal/store/posts.go']),
  Item(
    id: 'm1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text:
        '`ListPosts` reads the whole table in one query. I’ll give it a '
        'keyset cursor on `(published, id)`, so a post published while '
        'someone reads doesn’t shift the pages, and have an Explore agent '
        'find every template that renders the feed.',
  ),
  Item(
    id: 'p1',
    kind: ItemKind.ITEM_KIND_PLAN,
    plan: [
      PlanEntry(content: 'A cursor in store.ListPosts', status: 'completed'),
      PlanEntry(content: 'Page the feed handler', status: 'completed'),
      PlanEntry(
        content: 'Older posts link in the templates',
        status: 'in_progress',
      ),
      PlanEntry(
        content: 'Tests for the cursor and the handler',
        status: 'pending',
      ),
    ],
  ),
  Item(
    id: 'x',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    tool: 'Task',
    agent: 'Explore',
    title: 'Find every template that renders the feed',
    status: 'in_progress',
    model: 'haiku',
    agentId: 'a51c0e9f2b7d4e18',
    subagent: Subagent(
      state: 'running',
      started: ago(const Duration(minutes: 1, seconds: 48)),
      session: 'a51c0e9f2b7d4e18',
    ),
  ),
  _tool('x1', 'search', 'grep "range .Posts" themes/', parent: 'x'),
  _tool('x2', 'read', 'Read', parent: 'x', paths: ['themes/default/feed.html']),
  _tool('x3', 'read', 'Read', parent: 'x', paths: ['themes/default/tag.html']),
  Item(
    id: 'xm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    parent: 'x',
    text:
        'Two themes render the feed: `default` (feed.html, tag.html) and '
        '`minimal` (index.html). Only `default` has a pager partial; '
        'checking the docs theme next.',
  ),
  _tool(
    'x4',
    'read',
    'Read',
    parent: 'x',
    paths: ['themes/minimal/index.html'],
  ),
  _tool(
    'x5',
    'search',
    r'grep "\.NextPage" themes/',
    parent: 'x',
    status: 'in_progress',
  ),
  _tool(
    'e2',
    'edit',
    'Edit',
    paths: ['internal/feed/handler.go'],
    diffs: [
      FileChange(
        path: 'internal/feed/handler.go',
        oldText: 'posts, err := h.store.ListPosts(ctx)\n',
        newText:
            'after, err := ParseCursor(q)\n'
            'if err != nil {\n\treturn errBadCursor\n}\n'
            'posts, next, err := h.page(ctx, after)\n',
        added: 5,
        removed: 1,
      ),
    ],
  ),
  _tool(
    'e1',
    'edit',
    'Edit',
    paths: ['internal/store/posts.go'],
    diffs: [
      FileChange(
        path: 'internal/store/posts.go',
        oldText: _postsOld,
        newText: _postsNew,
        added: 17,
        removed: 6,
      ),
    ],
  ),
  _tool(
    'w1',
    'edit',
    'Write',
    paths: ['docs/design/feed-cursor.md'],
    diffs: [FileChange(path: 'docs/design/feed-cursor.md', newText: designDoc)],
  ),
  Item(
    id: 'm2',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text:
        'The store and the handler page now. While Explore goes through the '
        'themes, I’m running the store’s tests.',
  ),
  _tool(
    'b1',
    'execute',
    'go test ./internal/store/... ./internal/feed/...',
    tool: 'Bash',
    status: 'in_progress',
  ),
];

/// The design note the agent wrote, for the preview.
const designDoc = '''
# A cursor for the home feed

_Draft · written by Claude for #218_

The feed loaded every post in one query: 4.1 s and 38 MB on a site with
12,000 posts. Pages of 20, found by a keyset cursor, keep it flat.

## Why a cursor, not an offset

- An offset skips or repeats posts when one is published between pages.
- `(published, id)` is unique and already indexed.
- The cursor is opaque in the URL: `?after=` and a base64 pair.

## Timings

| Site          | Posts  | Before | After |
|---------------|-------:|-------:|------:|
| docs.example  |    240 |  90 ms | 18 ms |
| blog.example  |  3,100 |  1.2 s | 21 ms |
| news.example  | 12,000 |  4.1 s | 23 ms |

## Rollout

1. Ship the cursor behind `feed.paginate` (on by default).
2. Themes without `.NextPage` get an "Older posts" link added.
3. Drop the old query in 0.10.

```go
type Cursor struct {
	Published time.Time
	ID        int64
}
```
''';

GitHubCheck _check(String name, String state, {bool required = true}) =>
    GitHubCheck(
      id: Int64(name.hashCode.abs()),
      name: name,
      workflow: 'CI',
      state: state,
      failed: state == 'failure',
      required: required,
      url: 'https://github.com/$demoRepo/actions/runs/1/job/1',
      startedMs: ago(const Duration(minutes: 2)),
    );

GitHubComment _said(
  String author,
  String body, {
  String review = '',
  Duration age = const Duration(minutes: 30),
}) => GitHubComment(
  id: 'C_${author}_${age.inSeconds}',
  author: author,
  association: 'MEMBER',
  body: body,
  url: 'https://github.com/$demoRepo/pull/218',
  createdMs: ago(age),
  review: review,
);

GitHubThread _thread(
  String id,
  String path,
  int line,
  List<GitHubComment> comments,
) => GitHubThread(
  id: id,
  path: path,
  side: 'right',
  line: line,
  canReply: true,
  canResolve: true,
  comments: comments,
);

/// Lumen's pull request #218, from the hero chat's branch: a check failing,
/// one running, changes requested with two threads open.
GitHubPull demoPull({bool running = true}) => GitHubPull(
  item: GitHubItem(
    ref: GitHubRef(host: 'github.com', repo: demoRepo, number: 218),
    id: 'PR_218',
    pull: true,
    title: 'Paginate the home feed with a keyset cursor',
    url: 'https://github.com/$demoRepo/pull/218',
    state: 'open',
    author: 'maya-chen',
    updatedMs: ago(const Duration(minutes: 4)),
    checks: 'failure',
    review: 'changes_requested',
    unresolved: 2,
    comments: 3,
  ),
  body:
      'The home feed loaded every post at once (4 s on a 12k-post site). '
      'This pages it 20 at a time with a keyset cursor on '
      '`(published, id)`, and adds an **Older posts** link to the default '
      'themes.\n\n'
      '- [x] Cursor in `store.ListPosts`\n'
      '- [x] Handler reads `?after=`\n'
      '- [ ] Themes: minimal and docs',
  association: 'MEMBER',
  base: 'main',
  head: demoBranch,
  headRepo: demoRepo,
  baseOid: 'a' * 40,
  headOid: 'b' * 40,
  mergeable: 'mergeable',
  mergeState: 'blocked',
  additions: 142,
  deletions: 37,
  changedFiles: 9,
  commits: 3,
  reviewers: [
    GitHubReviewer(login: 'jonas-weber', state: 'changes_requested'),
    GitHubReviewer(
      login: 'lumen-dev/maintainers',
      state: 'requested',
      team: true,
      codeOwner: true,
    ),
  ],
  conversation: [
    _said(
      'jonas-weber',
      'Nice, the keyset approach is the right call. Two things inline, '
          'and the minimal theme still renders every post.',
      review: 'changes_requested',
      age: const Duration(minutes: 12),
    ),
    _said(
      'priya-nair',
      'Tried it on the docs site: page two loads in 20 ms. 🎉',
      age: const Duration(minutes: 6),
    ),
  ],
  threads: [
    _thread('T1', 'internal/feed/cursor.go', 31, [
      _said(
        'jonas-weber',
        'A malformed `after` should be a 400, not a 500. Can we check the '
            'decode error before the query?',
        age: const Duration(minutes: 12),
      ),
    ]),
    _thread('T2', 'internal/store/posts.go', 58, [
      _said(
        'jonas-weber',
        'Could this use `LIMIT ? + 1` in SQL instead of passing `limit+1`? '
            'Reads a little clearer.',
        age: const Duration(minutes: 11),
      ),
    ]),
  ],
  checks: [
    GitHubCheck(
      id: Int64(41),
      name: 'test (linux)',
      workflow: 'CI',
      state: 'failure',
      failed: true,
      required: true,
      url: 'https://github.com/$demoRepo/actions/runs/1/job/41',
      annotations: [
        GitHubAnnotation(
          path: 'internal/feed/handler_test.go',
          line: 77,
          level: 'failure',
          message: 'TestFeedPages: page 2 has 19 posts, want 20',
        ),
      ],
    ),
    if (running) _check('test (macos)', 'pending'),
    for (final n in ['lint', 'build', 'test (windows)', 'docs'])
      _check(n, 'success', required: n != 'docs'),
    _check('deploy preview', 'skipped', required: false),
  ],
);

/// The files of #218, for the Pull request tab's Files.
List<FileChange> demoPullFiles() => [
  FileChange(
    path: 'internal/store/posts.go',
    status: 'modified',
    oldText: _postsOld,
    newText: _postsNew,
    added: 17,
    removed: 6,
  ),
];

const _cursorOld = '''
package feed

import (
	"errors"
	"strconv"
)

const pageSize = 20

var errBadPage = errors.New("feed: bad page")

// ParsePage reads ?page=; empty is the first page.
func ParsePage(s string) (int, error) {
	if s == "" {
		return 0, nil
	}
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		return 0, errBadPage
	}
	return n * pageSize, nil
}
''';

const _cursorNew = '''
package feed

import (
	"encoding/base64"
	"errors"
	"strconv"
	"strings"
	"time"
)

const pageSize = 20

var errBadCursor = errors.New("feed: bad cursor")

// Cursor is where a page ends: the last post's time and id.
type Cursor struct {
	Published time.Time
	ID        int64
}

// String encodes the cursor for a URL.
func (c Cursor) String() string {
	if c.ID == 0 {
		return ""
	}
	raw := c.Published.Format(time.RFC3339Nano) + "|" +
		strconv.FormatInt(c.ID, 10)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// ParseCursor reads ?after=; empty is the first page.
func ParseCursor(s string) (Cursor, error) {
	if s == "" {
		return Cursor{}, nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return Cursor{}, errBadCursor
	}
	at, id, ok := strings.Cut(string(raw), "|")
	if !ok {
		return Cursor{}, errBadCursor
	}
	t, err := time.Parse(time.RFC3339Nano, at)
	if err != nil {
		return Cursor{}, errBadCursor
	}
	n, err := strconv.ParseInt(id, 10, 64)
	return Cursor{Published: t, ID: n}, err
}
''';

/// The line of [file]'s new text that is [text] (1-based).
int lineOf(FileChange file, String text) =>
    file.newText.split('\n').indexOf(text) + 1;

/// The hero chat's branch, as the Changes view shows it.
List<FileChange> demoChanges() => [
  FileChange(
    path: 'internal/feed/cursor.go',
    status: 'modified',
    oldText: _cursorOld,
    newText: _cursorNew,
    added: 41,
    removed: 9,
  ),
  FileChange(
    path: 'internal/store/posts.go',
    status: 'modified',
    oldText: _postsOld,
    newText: _postsNew,
    added: 17,
    removed: 6,
  ),
  FileChange(
    path: 'internal/feed/handler.go',
    status: 'modified',
    oldText: 'posts, err := h.store.ListPosts(ctx)\n',
    newText:
        'after, err := ParseCursor(q)\nif err != nil {\n'
        '\treturn errBadCursor\n}\n'
        'posts, next, err := h.page(ctx, after)\n',
    added: 5,
    removed: 1,
  ),
  FileChange(
    path: 'internal/feed/handler_test.go',
    status: 'added',
    newText: 'package feed\n\nfunc TestFeedPages(t *testing.T) {}\n',
    added: 41,
  ),
  FileChange(
    path: 'themes/default/feed.html',
    status: 'modified',
    oldText: '{{ range .Posts }}{{ template "card" . }}{{ end }}\n',
    newText:
        '{{ range .Posts }}{{ template "card" . }}{{ end }}\n'
        '{{ with .Next }}<a rel="next" href="?after={{ . }}">Older posts</a> '
        '{{ end }}\n',
    added: 1,
  ),
  FileChange(
    path: 'docs/design/feed-cursor.md',
    status: 'added',
    newText: designDoc,
    added: 34,
  ),
];

/// The Jira site: a made-up Cloud site and its sprint.
final demoSite = JiraSite(
  id: 'lumen.example.net',
  url: 'https://lumen.example.net',
  name: 'Maya Chen',
  board: Int64(4),
  boardName: 'Lumen',
  searches: [JiraSearch(name: 'Bugs', jql: 'type = Bug')],
);

JiraIssue demoIssue(
  String key,
  String summary,
  String status,
  String category, {
  String assignee = 'Maya Chen',
  String priority = 'Medium',
  String type = 'Task',
}) => JiraIssue(
  key: key,
  summary: summary,
  type: type,
  status: status,
  statusCategory: category,
  assignee: assignee,
  priority: priority,
  url: 'https://lumen.example.net/browse/$key',
);

final List<JiraIssue> demoSprint = [
  demoIssue(
    'LUM-142',
    'Paginate the home feed',
    'In Progress',
    'indeterminate',
  ),
  demoIssue(
    'LUM-151',
    'Atom feed drops the post summary',
    'In Review',
    'indeterminate',
    priority: 'High',
    type: 'Bug',
  ),
  demoIssue(
    'LUM-139',
    'Resize images at build time',
    'In Progress',
    'indeterminate',
    assignee: 'Jonas Weber',
  ),
  demoIssue(
    'LUM-147',
    'Dark theme for the default layout',
    'To Do',
    'new',
    assignee: 'Priya Nair',
    priority: 'Low',
  ),
  demoIssue(
    'LUM-153',
    'Sitemap misses tag pages',
    'To Do',
    'new',
    assignee: '',
    type: 'Bug',
  ),
  demoIssue(
    'LUM-144',
    'Translate the CLI messages',
    'To Do',
    'new',
    assignee: 'Sam Okafor',
  ),
  demoIssue(
    'LUM-131',
    'Release notes for 0.9',
    'Done',
    'done',
    assignee: 'Sam Okafor',
  ),
  demoIssue(
    'LUM-128',
    'Watch mode rebuilds twice',
    'Done',
    'done',
    type: 'Bug',
  ),
];

/// A terminal beside the hero chat: the tests, run by hand.
const demoTerminal =
    '\x1b[1;34m~/src/lumen/.worktrees/quiet-heron\x1b[0m '
    '\x1b[35mfeed-cursor\x1b[0m\r\n'
    r'$ go test ./internal/feed/... -run TestFeed -v'
    '\r\n'
    '=== RUN   TestFeedFirstPage\r\n'
    '--- \x1b[32mPASS\x1b[0m: TestFeedFirstPage (0.01s)\r\n'
    '=== RUN   TestFeedPages\r\n'
    '    handler_test.go:77: page 2 has 19 posts, want 20\r\n'
    '--- \x1b[31mFAIL\x1b[0m: TestFeedPages (0.02s)\r\n'
    '\x1b[31mFAIL\x1b[0m\r\n'
    'FAIL\tgithub.com/lumen-dev/lumen/internal/feed\t0.214s\r\n'
    '\r\n'
    '\x1b[1;34m~/src/lumen/.worktrees/quiet-heron\x1b[0m '
    '\x1b[35mfeed-cursor\x1b[0m\r\n'
    r'$ ';

/// The Codex chat, waiting on a question: for the phone.
GetChatResponse demoQuestion(Chat c) => GetChatResponse(
  chat: c,
  status: c.status,
  items: [
    Item(
      id: 'u',
      kind: ItemKind.ITEM_KIND_USER_MESSAGE,
      text:
          'The Atom feed drops the summary when a post has no excerpt. '
          'Fix it.',
    ),
    _tool('r', 'read', 'Read', paths: ['internal/feed/atom.go']),
    _tool('g', 'search', 'grep "Summary" internal/'),
    Item(
      id: 'm',
      kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
      text:
          'Found it: `atom.go` writes `<summary>` only from the excerpt. '
          'One question before I change it:',
    ),
    Item(
      id: 'q',
      kind: ItemKind.ITEM_KIND_QUESTION,
      status: 'pending',
      fields: [
        Field(
          id: 'question_0',
          title: 'Summary',
          description: 'With no excerpt, what should the summary be?',
          type: FieldType.FIELD_TYPE_CHOICE,
          options: [
            Option(id: 'f', name: 'The first paragraph'),
            Option(id: 'c', name: 'The first 280 characters'),
            Option(id: 'n', name: 'Leave it out'),
          ],
        ),
      ],
    ),
  ],
);
