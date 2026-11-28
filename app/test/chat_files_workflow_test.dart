// A Claude workflow's agents write files no item of the chat names: the
// daemon says them on the workflow's call (Workflow.written, API 156), and
// the chat's files take them in, placed by when they changed.
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';
import 'fixture_now.dart';

/// A write of the chat's own that ended [ago] before [fixtureNow].
Item _wrote(String id, String path, Duration ago, {String kind = 'edit'}) =>
    Item(
      id: id,
      kind: ItemKind.ITEM_KIND_TOOL_CALL,
      toolKind: kind,
      title: kind,
      status: 'completed',
      paths: [path],
      ended: msAgo(ago),
    );

const _m = Duration(minutes: 1);

void main() {
  test("a workflow's files sit among the chat's own by when they changed, "
      'each once, the one changed last first', () {
    final items = [
      _wrote('a', 'docs/plan.md', _m * 30),
      workflowWrote('wf', 'audit-docs', [
        ('docs/plan.md', _m * 5), // the chat's file, changed again by it
        ('docs/audit.md', _m * 12),
        ('src/audit.go', _m * 20), // code: only among every file written
      ], state: 'done')..ended = msAgo(_m * 25),
      _wrote('b', 'notes.md', _m * 10),
    ];
    expect(chatFiles(items), ['docs/plan.md', 'notes.md', 'docs/audit.md']);
    expect(chatFiles(items, any: true), [
      'docs/plan.md',
      'notes.md',
      'docs/audit.md',
      'src/audit.go',
    ]);
  });

  test('a file the chat deletes after a workflow wrote it goes; a file a '
      'workflow wrote with no time sits at its launch; a path inside the '
      "chat's folder is one name with the chat's", () {
    const folder = '/Users/me/nushi';
    final items = [
      _wrote('a', 'one.md', _m * 30),
      workflowWrote('wf', 'w', [
        ('/Users/me/nushi/docs/a.md', _m * 20),
        ('gone.md', _m * 15),
        ('/Users/me/other/b.md', _m * 14),
      ])..ended = msAgo(_m * 29),
      _wrote('d', 'gone.md', _m * 10, kind: 'delete'),
      workflowWrote('wf2', 'v', const [])
        ..ended = msAgo(_m * 8)
        ..workflow.written.add(WrittenFile(path: 'untimed.md')),
      _wrote('b', 'docs/a.md', _m * 5),
    ];
    expect(chatFiles(items, folder: folder), [
      'docs/a.md',
      'untimed.md',
      '/Users/me/other/b.md',
      'one.md',
    ]);
  });

  test('a delete in the same millisecond as a workflow write comes after '
      'it, and a long call is placed by its start', () {
    // The daemon's rule (chats' writtenBy): at each item the clock moves
    // up to its start, else its end, else its sending; the files changed
    // not after it go in, then the item.
    final items = [
      // A run launched at 00 writes y.md at 10; a subagent's call runs 02
      // to 30, and its child deletes y.md at 04, before that write.
      workflowWrote('wf', 'w', [('y.md', _m * 50)], state: 'done')
        ..started = msAgo(_m * 60),
      Item(id: 'agent', kind: ItemKind.ITEM_KIND_TOOL_CALL, toolKind: 'think')
        ..started = msAgo(_m * 58)
        ..ended = msAgo(_m * 30),
      _wrote('child', 'y.md', _m * 56, kind: 'delete')
        ..started = msAgo(_m * 56),
      // A run writes x.md, and the chat deletes it in that millisecond.
      workflowWrote('wf2', 'v', [('x.md', _m * 15)], state: 'done')
        ..started = msAgo(_m * 20),
      _wrote('d', 'x.md', _m * 15, kind: 'delete')..started = msAgo(_m * 15),
    ];
    expect(chatFiles(items), ['y.md']);
  });

  test('a workflow running before the loaded part puts back only what it '
      'wrote since the snapshot, not its files over newer ones', () {
    final run = workflowWrote('wf', 'audit-docs', [('docs/wf.md', _m * 50)]);
    final chat = ChatState('c', '/Users/me/nushi')
      ..load(
        GetChatResponse(
          items: [_wrote('a', 'docs/plan.md', _m * 30)],
          older: 10,
          // The chat's own x.md, newer than the run's wf.md.
          olderWritten: ['docs/x.md', 'docs/wf.md'],
          running: [run],
          seq: Int64(1),
        ),
      );
    expect(chatFilesOf(chat), ['docs/plan.md', 'docs/x.md', 'docs/wf.md']);
    chat.apply(
      EventsResponse(
        chatId: 'c',
        seq: Int64(2),
        item: ItemEvent(
          item: workflowWrote('wf', 'audit-docs', [
            ('docs/new.md', _m),
            ('docs/wf.md', _m * 50),
          ]),
          index: 4,
        ),
      ),
    );
    expect(chatFilesOf(chat), [
      'docs/new.md',
      'docs/plan.md',
      'docs/x.md',
      'docs/wf.md',
    ]);
    // Changed again since, it is the newest.
    chat.apply(
      EventsResponse(
        chatId: 'c',
        seq: Int64(3),
        item: ItemEvent(
          item: workflowWrote('wf', 'audit-docs', [
            ('docs/wf.md', Duration.zero),
            ('docs/new.md', _m),
          ]),
          index: 4,
        ),
      ),
    );
    expect(chatFilesOf(chat).first, 'docs/wf.md');
  });

  test("the chat's files follow a running workflow's as they arrive, and "
      'say which run wrote each', () {
    final chat = ChatState('c', '/Users/me/nushi')
      ..load(
        GetChatResponse(
          items: [
            userSays('u', 'Audit the docs.'),
            _wrote('a', 'docs/plan.md', _m * 30),
            workflowWrote('wf', 'audit-docs', [('docs/one.md', _m * 4)]),
          ],
          seq: Int64(1),
        ),
      );
    expect(chatFilesOf(chat), ['docs/one.md', 'docs/plan.md']);
    expect(writtenByWorkflow(chat, 'docs/one.md'), 'audit-docs');
    expect(writtenByWorkflow(chat, 'docs/plan.md'), isNull);
    chat.apply(
      EventsResponse(
        chatId: 'c',
        seq: Int64(2),
        item: ItemEvent(
          item: workflowWrote('wf', 'audit-docs', [
            ('docs/two.md', _m),
            ('docs/one.md', _m * 4),
          ]),
          index: 2,
        ),
      ),
    );
    expect(chatFilesOf(chat), ['docs/two.md', 'docs/one.md', 'docs/plan.md']);
    expect(chatWrote(chat), contains('docs/two.md'));
    // Launched in the last turn, its files are among the recent.
    expect(
      chatArtifacts(chat).recent,
      containsAll(['docs/two.md', 'docs/one.md']),
    );
  });

  test('a file two runs wrote names the one that changed it last; a run '
      'with no name yet by its id, as its card; one the chat changed since '
      'names none', () {
    final chat = ChatState('c', '/Users/me/nushi')
      ..load(
        GetChatResponse(
          items: [
            workflowWrote('w1', 'first', [('r.md', _m * 9), ('s.md', _m)]),
            workflowWrote('w2', 'second', [('r.md', _m * 3)]),
            workflowWrote('w3', '', [('t.md', _m * 2)]),
            _wrote('e', 's.md', Duration.zero),
          ],
        ),
      );
    expect(writtenByWorkflow(chat, 'r.md'), 'second');
    expect(writtenByWorkflow(chat, 's.md'), isNull);
    expect(writtenByWorkflow(chat, 't.md'), 'wf_w3');
  });

  test('a workflow running before the loaded part keeps its files up as '
      'its events come, as a trimmed one does', () {
    final run = workflowWrote('wf', 'audit-docs', [('docs/old.md', _m * 50)]);
    final chat = ChatState('c', '/Users/me/nushi')
      ..load(
        GetChatResponse(
          items: [_wrote('a', 'docs/plan.md', _m * 30)],
          older: 10,
          olderWritten: ['docs/old.md'],
          running: [run],
          seq: Int64(1),
        ),
      )
      ..apply(
        EventsResponse(
          chatId: 'c',
          seq: Int64(2),
          item: ItemEvent(
            item: workflowWrote('wf', 'audit-docs', [
              ('docs/new.md', _m),
              ('docs/old.md', _m * 50),
            ]),
            index: 4,
          ),
        ),
      );
    expect(chatFilesOf(chat), ['docs/new.md', 'docs/plan.md', 'docs/old.md']);
    expect(writtenByWorkflow(chat, 'docs/new.md'), 'audit-docs');
    // Trimmed, a loaded run's files stay in the chat's list.
    final trimmed = ChatState('c', '/Users/me/nushi')
      ..load(
        GetChatResponse(
          items: [
            userSays('u', 'Go.'),
            workflowWrote('wf', 'w', [('docs/w.md', _m * 40)], state: 'done'),
            userSays('u2', 'Again.'),
            _wrote('b', 'docs/b.md', _m * 2),
          ],
          seq: Int64(1),
        ),
      );
    expect(trimmed.trim(2), isTrue);
    expect(chatFilesOf(trimmed), ['docs/b.md', 'docs/w.md']);
  });

  test('a running workflow trimmed away puts back only what it writes '
      "after, not its older files over the chat's newer ones", () {
    final chat = ChatState('c', '/Users/me/nushi')
      ..load(
        GetChatResponse(
          items: [
            userSays('u', 'Audit.'),
            workflowWrote('wf', 'audit-docs', [('docs/wf.md', _m * 50)]),
            _wrote('a', 'docs/x.md', _m * 30),
            userSays('u2', 'Go on.'),
            _wrote('b', 'docs/b.md', _m * 2),
          ],
          seq: Int64(1),
        ),
      );
    expect(chatFilesOf(chat), ['docs/b.md', 'docs/x.md', 'docs/wf.md']);
    expect(chat.trim(2), isTrue);
    expect(chat.runningBefore.map((it) => it.id), ['wf']);
    expect(chatFilesOf(chat), ['docs/b.md', 'docs/x.md', 'docs/wf.md']);
    chat.apply(
      EventsResponse(
        chatId: 'c',
        seq: Int64(2),
        item: ItemEvent(
          item: workflowWrote('wf', 'audit-docs', [
            ('docs/new.md', _m),
            ('docs/wf.md', _m * 50),
          ]),
          index: 1,
        ),
      ),
    );
    expect(chatFilesOf(chat), [
      'docs/new.md',
      'docs/b.md',
      'docs/x.md',
      'docs/wf.md',
    ]);
  });
}
