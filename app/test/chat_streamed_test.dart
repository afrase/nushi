import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_find.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/details_panel.dart';
import 'package:nushi/files_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'panes_app.dart';

// Text streaming into an item tells ChatState.streamed, not the chat
// itself: what shows item content follows it, and the header, the details
// panel and the Files tree don't build again per chunk.

/// Panes' chat with a message from its subagent among the subagent's steps.
final List<Item> _items = [
  ...panesItems.take(3),
  Item(
    id: 'sm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    parent: 'a',
    text: 'Looking at the handler',
  ),
  ...panesItems.skip(3),
];

int _seq = 1000;

/// A chunk of [text] streamed into chat c's item [id].
EventsResponse _chunk(String id, String text) => EventsResponse(
  chatId: 'c',
  seq: Int64(++_seq),
  item: ItemEvent(
    item: Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text),
    append: true,
  ),
);

/// Whether [e] is, or is inside, a widget of type [T].
bool _in<T extends Widget>(Element e) =>
    e.widget is T || e.findAncestorWidgetOfExactType<T>() != null;

void main() {
  setUpAll(loadFonts);

  testWidgets("streamed text shows in the transcript, a subagent's pane and "
      "find's count; the header, the details panel and the Files tree don't "
      'build again', (tester) async {
    final (d, fake) = await panesApp(
      tester,
      width: 2400,
      items: _items,
      open: (
        side: false,
        files: true,
        subagent: true,
        command: false,
        previews: 0,
        browser: 0,
      ),
    );
    final chat = d.chats['c']!;
    expect(find.byType(ChatHeader), findsOneWidget);
    expect(find.byType(DetailsPanel), findsOneWidget);
    expect(find.byType(FilesTree), findsOneWidget);
    chat.find.query = 'redirect';
    await tester.pump(ChatFind.pause);
    await tester.pumpAndSettle();
    final hits = chat.find.hits.length;
    expect(hits, greaterThan(0));

    var header = 0;
    var details = 0;
    var tree = 0;
    debugOnRebuildDirtyWidget = (e, _) {
      if (_in<ChatHeader>(e)) header++;
      if (_in<DetailsPanel>(e)) details++;
      if (_in<FilesTree>(e)) tree++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    for (final words in [' Then', ' the redirect', ' runs.']) {
      fake.emit(_chunk('m', words));
      await tester.pump();
    }
    fake.emit(_chunk('sm', ' and its redirect'));
    await tester.pump();
    // What came types out (Arriving): the frames until it has.
    await tester.pumpAndSettle();
    debugOnRebuildDirtyWidget = null;

    expect((header, details, tree), (0, 0, 0));
    expect(
      chat.items.firstWhere((it) => it.id == 'm').text,
      endsWith('Then the redirect runs.'),
    );
    expect(
      find.textContaining('Then the redirect runs.', findRichText: true),
      findsOneWidget,
    );
    // The subagent's pane shows its step's text as it streams.
    expect(
      find.textContaining(
        'Looking at the handler and its redirect',
        findRichText: true,
      ),
      findsWidgets,
    );
    // Two more matches streamed in: the find counts them.
    expect(chat.find.hits.length, hits + 2);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a whole item still tells the chat: a background command's "
      'output shows in its pane', (tester) async {
    final (d, fake) = await panesApp(
      tester,
      width: 1900,
      open: (
        side: false,
        files: false,
        subagent: false,
        command: true,
        previews: 0,
        browser: 0,
      ),
    );
    final cmd = panesItems.firstWhere((it) => it.id == 'cmd').deepCopy()
      ..backgroundCommand.output =
          'ready on http://localhost:3000\n'
          'compiled in 412ms\n';
    fake.emit(
      EventsResponse(
        chatId: 'c',
        seq: Int64(++_seq),
        item: ItemEvent(item: cmd),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('compiled in 412ms'), findsWidgets);
    await closeView(tester, d);
  }, variant: onMac);
}
