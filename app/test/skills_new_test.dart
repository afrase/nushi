import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone_drafts.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/trust_card.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The owner clicked New skill… for PiG and got an empty new chat: the
// request was dropped when the chat's snapshot hadn't come yet, and went
// nowhere when the start ended with another chat selected (ADR 0052).

const _shared = 'Help me write a new skill shared by every agent';
const _claudeOnly = 'Help me write a new Claude Code skill.';

/// The whole app needs the Mac's menu bar.
final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// What the daemon does for [_app], whose Skills view is on [folder] (one
/// per test, as a folder's list outlives the daemon): the new chat is `new`,
/// its snapshot held on [snapshot] and the start's answer on [start] when
/// given, and a folder in [untrusted] brings code to approve.
FakeDaemon _fake(
  String folder, {
  Completer<GetChatResponse>? snapshot,
  Completer<void>? start,
  Set<String> untrusted = const {},
  bool announce = true,
}) {
  late final FakeDaemon fake;
  return fake = FakeDaemon([chat('a', 'codex', 'Other', folder: folder)])
    ..answer = (input) async {
      switch (input) {
        case ListSkillsRequest(:final agent):
          return ListSkillsResponse(readsShared: agent != 'claude');
        case CheckFolderRequest(:final folder) when untrusted.contains(folder):
          return CheckFolderResponse(
            key: 'k',
            runs: [FolderRun(file: '$folder/.mcp.json', what: 'x')],
          );
        case StartChatRequest(:final agent, :final folder):
          await start?.future;
          final made = chat('new', agent, 'New', folder: folder);
          fake.chats.add(made);
          if (announce) fake.emit(EventsResponse(chatId: 'new', chat: made));
          return StartChatResponse(chatId: 'new');
        case GetChatRequest(chatId: 'new') when snapshot != null:
          return await snapshot.future;
      }
      return null;
    };
}

/// The app on [fake] at [agent]'s Skills view, with chat `a` selected before
/// it.
Future<Daemon> _app(
  WidgetTester tester,
  FakeDaemon fake,
  String agent, {
  Drafts? drafts,
}) async {
  viewport(tester, const Size(1200, 700));
  final d = await fake.connect(tester, drafts: drafts);
  await tester.pumpWidget(NushiApp(daemon: d));
  d
    ..select('a')
    ..showSkills(fake.chats.first.folder, agent: agent);
  await tester.pumpAndSettle();
  return d;
}

/// Clicks New skill…, and [choice] when the dialog asks where it goes.
Future<void> _newSkill(WidgetTester tester, {String? choice}) async {
  await tester.tap(find.text('New skill…'));
  await tester.pumpAndSettle();
  if (choice != null) {
    await tester.tap(find.text(choice));
    await tester.pumpAndSettle();
  }
}

