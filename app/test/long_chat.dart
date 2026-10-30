import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// A long made-up chat, as the owner's real ones are: [turns] exchanges of
/// a user message, tool rows (reads, an edit with a diff, a command), a
/// subagent with its own steps every few turns, and a long reply in
/// Markdown with a list, a table and fenced code. About 11 entries a turn
/// (300 items for 27 turns); [prefix] keeps two chats' ids apart.
List<Item> longChat(String prefix, {int turns = 27}) => [
  for (var n = 0; n < turns; n++) ..._turn(prefix, n),
];

List<Item> _turn(String p, int n) => [
  Item(
    id: '$p-u$n',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text:
        'Turn $n: the session handling still loops when the cookie expires '
        'during a long upload. Can you look at `auth/session.go` and the '
        'middleware order again, and add a test for the upload path?',
  ),
  for (var r = 0; r < 3; r++)
    Item(
      id: '$p-r$n-$r',
      kind: ItemKind.ITEM_KIND_TOOL_CALL,
      toolKind: 'read',
      title: 'Read auth/file_$r.go',
      paths: ['auth/file_$r.go'],
      status: 'completed',
    ),
  Item(
    id: '$p-g$n',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'search',
    title: 'grep -rn "LoadSession" .',
    status: 'completed',
  ),
  if (n % 3 == 0) ...[
    Item(
      id: '$p-sa$n',
      kind: ItemKind.ITEM_KIND_TOOL_CALL,
      agent: 'Explore',
      agentId: 'ag$n',
      title: 'Find every caller of LoadSession',
      status: 'completed',
      subagent: Subagent(state: 'done'),
    ),
    for (var s = 0; s < 4; s++)
      Item(
        id: '$p-sa$n-$s',
        parent: '$p-sa$n',
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        toolKind: 'read',
        title: 'Read web/handler_$s.go',
        status: 'completed',
      ),
  ],
  Item(
    id: '$p-e$n',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'edit',
    title: 'Edit auth/middleware.go',
    paths: ['auth/middleware.go'],
    status: 'completed',
    diffs: [
      FileChange(
        path: 'auth/middleware.go',
        oldText: _code(n, 'RequireLogin'),
        newText: _code(n, 'LoadSession'),
      ),
    ],
  ),
  Item(
    id: '$p-x$n',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'execute',
    title: 'go test ./auth/... -run TestUpload$n',
    status: n.isEven ? 'completed' : 'failed',
  ),
  Item(
    id: '$p-t$n',
    kind: ItemKind.ITEM_KIND_THOUGHT,
    text:
        'The upload handler reads the body before the session middleware '
        'runs, so the expired cookie is seen late. Swapping them should '
        'be enough, but the test must cover the streaming case too.',
  ),
  Item(id: '$p-a$n', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: _reply(n)),
];

String _code(int n, String first) => [
  'package auth',
  '',
  '// Chain $n: the order the middlewares run in.',
  'func Chain(h http.Handler) http.Handler {',
  '\th = $first(h)',
  '\th = Recover(h)',
  '\th = Log(h)',
  '\treturn h',
  '}',
  '',
].join('\n');

String _reply(int n) =>
    '''
## What turn $n found

The loop comes from **two things meeting**: the expired cookie is still sent,
and `RequireLogin` runs before `LoadSession`, so it redirects before the
session is cleared. The upload path makes it worse, since the body is read
first and the redirect lands mid-stream.

1. **Order**: `LoadSession` now runs first, so an expired session is cleared.
2. **Upload**: the handler checks the session before reading the body.
3. **Tests**: `TestUpload$n` covers an expiry in the middle of an upload.

| File | Change | Lines |
| --- | --- | --- |
| `auth/middleware.go` | order swapped | 4 |
| `web/upload.go` | session checked first | 12 |
| `auth/session_test.go` | new test | 48 |

```go
func TestUpload$n(t *testing.T) {
\tsrv := httptest.NewServer(Chain(uploadHandler()))
\tdefer srv.Close()
\treq, _ := http.NewRequest("POST", srv.URL+"/upload", slowBody(1 << 20))
\treq.AddCookie(&http.Cookie{Name: "session", Value: expired()})
\tresp, err := http.DefaultClient.Do(req)
\tif err != nil {
\t\tt.Fatal(err)
\t}
\tif resp.StatusCode != http.StatusUnauthorized {
\t\tt.Fatalf("got %d, want 401", resp.StatusCode)
\t}
}
```

All 214 tests pass. Want me to look at the logout path as well, or at the
`Recover` middleware, which swallows the error and hides where it came from?
''';
