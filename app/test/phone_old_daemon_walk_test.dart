// The phone's core flows, walked end to end on a daemon that has only an
// old API's calls (ADR 0004): it keeps doing what the phone is for, and
// what it can't do fails with the old daemon's bar's words. Nothing
// throws, nothing hangs, nothing shows a raw error.
import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/chat_sheet.dart';
import 'package:nushi/phone/link.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/spinner.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The rpcs of API 100, release v0.2.26 (the first whose
/// internal/api/api.go has `Version = 100`): `git show
/// v0.2.26:proto/nushi/v1/nushi.proto | grep "rpc "`, names only, sorted.
const api100 = {
  'AddGitHubComment', 'AddGitHubToken', 'AddJiraComment', 'AddJiraSite', //
  'AddMcpServer', 'AllowGitHubToken', 'AllowJiraToken', 'AnswerPermission',
  'AnswerQuestion', 'ArchiveChat', 'ArrangeTerminals', 'AttachTerminal',
  'CancelTurn', 'CheckFolder', 'CheckForUpdates', 'CheckJiraSite',
  'ClearTranscripts', 'CloseSideChat', 'CloseTerminal', 'CommitStaged',
  'ConfirmPairing', 'DeleteChat', 'DeleteChatBranch', 'DeleteGitHubBranch',
  'DequeueGitHubPull', 'DisableGitHubAutoMerge', 'DismissRemovedChats',
  'EditMcpServer', 'EnableGitHubAutoMerge', 'EnqueueGitHubPull', 'Events',
  'FindChatFiles', 'FindChatPull', 'FindJiraIssues', 'ForkAsChat',
  'ForkChat', 'GetChat', 'GetChatItems', 'GetCleanUp', 'GetContextUsage',
  'GetDiff', 'GetFile', 'GetFolderStatus', 'GetGitHubFiles',
  'GetGitHubIssue', 'GetGitHubJobLog', 'GetGitHubMergeText',
  'GetGitHubPrompt', 'GetGitHubPull', 'GetGitHubStates',
  'GetJiraAttachment', 'GetJiraIssue', 'GetJiraJql', 'GetMemory',
  'GetPushKey', 'GetRelatedWorktrees', 'GetRemote', 'GetSettings',
  'KeepSideChat', 'LinkChatPull', 'LinkSkill', 'ListAgents',
  'ListAgentSessions', 'ListBranches', 'ListChats', 'ListCommits',
  'ListFiles', 'ListGitHubHosts', 'ListGitHubInbox', 'ListGitHubRepos',
  'ListJiraBoards', 'ListJiraIssues', 'ListJiraSites',
  'ListJiraTransitions', 'ListMcpServers', 'ListSkills', 'ListTerminals',
  'ListTranscripts', 'Log', 'LoginMcpServer', 'LogoutMcpServer',
  'MergeGitHubPull', 'MoveChat', 'OpenAgentSession', 'OpenTerminal',
  'PinChats', 'Ping', 'PlanDeleteChat', 'ReloadChat', 'RemoveAgent',
  'RemoveChatWorktree', 'RemoveGitHubToken', 'RemoveJiraSite',
  'RemoveMcpServer', 'RenameBranch', 'RenameChat', 'RenameTerminal',
  'ReopenChat', 'ReplyGitHubThread', 'RerunGitHubChecks', 'ResizeTerminal',
  'ResolveGitHubThread', 'RestartTerminal', 'RestartWhenIdle',
  'RestoreGitHubBranch', 'RevokeDevice', 'RewindChat', 'SendPrompt',
  'SendTestPush', 'SetChatColor', 'SetConfigOption', 'SetDeviceView',
  'SetJiraBoard', 'SetJiraSearches', 'SetMcpServerOn', 'SetPluginOn',
  'SetPushSubscription', 'SetRemote', 'SetSettings', 'SetSkillOn',
  'SetUpAgent', 'SleepChat', 'StageFiles', 'StartChat', 'StartPairing',
  'StopTask', 'SubmitGitHubReview', 'SuggestJiraJql', 'SwitchBranch',
  'TransitionJiraIssue', 'TrashSkill', 'TrustFolder', 'UninstallPlugin',
  'UnpairThisDevice', 'Unqueue', 'WatchChatFile', 'WriteCommitMessage',
  'WriteTerminal',
};

