import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';

/// Prose and code with emoji, ZWJ sequences, flags, skin tones, CJK
/// without spaces and combining marks.
const _text =
    'Done 👍🏽 the build 👩‍💻 passes on 🇯🇵 and 🇫🇷 now ✅ café (café) '
    'and naïve.\n\n'
    '日本語のテキストはスペースなしで長く続くことがあるので四十文字を超える単語として扱われる'
    'かもしれません🎉🎉🎉 終わり。\n\n'
    'A family 👨‍👩‍👧‍👦 and a flag 🏳️‍🌈 then ❤️ and 1️⃣ end.\n\n'
    '```\n'
    'let greeting = "héllo 👋🏿 wörld" // 注释 👩‍👩‍👦\n'
    'let flags = ["🇩🇪", "🇬🇧", "🇺🇸"] // café é́\n'
    '```\n\n'
    'After the code 🙂 the end.';

/// [text] in chunks of 1 to 7 code points, never splitting a surrogate
/// pair (the daemon sends whole UTF-8) but often a grapheme cluster.
List<String> _chunks(String text, Random r) {
  final runes = text.runes.toList();
  final out = <String>[];
  var at = 0;
  while (at < runes.length) {
    final n = min(runes.length - at, 1 + r.nextInt(7));
    out.add(String.fromCharCodes(runes.sublist(0, at + n)));
    at += n;
  }
  return out;
}

/// Why [s] draws a broken character: a stream mark (private use) or a
/// lone half of a surrogate pair; null when it doesn't.
String? _broken(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0xE000 && c <= 0xE003) return 'a mark at $i';
    final next = i + 1 < s.length ? s.codeUnitAt(i + 1) : 0;
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (next < 0xDC00 || next > 0xDFFF) return 'a lone high half at $i';
      i++;
    } else if (c >= 0xDC00 && c <= 0xDFFF) {
      return 'a lone low half at $i';
    }
  }
  return null;
}

/// The grapheme clusters of [s].
Set<String> _clusters(String s) => s.characters.toSet();

void main() {
  setUpAll(loadFonts);

  testWidgets('streaming emoji, ZWJ sequences, flags, CJK and combining '
      'marks in uneven chunks: no frame draws a broken character or splits '
      'a cluster', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')
      ..loaded = true
      ..busy = true
      ..items.add(
        Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Go'),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: chat,
            builder: (context, _) =>
                Transcript(chat: chat, daemon: d, onReply: null),
          ),
        ),
      ),
    );
    final whole = _clusters(_text);
    var frames = 0;
    void check(String when) {
      frames++;
      for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
        // An icon's glyph is in the private use area too.
        if (r.text.style?.fontFamily == 'MaterialIcons') continue;
        final s = r.text.toPlainText().replaceAll('\u{FFFC}', '');
        expect(_broken(s), isNull, reason: '$when: "$s"');
        // Every cluster drawn is one of the text's, and no span (a fresh
        // run, a highlighted token) starts inside one.
        for (final c in s.characters) {
          if (c.codeUnitAt(0) < 0x80 && c.length == 1) continue; // ASCII
          expect(whole, contains(c), reason: '$when: "$c" in "$s"');
        }
        var at = 0;
        final bounds = {0};
        for (final c in s.characters) {
          bounds.add(at += c.length);
        }
        at = 0;
        r.text.visitChildren((span) {
          if (span is TextSpan && span.text != null) {
            expect(bounds, contains(at), reason: '$when: a span in "$s"');
            at += span.text!.length;
          } else if (span is WidgetSpan) {
            at += 0; // the caret, dropped above
          }
          return true;
        });
      }
    }

    void stream(String text) {
      final it = Item(
        id: 'm',
        kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
        text: text,
      );
      final i = chat.items.indexWhere((x) => x.id == 'm');
      if (i < 0) {
        chat.items.add(it);
      } else {
        chat.items[i] = it;
      }
      chat.notifyListeners();
    }

    final r = Random(11);
    for (final (i, chunk) in _chunks(_text, r).indexed) {
      stream(chunk);
      await tester.pump();
      check('chunk $i');
      // Mostly a frame between chunks, sometimes a few.
      for (var f = r.nextInt(3); f >= 0; f--) {
        await tester.pump(const Duration(milliseconds: 16));
        check('chunk $i, a frame on');
      }
    }
    for (var f = 0; f < 30; f++) {
      await tester.pump(const Duration(milliseconds: 16));
      check('after the stream, frame $f');
    }
    chat
      ..busy = false
      ..notifyListeners();
    await tester.pumpAndSettle();
    check('ended');
    expect(frames, greaterThan(100));
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  });
}
