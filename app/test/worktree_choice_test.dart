import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/worktree.dart';

import 'fake_daemon.dart';

const _repo = '/Users/me/nushi';

File get _appJson => File('$dataDir/app.json');

/// A chat without messages in [_repo].
ChatState _fresh(String id) =>
    ChatState(id, _repo)..load(GetChatResponse(status: ChatStatus()));

void main() {
  setUpAll(() async {
    await loadFonts();
    // An app.json from before step 337, which remembered the repositories
    // whose new chats got a worktree; read before anything else is.
    Directory(dataDir).createSync(recursive: true); // the tests' own
    _appJson.writeAsStringSync(
      jsonEncode({
        'details': false,
        'worktrees': [_repo],
      }),
    );
  });

  test('an old app.json with worktrees loads, and the key goes on the next '
      'save', () {
    expect(showDetails.value, isFalse); // the rest of it was read
    showDetails.value = true;
    final saved = jsonDecode(_appJson.readAsStringSync()) as Map;
    expect(saved['details'], isTrue);
    expect(saved.containsKey('worktrees'), isFalse);
  });

  testWidgets('the New worktree chip moves this chat only: the next new chat '
      'in the repository starts in the folder itself', (tester) async {
    final fake = FakeDaemon([Chat(id: 'c', agent: 'claude', folder: _repo)])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(git: true),
        _ => null,
      };
    final d = await fake.connect(tester);

    // Even with the old key naming this repository.
    await d.startChat(_repo, 'claude');
    expect(fake.started.last.worktree, isFalse);

    final chat = _fresh('c');
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: NewChatBar(chat: chat, daemon: d),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New worktree'));
    await tester.pumpAndSettle();
    final moved = fake.calls.whereType<MoveChatRequest>().single;
    expect([moved.chatId, moved.folder, moved.worktree], ['c', _repo, true]);

    await d.startChat(_repo, 'claude');
    expect(fake.started.last.worktree, isFalse);
    // A new chat moved into the repository by its folder button doesn't
    // follow the choice either.
    expect(await d.moveChat(_fresh('n'), _repo), isTrue);
    expect(fake.calls.whereType<MoveChatRequest>().last.worktree, isFalse);
    // An issue's chat still asks for one.
    await d.startChat(
      _repo,
      'claude',
      issue: IssueChat(site: 's', key: 'AB-1', summary: 'x', branch: 'AB-1'),
    );
    expect(fake.started.last.worktree, isTrue);
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  });
}
