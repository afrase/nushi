import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/drafts_mac.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ImageData;

// What was kept and couldn't be read is never written over: a
// drafts.json that doesn't parse is set aside with the images it names,
// and a store whose load fails gets no save until a load reads it.

/// A store whose load fails while [kept] is null (a disk's or the
/// browser's error), and that records each save.
final class _Store implements DraftStore {
  Map<String, Map<String, Object?>>? kept;
  final saves = <Map<String, Map<String, Object?>>>[];

  @override
  Future<Map<String, Map<String, Object?>>> load() async =>
      kept ?? (throw const FileSystemException('read failed'));

  @override
  Future<void> save(Map<String, Map<String, Object?>> drafts) async =>
      saves.add(drafts);

  @override
  bool get textOnly => true;

  @override
  String? keepImage(ImageData image) => null;

  @override
  ImageData? image(String name) => null;
}

Directory _dir() {
  final dir = Directory.systemTemp.createTempSync('drafts-kept');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test('a drafts.json that doesn’t parse is set aside, and its images '
      'stay', () async {
    final dir = _dir();
    const bad = '{"d": {"text": "half", "images": ["1-0.png"]';
    File('${dir.path}/drafts.json').writeAsStringSync(bad);
    final image = File('${dir.path}/drafts/1-0.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);

    final drafts = Drafts(DraftFiles(dir.path));
    final c = ChatState('c', '/x');
    drafts.attach(c);
    await drafts.loaded;
    c.draft.text.text = 'new';
    await drafts.flush();

    final aside = dir.listSync().whereType<File>().where(
      (f) => f.uri.pathSegments.last.startsWith('drafts.json.unreadable-'),
    );
    expect(aside.single.readAsStringSync(), bad);
    expect(jsonDecode(File('${dir.path}/drafts.json').readAsStringSync()), {
      'c': {'text': 'new'},
    });
    expect(image.readAsBytesSync(), [1, 2, 3]);

    // The next launch reads the new file, and still sweeps nothing while
    // the set-aside one is there.
    final again = Drafts(DraftFiles(dir.path));
    final c2 = ChatState('c', '/x');
    again.attach(c2);
    await again.loaded;
    expect(c2.draft.text.text, 'new');
    c2.draft.text.text = '';
    await again.flush();
    expect(image.existsSync(), isTrue);
  });

  test('a load that fails saves nothing over the store until a load '
      'reads it', () async {
    final store = _Store();
    final drafts = Drafts(store);
    final c = ChatState('c', '/x');
    final d = ChatState('d', '/x');
    drafts
      ..attach(c)
      ..attach(d);
    await drafts.loaded;
    c.draft.text.text = 'typed while it failed';
    await drafts.flush();
    expect(store.saves, isEmpty);

    // It reads now: what was kept is back, the chat written to wins, and
    // both are saved.
    store.kept = {
      'c': {'text': 'older'},
      'd': {'text': 'kept'},
    };
    await drafts.flush();
    expect(d.draft.text.text, 'kept');
    expect(c.draft.text.text, 'typed while it failed');
    expect(store.saves.single.keys, unorderedEquals(['c', 'd']));
    expect(
      store.saves.single['c'],
      containsPair('text', 'typed while it failed'),
    );
    expect(store.saves.single['d'], {'text': 'kept'});
  });

  test('a forgotten chat stays forgotten once a failed load reads', () async {
    final store = _Store();
    final drafts = Drafts(store);
    await drafts.loaded;
    drafts.forget('d');
    await drafts.flush();
    expect(store.saves, isEmpty);
    store.kept = {
      'd': {'text': 'gone'},
      'e': {'text': 'kept'},
    };
    await drafts.flush();
    expect(store.saves.last, {
      'e': {'text': 'kept'},
    });
  });
}
