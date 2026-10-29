// The phone's drafts in a real browser's IndexedDB: kept, back after a
// reload (a new app on the same storage), gone with Forget this Mac.
// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/phone/phone_drafts.dart';
import 'package:nushi/phone/platform.dart';

void main() {
  test('a draft comes back from IndexedDB after a reload', () async {
    final platform = PhonePlatform();
    final drafts = Drafts(PhoneDrafts(platform));
    final chat = ChatState('c', '/x');
    drafts.attach(chat);
    await drafts.loaded;
    chat.draft
      ..text.text = 'From the bus ${'x' * (1 << 20)}'
      ..addReply((quote: 'a line', text: 'fix this', from: ''));
    await drafts.flush();

    final again = Drafts(PhoneDrafts(PhonePlatform()));
    final back = ChatState('c', '/x');
    again.attach(back);
    await again.loaded;
    expect(back.draft.text.text, chat.draft.text.text);
    expect(back.draft.replies.value.single.text, 'fix this');

    await platform.clear(); // Forget this Mac
    expect(await platform.loadDrafts(), isNull);
  });
}