/// The text in the box of the chat that shows.
String _box(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byType(Composer),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

/// What a request holds to in every case: nothing went to the agent.
void _nothingSent(FakeDaemon fake) =>
    expect(fake.calls.whereType<SendPromptRequest>(), isEmpty);

void main() {
  setUpAll(loadFonts);

  for (final (agent, choice, request) in [
    ('codex', null, _shared),
    ('pig', null, _shared),
    ('claude', 'In .agents/skills', _shared),
    ('claude', 'In .claude/skills', _claudeOnly),
  ]) {
    testWidgets('$agent, ${choice ?? 'no question'}: the request is in the '
        "new chat's box, not sent", (tester) async {
      final fake = _fake('/Users/me/$agent-${request.length}');
      final d = await _app(tester, fake, agent);
      await _newSkill(tester, choice: choice);
      expect(fake.started.single.agent, agent);
      expect(d.selectedId, 'new');
      expect(_box(tester), startsWith(request));
      _nothingSent(fake);
      await closeView(tester, d);
    }, variant: _mac);
  }

  testWidgets('the request stays when the snapshot comes late', (tester) async {
    final snapshot = Completer<GetChatResponse>();
    final fake = _fake('/Users/me/late', snapshot: snapshot);
    final d = await _app(tester, fake, 'pig');
    await _newSkill(tester);
    expect(d.chats['new']!.loaded, isFalse);
    expect(d.chats['new']!.draft.text.text, startsWith(_shared));
    snapshot.complete(GetChatResponse());
    await tester.pumpAndSettle();
    expect(d.chats['new']!.loaded, isTrue);
    expect(_box(tester), startsWith(_shared));
    _nothingSent(fake);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a folder to trust: nothing until Start anyway, then the '
      'request is in the box', (tester) async {
    final snapshot = Completer<GetChatResponse>();
    const folder = '/Users/me/trust';
    final fake = _fake(folder, snapshot: snapshot, untrusted: {folder});
    final d = await _app(tester, fake, 'pig');
    await _newSkill(tester);
    expect(find.byType(TrustCard), findsOne);
    expect(fake.started, isEmpty);
    await tester.tap(find.text('Start anyway'));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'new');
    expect(_box(tester), startsWith(_shared));
    snapshot.complete(GetChatResponse());
    await tester.pumpAndSettle();
    expect(_box(tester), startsWith(_shared));
    _nothingSent(fake);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a trust card up when the chat starts: the request waits in '
      'the new chat, which stays unselected', (tester) async {
    final start = Completer<void>();
    final fake = _fake(
      '/Users/me/card',
      start: start,
      untrusted: {'/Users/me/site'},
    );
    final d = await _app(tester, fake, 'pig');
    await _newSkill(tester);
    final other = d.startChat('/Users/me/site', 'codex');
    await tester.pumpAndSettle();
    expect(find.byType(TrustCard), findsOne);
    start.complete();
    await tester.pumpAndSettle();
    expect(d.selectedId, 'a');
    expect(d.chats['a']!.draft.text.text, isEmpty);
    expect(d.chats['new']!.draft.text.text, startsWith(_shared));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await other;
    d.select('new');
    await tester.pumpAndSettle();
    expect(_box(tester), startsWith(_shared));
    _nothingSent(fake);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the user went elsewhere: the request goes to the new chat '
      'all the same', (tester) async {
    final start = Completer<void>();
    final fake = _fake('/Users/me/away', start: start);
    final d = await _app(tester, fake, 'pig');
    await _newSkill(tester);
    // Settings shut as the start began (ADR 0087).
    expect(d.settingsOpen, isNull);
    d.go(const JiraPlace());
    await tester.pumpAndSettle();
    start.complete();
    await tester.pumpAndSettle();
    expect(d.selectedId, 'a');
    expect(d.place, const JiraPlace());
    expect(d.chats['new']!.draft.text.text, startsWith(_shared));
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a start that fails writes nothing, and shows why', (
    tester,
  ) async {
    final fake = _fake('/Users/me/fails')
      ..startError = "couldn't start PiG: not found";
    final d = await _app(tester, fake, 'pig');
    await _newSkill(tester);
    expect(fake.started.single.agent, 'pig');
    expect(d.chats.containsKey('new'), isFalse);
    expect(d.chats['a']!.draft.text.text, isEmpty);
    expect(find.textContaining("couldn't start PiG"), findsWidgets);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('a trust card turned down writes nothing', (tester) async {
    const folder = '/Users/me/no';
    final fake = _fake(folder, untrusted: {folder});
    final d = await _app(tester, fake, 'pig');
    await _newSkill(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.started, isEmpty);
    expect(d.chats.containsKey('new'), isFalse);
    expect(d.chats['a']!.draft.text.text, isEmpty);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the request is kept on disk before the daemon announces the '
      'chat, and an empty kept draft leaves it', (tester) async {
    final platform = PhonePlatform()
      ..drafts = jsonEncode({'new': <String, Object?>{}});
    final drafts = Drafts(PhoneDrafts(platform));
    final fake = _fake('/Users/me/kept', announce: false);
    final d = await _app(tester, fake, 'pig', drafts: drafts);
    await _newSkill(tester);
    expect(_box(tester), startsWith(_shared));
    await drafts.flush();
    expect(platform.drafts, contains(_shared));
    fake.emit(EventsResponse(chatId: 'new', chat: fake.chats.last));
    await tester.pumpAndSettle();
    expect(_box(tester), startsWith(_shared));
    await closeView(tester, d);
    await tester.pump(const Duration(seconds: 4)); // the ping's timeout
  }, variant: _mac);
}
