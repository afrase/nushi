// A chat's images that come as references (ADR 0099): the phone asks for
// them and fetches each as it shows, a few at a time, kept by hash; a box
// of the image's size with a spinner while it comes, Try again when it
// fails. The Mac asks for none and shows them inline as before.
import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart' as connect;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_images.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/outbox.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// One transparent pixel.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

final String _sha = 'a' * 64;

/// A 1600×1000 screenshot, as a reference.
ImageData _ref([String? sha]) => ImageData(
  mimeType: 'image/png',
  sha256: sha ?? _sha,
  size: Int64(3400000),
  width: 1600,
  height: 1000,
);

final Chat _chat = chat('c', 'claude', 'Fix the login redirect');

List<Item> _items(List<ImageData> images) => [
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Why does it redirect twice?',
  ),
  Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Here is the page after the first redirect:',
    images: images,
  ),
];

final Finder _loading = find.byKey(const ValueKey('image-loading'));
final Finder _failed = find.text('Couldn’t load the image');
final Finder _again = find.widgetWithText(Button, 'Try again');

/// Frames enough for a fetch, without settling (a spinner never does).
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The phone on a [size] screen in chat c, whose agent message has
/// [images]; GetChatImage answers as [image] does. It returns the events
/// requests and the GetChatImage requests, each as it is made.
Future<(Phone, FakeDaemon, List<EventsRequest>, List<GetChatImageRequest>)>
_phone(
  WidgetTester tester, {
  List<ImageData>? images,
  List<Item>? items,
  Object? Function(GetChatImageRequest)? image,
  Size size = const Size(390, 844),
}) async {
  viewport(tester, size, ratio: 3);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final events = <EventsRequest>[];
  final asked = <GetChatImageRequest>[];
  Object? answer(Object input) => switch (input) {
    GetChatRequest() => GetChatResponse(
      chat: _chat,
      items: items ?? _items(images ?? [_ref()]),
    ),
    GetChatImageRequest() => image?.call((asked..add(input)).last),
    _ => null,
  };
  final fake = FakeDaemon([_chat])
    ..answer = answer
    ..streams = (r) {
      if (r is EventsRequest) events.add(r);
      return null;
    };
  final phone = await startPhone(tester, fake);
  await tester.tap(find.text('Fix the login redirect'));
  await _frames(tester);
  return (phone, fake, events, asked);
}

