import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/settings.dart';

// Asking which chats the prefs keep something for (the Mac does on every
// chat list) makes only the prefs kept by chat: a pref made is saved from
// then on, so one made here would pin its default into app.json, and a
// later release's new default would never reach the user.

void main() {
  test('the chats kept pin no other pref’s default', () async {
    chatsKept();
    showDetails.value = false;
    await pumpEventQueue();
    final saved = readSaved();
    expect(saved['details'], isFalse);
    for (final key in ['githubFindingBots', 'usageRange', 'jiraGroups']) {
      expect(saved, isNot(contains(key)), reason: key);
    }
  });
}
