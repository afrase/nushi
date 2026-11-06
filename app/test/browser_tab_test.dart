import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/preview_entry.dart';

import 'harness.dart';

void main() {
  group('the tabs', () {
    ChatState state() => ChatState('c', '/Users/me/nushi');

    test('each new browser tab is a tab of its own, last', () {
      final c = state()..openPreview('docs/a.md');
      final one = c.openBrowserTab();
      final two = c.openBrowserTab();
      expect(c.previewTabs.value, [const PreviewFile('docs/a.md'), one, two]);
      expect(c.preview.value, two);
      expect(c.previewFile, isNull);
      // A file still opens once, beside them.
      c.openPreview('/Users/me/nushi/docs/a.md');
      expect(c.previewTabs.value, hasLength(3));
      expect(c.previewFile, 'docs/a.md');
    });

    test('closing one shows the next; Close takes them all', () {
      final c = state()..openPreview('a.md');
      final one = c.openBrowserTab('http://localhost:3000');
      c
        ..openPreview('b.md')
        ..showPreviewTab(one)
        ..closePreview(one);
      expect(c.previewFile, 'b.md');
      expect(c.previewNames, ['a.md', 'b.md']);
      c.preview.value = null;
      expect(c.previewTabs.value, isEmpty);
    });

    test('Browser shows the last browser tab, or a new one', () {
      final c = state()..showBrowser();
      final first = c.preview.value! as BrowserTab;
      expect(first.address.value, '');
      final second = c.openBrowserTab();
      c
        ..openPreview('a.md')
        ..showBrowser();
      expect(c.preview.value, same(second));
      c.showBrowser();
      expect(c.previewTabs.value, hasLength(3));
    });

    test('a browser tab says its title, else its address, else New tab', () {
      final tab = BrowserTab();
      expect(tab.label, 'New tab');
      tab.address.value = 'http://localhost:3000/app';
      expect(tab.label, 'localhost:3000/app');
      tab.title.value = '  Tea shop  ';
      expect(tab.label, 'Tea shop');
      // A page names itself: a bidi override shows.
      tab.title.value = 'invoice\u202efdp.sh';
      expect(tab.label, 'invoice\ufffdfdp.sh');
      tab.title.value = 'x' * 300;
      expect(tab.label.length, 120);
    });
  });
}