/// The rpcs of API 119, release v0.36.4 (the last below the floor), made
/// the same way: API 100's and these.
const api119 = <String>{
  ...api100,
  'ArchiveSideChat',
  'GetChatImage',
  'GetGitHubItems',
  'GetProjectIcon',
  'GetRelatedWorktreeStats',
  'InstallUpdate',
  'ListServers',
  'PinMessage',
  'RestoreSideChat',
  'SearchAgentSessions',
  'StartServer',
  'StopAllServers',
  'StopServer',
  'WatchChatFolder',
  'WatchServerLog',
  'WriteChatFile',
};

/// [fake] as a daemon with only [rpcs]: any other call or stream is
/// refused as Unimplemented, as a real old daemon refuses it, until it is
/// [newer] (every call through to [fake]).
class _OldDaemon implements Transport {
  new(this.fake, this.rpcs);

  final FakeDaemon fake;
  final Set<String> rpcs;
  bool newer = false;

  /// The calls refused, by name.
  final refused = <String>[];

  void _check(Spec<Object?, Object?> spec) {
    final name = spec.procedure.split('/').last;
    if (newer || rpcs.contains(name)) return;
    refused.add(name);
    throw ConnectException(
      Code.unimplemented,
      '${spec.procedure.substring(1)} is not implemented',
    );
  }

  @override
  Future<UnaryResponse<I, O>> unary<I extends Object, O extends Object>(
    Spec<I, O> spec,
    I input, [
    CallOptions? options,
  ]) async {
    _check(spec);
    return await fake.unary(spec, input, options);
  }

  @override
  Future<StreamResponse<I, O>> stream<I extends Object, O extends Object>(
    Spec<I, O> spec,
    Stream<I> input, [
    CallOptions? options,
  ]) async {
    _check(spec);
    return await fake.stream(spec, input, options);
  }
}

const _words = 'Open Nushi on your Mac to update its daemon';
const _title = 'Fix the flaky relay test';

/// Nothing threw, no text on screen is a raw Unimplemented, and [fake]
/// refused nothing itself (its refusal is an Unimplemented too, which the
/// phone would word as the old daemon's).
void _clean(WidgetTester tester, FakeDaemon fake, String step) {
  expect(tester.takeException(), isNull, reason: step);
  expect(fake.refused, isEmpty, reason: step);
  expect(
    find.textContaining(
      RegExp('not implemented|unimplemented', caseSensitive: false),
    ),
    findsNothing,
    reason: '$step: a raw Unimplemented on screen',
  );
}

/// A permission to run `make test`, [status] and [answer] as given.
Item _permission(String status, [String answer = '']) => Item(
  id: 'p',
  kind: ItemKind.ITEM_KIND_PERMISSION,
  status: status,
  title: 'make test',
  answer: answer,
  options: [
    Option(id: 'y', name: 'Yes'),
    Option(id: 'n', name: 'No'),
  ],
);

/// Claude's AskUserQuestion, one choice, [status] as given, with the
/// option ids picked in [values].
Item _question(String status, [List<String> values = const []]) => Item(
  id: 'q',
  kind: ItemKind.ITEM_KIND_QUESTION,
  status: status,
  text: 'Claude has a question',
  fields: [
    Field(
      id: 'question_0',
      title: 'Wait',
      description: 'How should the test wait?',
      type: FieldType.FIELD_TYPE_CHOICE,
      options: [
        Option(id: 'p', name: 'Poll the ping'),
        Option(id: 'l', name: 'A longer timeout'),
      ],
      values: values,
    ),
  ],
);