void main() {
  setUpAll(loadFonts);

  group('ChatImages', () {
    test('keeps them by hash up to its cap, the least recently shown '
        'going first', () async {
      final fetched = <String>[];
      final images = ChatImages((chat, sha) async {
        fetched.add(sha);
        return Uint8List(10);
      }, maxBytes: 25);
      await images.load('c', 'a');
      await images.load('c', 'b');
      expect(images.kept('a'), isNotNull); // a is now the most recent
      await images.load('c', 'c'); // 30 bytes: b goes
      expect(images.kept('b'), isNull);
      expect(images.kept('a'), isNotNull);
      expect(images.kept('c'), isNotNull);
      await images.load('c', 'a');
      expect(fetched, ['a', 'b', 'c']);
    });

    test('fetches a few at a time, one at once for many asking, and drops '
        'one nobody shows any more', () async {
      final waits = <String, Completer<Uint8List>>{};
      final images = ChatImages(
        (chat, sha) => (waits[sha] = Completer()).future,
        parallel: 2,
      );
      var shown = true;
      final a = images.load('c', 'a');
      final again = images.load('c', 'a');
      final b = images.load('c', 'b');
      final c = images.load('c', 'c', wanted: () => shown);
      final d = images.load('c', 'd');
      expect(waits.keys, ['a', 'b']);
      shown = false; // c's row scrolled away
      waits['a']!.complete(Uint8List(1));
      expect(identical(await a, await again), isTrue);
      expect(waits.keys, ['a', 'b', 'd']);
      await expectLater(c, throwsA(isA<ImageNotWanted>()));
      waits['b']!.complete(Uint8List(1));
      waits['d']!.complete(Uint8List(1));
      await Future.wait([b, d]);
    });

    test('an echo’s references keep the bytes this app sent, not fetched '
        'back', () async {
      final fetched = <String>[];
      final images = ChatImages((chat, sha) async {
        fetched.add(sha);
        return Uint8List(0);
      });
      final sent = Uint8List.fromList(List.filled(100000, 7));
      ImageData ref(String sha, int size) =>
          ImageData(mimeType: 'image/png', sha256: sha, size: Int64(size));
      final outbox = Outbox(() {})
        ..keepImage = images.put
        ..send('Look', [
          ImageData(mimeType: 'image/png', data: sent),
          ImageData(mimeType: 'image/png', data: _png),
        ])
        ..adopt(
          Item(
            id: 'u',
            kind: ItemKind.ITEM_KIND_USER_MESSAGE,
            text: 'Look',
            images: [
              ref(_sha, sent.length),
              ImageData(mimeType: 'image/png', data: _png),
            ],
          ),
        );
      expect(outbox.sending, isEmpty);
      expect(images.kept(_sha)?.bytes, same(sent));
      expect((await images.load('c', _sha)).bytes, same(sent));
      expect(fetched, isEmpty);
      // Not one of another length in its place.
      outbox
        ..send('Again', [ImageData(mimeType: 'image/png', data: sent)])
        ..adopt(
          Item(
            id: 'v',
            kind: ItemKind.ITEM_KIND_USER_MESSAGE,
            text: 'Again',
            images: [ref('b' * 64, sent.length + 1)],
          ),
        );
      expect(images.kept('b' * 64), isNull);
    });

    test('whole: references fetched, inline images as they are', () async {
      final images = ChatImages((chat, sha) async => Uint8List.fromList(_png));
      final inline = ImageData(mimeType: 'image/gif', data: [1, 2]);
      final out = await images.whole('c', [_ref(), inline]);
      expect(out.first.data, _png);
      expect(out.first.mimeType, 'image/png');
      expect(out.first.sha256, isEmpty);
      expect(out.last, same(inline));
    });
  });

  testWidgets('the phone asks for references, and shows a box of the '
      'image’s size with a spinner while it comes', (tester) async {
    final (phone, fake, events, asked) = await _phone(
      tester,
      image: (_) => Completer<Object?>().future, // never comes
    );
    final get = fake.calls.whereType<GetChatRequest>().single;
    expect(get.imageRefs, isTrue);
    expect(events.single.imageRefs, isTrue);
    expect(_loading, findsOneWidget);
    expect(asked, hasLength(1));
    final box = tester.getRect(
      find.ancestor(of: _loading, matching: find.byType(AspectRatio)),
    );
    expect(box.width / box.height, closeTo(1.6, 0.01));
    expect(box.width, greaterThan(300)); // the phone's width, nearly
    expect(box.right, lessThanOrEqualTo(390));
    // The spinner is a clear one, not a hairline.
    final spinner = tester.getSize(_loading);
    expect(spinner.width, greaterThanOrEqualTo(28));
    await render(tester, find.byType(PhoneApp), 'phone_image_loading_390');
    await endPhone(tester, phone);
  });

  testWidgets('a loading image on the larger phone', (tester) async {
    final (phone, _, _, _) = await _phone(
      tester,
      size: const Size(430, 932),
      image: (_) => Completer<Object?>().future,
    );
    expect(_loading, findsOneWidget);
    expectTextInside(tester, 430);
    await render(tester, find.byType(PhoneApp), 'phone_image_loading_430');
    await endPhone(tester, phone);
  });

  testWidgets('the image shows once it comes, and a small one inline at '
      'once', (tester) async {
    final small = ImageData(mimeType: 'image/png', data: _png);
    final (phone, _, _, asked) = await _phone(
      tester,
      images: [_ref(), small],
      image: (_) => GetChatImageResponse(mimeType: 'image/png', data: _png),
    );
    expect(_loading, findsNothing);
    expect(find.byType(ClickableImage), findsNWidgets(2));
    expect(asked, hasLength(1));
    await endPhone(tester, phone);
  });

  testWidgets('a tool call’s images, alone or in a run, come as references '
      'too', (tester) async {
    Item call(String id, [List<ImageData> images = const []]) => Item(
      id: id,
      kind: ItemKind.ITEM_KIND_TOOL_CALL,
      title: 'Take a screenshot',
      status: 'completed',
      images: images,
    );
    final (phone, _, _, asked) = await _phone(
      tester,
      items: [
        Item(
          id: 'u',
          kind: ItemKind.ITEM_KIND_USER_MESSAGE,
          text: 'Show me the page',
        ),
        call('t1', [_ref('b' * 64)]),
        Item(id: 'a', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'And now:'),
        call('t2'),
        call('t3', [_ref('c' * 64)]),
      ],
      image: (_) => Completer<Object?>().future,
    );
    // t1 alone; t2 and t3 a folded run, which shows t3's image itself.
    expect(find.byType(ToolCallView), findsOneWidget);
    expect(find.byType(RunView), findsOneWidget);
    expect(_loading, findsNWidgets(2));
    expect(find.byIcon(Icons.broken_image), findsNothing);
    expect([for (final r in asked) r.sha256], ['b' * 64, 'c' * 64]);
    await render(tester, find.byType(PhoneApp), 'phone_tool_image_390');
    await endPhone(tester, phone);
  });

  testWidgets('a long chat’s images are fetched as it scrolls to them, '
      'not all as it opens', (tester) async {
    String sha(int i) => '$i'.padLeft(64, '0');
    final (phone, _, _, asked) = await _phone(
      tester,
      items: [
        for (var i = 0; i < 20; i++)
          Item(
            id: 'a$i',
            kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
            text: 'Step $i:',
            images: [_ref(sha(i))],
          ),
      ],
      image: (_) => GetChatImageResponse(mimeType: 'image/png', data: _png),
    );
    // It opens at its end: those on the screen and a screen above it.
    final first = [for (final r in asked) r.sha256];
    expect(first, contains(sha(19)));
    expect(first, isNot(contains(sha(0))));
    expect(first.length, lessThan(10));
    final list = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(Transcript),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    list.position.jumpTo(0);
    await _frames(tester);
    expect([for (final r in asked) r.sha256], contains(sha(0)));
    expect(asked.length, lessThan(20)); // not those in the middle
    await endPhone(tester, phone);
  });

  testWidgets('a failed image says so, and Try again fetches it again', (
    tester,
  ) async {
    var fail = true;
    final (phone, _, _, asked) = await _phone(
      tester,
      image: (_) => fail
          ? throw connect.ConnectException(connect.Code.unavailable, 'gone')
          : GetChatImageResponse(mimeType: 'image/png', data: _png),
    );
    expect(_failed, findsOneWidget);
    expect(_again, findsOneWidget);
    expect(find.byType(ClickableImage), findsNothing);
    expectTextInside(tester, 390);
    await render(tester, find.byType(PhoneApp), 'phone_image_failed_390');
    fail = false;
    await tester.tap(_again);
    await _frames(tester);
    expect(_failed, findsNothing);
    expect(find.byType(ClickableImage), findsOneWidget);
    expect(asked, hasLength(2));
    await endPhone(tester, phone);
  });

  testWidgets('the Mac asks for no references and shows images inline, as '
      'before', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
    viewport(tester, const Size(1700, 900));
    final events = <EventsRequest>[];
    final fake = FakeDaemon([_chat])
      ..answer = ((input) => input is GetChatRequest
          ? GetChatResponse(
              chat: _chat,
              items: _items([ImageData(mimeType: 'image/png', data: _png)]),
            )
          : null)
      ..streams = (r) {
        if (r is EventsRequest) events.add(r);
        return null;
      };
    final d = await fake.connect(tester)
      ..select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<GetChatRequest>().single.imageRefs, isFalse);
    expect(events.single.imageRefs, isFalse);
    expect(
      find.textContaining('after the first redirect', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(ClickableImage), findsOneWidget);
    expect(fake.calls.whereType<GetChatImageRequest>(), isEmpty);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Try again on a failed turn sends the message’s images whole', (
    tester,
  ) async {
    viewport(tester, const Size(760, 400));
    final fake = FakeDaemon([])
      ..chatImages[_sha] = ImageData(mimeType: 'image/png', data: _png);
    final d = await fake.connect(tester);
    final state = ChatState('c', '/Users/me/repo')
      ..agent = 'claude'
      ..items.addAll([
        Item(
          id: 'u',
          kind: ItemKind.ITEM_KIND_USER_MESSAGE,
          text: 'Look',
          images: [_ref()],
        ),
        Item(
          id: 'n',
          kind: ItemKind.ITEM_KIND_NOTICE,
          status: 'turn_failed',
          text: 'The turn failed',
        ),
      ]);
    await tester.pumpWidget(
      themed(
        Column(
          children: [
            for (final it in state.items)
              ItemView(it, state, d, live: false, still: true),
          ],
        ),
      ),
    );
    await _frames(tester);
    await tester.tap(_again);
    await _frames(tester);
    final sent = fake.calls.whereType<SendPromptRequest>().single;
    expect(sent.text, 'Look');
    expect(sent.images.single.data, _png);
    expect(sent.images.single.sha256, isEmpty);
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final (state, fetch) in [
      ('loading', (String _, String _) => Completer<Uint8List>().future),
      (
        'failed',
        (String _, String _) => Future<Uint8List>.error(StateError('gone')),
      ),
    ]) {
      testWidgets('an image on its way: $state ($name)', (tester) async {
        viewport(tester, const Size(480, 560));
        final images = ChatImages(fetch);
        await tester.pumpWidget(
          themed(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  ImageRef(images, 'c', _ref(), size: 240),
                  ImageRef(images, 'c', _ref('b' * 64)),
                ],
              ),
            ),
            tokens: tokens,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        // The Scaffold, not the app: the app adds the debug banner.
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/image_ref_${state}_$name.png'),
        );
      });
    }
  }
}