void main() {
  setUpAll(loadFonts);

  for (final (api, rpcs) in [(100, api100), (119, api119)]) {
    testWidgets('a phone on an API $api daemon walks its core flows, and '
        'what it lacks says to update it', (tester) async {
      viewport(tester, const Size(390, 844), ratio: 2);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final shot = api == 100;
      Future<void> snap(String name) async {
        if (shot) await render(tester, find.byType(PhoneApp), 'walk_$name');
      }

      // The chat's own status says so too: the fake sends the chat as it
      // has it with a pin.
      final idle = ChatStatus(canFork: true, canSleep: true);
      var ping = api;
      final fake =
          FakeDaemon([
              chat('a', 'claude', _title, status: idle),
              chat('b', 'codex', 'Review the Noise channel', age: 5),
            ])
            ..chatItems['a'] = [
              userSays('u1', 'Why does the relay test flake?'),
              agentSays('m1', 'The pairing races the first ping.'),
            ];
      fake.answer = (input) => switch (input) {
        PingRequest() => PingResponse(apiVersion: ping),
        AnswerPermissionRequest() => AnswerPermissionResponse(),
        SleepChatRequest() => SleepChatResponse(),
        StartChatRequest() => () {
          fake.chats.add(chat('n', 'claude', 'New chat'));
          return StartChatResponse(chatId: 'n');
        }(),
        _ => null,
      };
      final old = _OldDaemon(fake, rpcs);
      var seq = 0;
      void item(Item it, int index) => fake.emit(
        EventsResponse(
          chatId: 'a',
          seq: Int64(++seq),
          item: ItemEvent(item: it, index: index),
        ),
      );
      void status(ChatStatus s) =>
          fake.emit(EventsResponse(chatId: 'a', seq: Int64(++seq), status: s));
      final started = msAgo(const Duration(seconds: 5));
      final busy = ChatStatus(busy: true, started: started);
      Future<void> send(String text) async {
        await tester.enterText(find.byType(TextField).last, text);
        await tester.pump();
        await tester.tap(find.byTooltip(RegExp('^Send')));
        await tester.pumpAndSettle();
      }

      Future<void> sheet(String action) async {
        await tester.tap(find.bySemanticsLabel('Chat'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }

      final p = await startPhone(tester, old);
      await tester.pumpAndSettle();

      // The chats load, under the bar.
      expect(find.text(_title), findsOne);
      expect(find.text(_words), findsOne);
      _clean(tester, fake, 'the chats');
      await snap('chats');

      // A chat opens with its transcript.
      await tester.tap(find.text(_title));
      await tester.pumpAndSettle();
      expect(find.text('The pairing races the first ping.'), findsOne);
      status(idle);
      await tester.pumpAndSettle();
      _clean(tester, fake, 'the chat');

      // A message goes, and its turn runs.
      await send('Make it wait');
      expect(
        fake.calls.whereType<SendPromptRequest>().single.text,
        'Make it wait',
      );
      item(userSays('u2', 'Make it wait'), 2);
      status(busy);
      await tester.pumpAndSettle();
      expect(find.textContaining('Thinking'), findsOne);
      _clean(tester, fake, 'sent');
      await snap('running');

      // A permission card, answered.
      item(_permission('pending'), 3);
      status(ChatStatus(busy: true, started: started, waiting: true));
      await tester.pumpAndSettle();
      await snap('permission');
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(
        fake.calls.whereType<AnswerPermissionRequest>().single.optionId,
        'y',
      );
      item(_permission('allowed', 'y'), 3);
      status(busy);
      await tester.pumpAndSettle();
      expect(find.text('Answered: Yes'), findsOne);
      _clean(tester, fake, 'the permission');

      // A question card (Claude's AskUserQuestion), answered.
      item(_question('pending'), 4);
      status(ChatStatus(busy: true, started: started, waiting: true));
      await tester.pumpAndSettle();
      await snap('question');
      // A tap picks, the card's Send sends.
      await tester.tap(find.text('Poll the ping'));
      await tester.pumpAndSettle();
      expect(fake.calls.whereType<AnswerQuestionRequest>(), isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(QuestionCard),
          matching: find.text('Send'),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.calls.whereType<AnswerQuestionRequest>().single.itemId, 'q');
      item(_question('answered', ['p']), 4);
      status(busy);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Poll the ping', findRichText: true),
        findsOne,
      );
      _clean(tester, fake, 'the question');

      // The turn ends: the status line goes, no spinner is left.
      item(agentSays('m2', 'It polls the ping now.'), 5);
      status(idle);
      await tester.pumpAndSettle();
      expect(find.text('It polls the ping now.'), findsOne);
      expect(find.textContaining('Thinking'), findsNothing);
      expect(find.byType(Spinner), findsNothing);
      _clean(tester, fake, 'the turn ended');
      await snap('ended');

      // Stop: another turn, stopped.
      await send('Run it again');
      item(userSays('u3', 'Run it again'), 6);
      status(busy);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(RegExp('^Stop')));
      await tester.pumpAndSettle();
      expect(fake.calls.whereType<CancelTurnRequest>().single.chatId, 'a');
      status(idle);
      await tester.pumpAndSettle();
      expect(find.textContaining('Thinking'), findsNothing);
      expect(find.byType(Spinner), findsNothing);
      _clean(tester, fake, 'stopped');

      // The chats' list has it settled too, then the chat again.
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      expect(find.text('working'), findsNothing);
      expect(find.byType(Spinner), findsNothing);
      _clean(tester, fake, 'the list after the turns');
      await snap('settled');
      await tester.tap(find.text(_title));
      await tester.pumpAndSettle();

      // The chat's ⋯, each action. Rename keeps the sheet open.
      await tester.tap(find.bySemanticsLabel('Chat'));
      await tester.pumpAndSettle();
      await snap('sheet');
      await tester.tap(find.text('Rename…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Relay test fixed');
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      expect(
        fake.calls.whereType<RenameChatRequest>().single.title,
        'Relay test fixed',
      );
      _clean(tester, fake, 'Rename');
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();
      expect(fake.calls.whereType<PinChatsRequest>(), hasLength(1));
      expect(find.byType(ChatSheet), findsNothing);
      _clean(tester, fake, 'Pin');

      await sheet('Sleep');
      expect(fake.calls.whereType<SleepChatRequest>().single.chatId, 'a');
      expect(find.byType(ChatSheet), findsNothing);
      _clean(tester, fake, 'Sleep');

      // Files: API 100 lacks WatchChatFolder (API 103), which says so.
      await sheet('Files');
      await untilReal(tester, () => find.text('…').evaluate().isEmpty);
      if (rpcs.contains('WatchChatFolder')) {
        expect(find.text(_words), findsNothing); // no bar over the files
      } else {
        expect(old.refused, contains('WatchChatFolder'));
        expect(find.text(_words), findsOne); // the tree says it
      }
      _clean(tester, fake, 'Files');
      if (!rpcs.contains('WatchChatFolder')) await snap('files');
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();
      _clean(tester, fake, 'back from Files');

      await sheet('Fork');
      expect(fake.calls.whereType<ForkAsChatRequest>().single.chatId, 'a');
      expect(find.text('$_title (fork)'), findsWidgets);
      _clean(tester, fake, 'Fork');
      await tester.pump(const Duration(seconds: 10)); // its toast goes
      await tester.tap(find.bySemanticsLabel('Back').first);
      await tester.pumpAndSettle();

      await sheet('Archive');
      expect(fake.calls.whereType<ArchiveChatRequest>().single.chatId, 'a');
      expect(find.byType(ChatSheet), findsNothing);
      _clean(tester, fake, 'Archive');

      // A new chat starts, and opens.
      while (find.bySemanticsLabel('Back').evaluate().isNotEmpty) {
        await tester.tap(find.bySemanticsLabel('Back').first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.bySemanticsLabel('New chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(fake.started, hasLength(1));
      expect(find.text('New chat'), findsWidgets);
      _clean(tester, fake, 'New chat');
      await snap('new_chat');

      // The daemon restarts newer: the bar goes.
      ping = apiVersion;
      old.newer = true;
      expect(find.text(_words), findsOne);
      // Gone for one of the phone's pings, then back.
      fake.down = true;
      await tester.pump(Link.every + const Duration(seconds: 1));
      fake.down = false;
      await tester.pump(Link.every);
      await tester.pumpAndSettle();
      expect(find.text(_words), findsNothing);
      _clean(tester, fake, 'newer');
      await snap('newer');

      await endPhone(tester, p);
    }, variant: onPhone);
  }
}
