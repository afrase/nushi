// A chat's images that come as references (ADR 0099): the phone asks for
// them and fetches each as it shows, a few at a time, kept by hash; a box
// of the image's size with a spinner while it comes, Try again when it
// fails. The Mac asks for them too, and lets a row's image go once it's
// far off the screen.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:connectrpc/connect.dart' as connect;
import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_images.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/image_ref.dart';
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

/// A PNG of [width]×[height] of one color.
Future<Uint8List> _picture(WidgetTester tester, int width, int height) async =>
    (await tester.runAsync(() async {
      final r = ui.PictureRecorder();
      Canvas(r).drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = const Color(0xFF3366AA),
      );
      final image = await r.endRecording().toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;

/// A screenshot the phone sends: over 64 KB, so it comes back as a
/// reference; a pixel, then what a decoder never reads.
final Uint8List _shot = Uint8List(100000)..setAll(0, _png);
final String _shotSha = sha256.convert(_shot).toString();

/// [_shot] as the daemon shows it: a reference.
final ImageData _shotRef = ImageData(
  mimeType: 'image/png',
  sha256: _shotSha,
  size: Int64(_shot.length),
);

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

/// Waits on the real clock for every image in the tree to decode: until
/// one has, it has no size.
Future<void> _decode(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

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
  Object? Function(Object)? otherwise,
  ChatStatus? status,
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
      status: status,
    ),
    GetChatImageRequest() => image?.call((asked..add(input)).last),
    _ => otherwise?.call(input),
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
        ..images = images
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

    test('a queued message’s images are kept by the hash of their bytes, '
        'and let go when it is taken back', () async {
      final images = ChatImages((chat, sha) => throw StateError('fetched'));
      final small = ImageData(mimeType: 'image/png', data: _png);
      final big = ImageData(mimeType: 'image/png', data: _shot);
      final outbox = Outbox(() {})
        ..images = images
        ..hold([small, big]);
      await outbox.release(const []); // once the hold's work is done
      expect(await imageHash(_shot), _shotSha);
      expect(images.kept(_shotSha)?.bytes, same(_shot));
      // A small one comes inline: nothing to keep.
      expect(images.kept(sha256.convert(_png).toString()), isNull);
      // One kept already (shown in the chat) stays when it's taken back.
      final shown = Uint8List(70000)..[0] = 1;
      final shownSha = sha256.convert(shown).toString();
      images.put(shownSha, shown);
      outbox.hold([ImageData(mimeType: 'image/png', data: shown)]);
      await outbox.release([
        big,
        ImageData(mimeType: 'image/png', data: shown),
      ]);
      expect(images.kept(_shotSha), isNull);
      expect(images.kept(shownSha), isNotNull);
      // The Mac's outbox keeps none: its images come inline.
      final mac = Outbox(() {})..hold([big]);
      await mac.release(const []);
      expect(images.kept(_shotSha), isNull);
    });

    test('an image queued twice stays until both are taken back, and one '
        'shown stays', () async {
      final images = ChatImages((chat, sha) => throw StateError('fetched'));
      final big = ImageData(mimeType: 'image/png', data: _shot);
      final outbox = Outbox(() {})
        ..images = images
        ..hold([big])
        ..hold([big]);
      await outbox.release([big]);
      expect(images.kept(_shotSha), isNotNull);
      await outbox.release([big]);
      expect(images.kept(_shotSha), isNull);
      // Queued in one chat and shown in another, it stays when taken back.
      final other = Outbox(() {})..images = images;
      outbox.hold([big]);
      await outbox.release(const []);
      other.adopt(
        Item(
          id: 'u',
          kind: ItemKind.ITEM_KIND_USER_MESSAGE,
          images: [_shotRef],
        ),
      );
      await outbox.release([big]);
      expect(images.kept(_shotSha), isNotNull);
    });

    test('a queued message that runs before its images are hashed keeps '
        'them as any other, or leaves them to their fetch', () async {
      final fetch = Completer<Uint8List>();
      final images = ChatImages((chat, sha) => fetch.future);
      final big = ImageData(mimeType: 'image/png', data: _shot);
      final echo = Item(
        id: 'u',
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        images: [_shotRef],
      );
      final outbox = Outbox(() {})
        ..images = images
        ..hold([big])
        ..adopt(echo); // its echo, the hash still to come
      await outbox.release(const []);
      expect(images.holding, isFalse);
      expect(images.kept(_shotSha)?.bytes, same(_shot));
      images.forget(_shotSha);
      // Its row fetching it already: the fetch brings it, counted once.
      final row = images.load('c', _shotSha);
      outbox
        ..hold([big])
        ..adopt(echo);
      await outbox.release(const []);
      expect(images.holding, isFalse);
      expect(images.kept(_shotSha), isNull);
      fetch.complete(_shot);
      await row;
      expect(images.kept(_shotSha)?.bytes, same(_shot));
    });

    test('an image put while it is fetched is left to the fetch, counted '
        'once toward the cap', () async {
      final fetch = Completer<Uint8List>();
      final images = ChatImages((chat, sha) => fetch.future, maxBytes: 20);
      final row = images.load('c', 'a');
      expect(images.put('a', Uint8List(10)), isFalse);
      fetch.complete(Uint8List(10));
      await row;
      images.put('b', Uint8List(10)); // 20 bytes: both fit
      expect(images.kept('a'), isNotNull);
      expect(images.kept('b'), isNotNull);
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
    await _decode(tester); // the spinner until it has
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
    // Each row holds its image, those at the end too: a fetch again goes
    // over the relay.
    expect(find.byType(ClickableImage), findsNWidgets(asked.length));
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

  group('a message queued to a busy chat', () {
    final busy = ChatStatus(busy: true, images: true, started: Int64(1));
    final queued = QueuedMessage(
      id: 'q1',
      text: 'And this one?',
      images: [ImageData(mimeType: 'image/png', data: _shot)],
    );

    /// The phone in chat c, busy, its box's message with [_shot] queued.
    Future<(Phone, FakeDaemon, List<GetChatImageRequest>)> queue(
      WidgetTester tester,
    ) async {
      final (phone, fake, _, asked) = await _phone(
        tester,
        items: [_items(const []).first],
        status: busy,
        image: (_) => Completer<Object?>().future, // never comes
        otherwise: (input) =>
            input is UnqueueRequest ? UnqueueResponse(message: queued) : null,
      );
      phone.daemon!.chats['c']!.draft.images.value = [
        ImageData(mimeType: 'image/png', data: _shot),
      ];
      await tester.enterText(find.byType(TextField), 'And this one?');
      await tester.pump();
      await tester.tap(find.byTooltip('Queue'));
      await _frames(tester);
      final sent = fake.calls.whereType<SendPromptRequest>().single;
      expect((sent.queue, sent.images.single.data), (true, _shot));
      fake.emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(1),
          queue: ChatQueue(messages: [queued]),
        ),
      );
      await _frames(tester);
      return (phone, fake, asked);
    }

    testWidgets('its image shows from the bytes the phone sent when it runs, '
        'not fetched back', (tester) async {
      final (phone, fake, asked) = await queue(tester);
      fake
        ..emit(EventsResponse(chatId: 'c', seq: Int64(2), queue: ChatQueue()))
        ..emit(
          EventsResponse(
            chatId: 'c',
            seq: Int64(3),
            item: ItemEvent(
              index: 1,
              item: Item(
                id: 'u2',
                kind: ItemKind.ITEM_KIND_USER_MESSAGE,
                text: 'And this one?',
                images: [
                  ImageData(
                    mimeType: 'image/png',
                    sha256: _shotSha,
                    size: Int64(_shot.length),
                  ),
                ],
              ),
            ),
          ),
        );
      await _frames(tester);
      await _decode(tester);
      expect(find.byType(ClickableImage), findsOneWidget);
      expect(_loading, findsNothing);
      expect(asked, isEmpty);
      await endPhone(tester, phone);
    });

    testWidgets('removed from the queue, the phone keeps nothing of it', (
      tester,
    ) async {
      final (phone, fake, _) = await queue(tester);
      final images = phone.daemon!.images;
      expect(images.kept(_shotSha)?.bytes, same(_shot));
      await tester.tap(find.byTooltip('Remove'));
      await _frames(tester);
      expect(fake.calls.whereType<UnqueueRequest>().single.id, 'q1');
      expect(images.kept(_shotSha), isNull);
      expect(phone.daemon!.chats['c']!.draft.images.value, isEmpty);
      await endPhone(tester, phone);
    });

    testWidgets('taken back to edit, it keeps nothing either', (tester) async {
      final (phone, _, _) = await queue(tester);
      expect(phone.daemon!.images.kept(_shotSha), isNotNull);
      await tester.tap(find.byTooltip('Edit'));
      await _frames(tester);
      expect(phone.daemon!.images.kept(_shotSha), isNull);
      // Back in the box, to send again.
      expect(phone.daemon!.chats['c']!.draft.images.value, hasLength(1));
      await endPhone(tester, phone);
    });
  });

  testWidgets('the Mac asks for references too, and shows a small image '
      'inline', (tester) async {
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
    expect(fake.calls.whereType<GetChatRequest>().single.imageRefs, isTrue);
    expect(events.single.imageRefs, isTrue);
    expect(
      find.textContaining('after the first redirect', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(ClickableImage), findsOneWidget);
    expect(fake.calls.whereType<GetChatImageRequest>(), isEmpty);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('on the Mac a row far off the screen lets its image go, in '
      'its place, and takes it back from what is kept', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
    viewport(tester, const Size(1700, 900));
    String sha(int i) => '$i'.padLeft(64, '0');
    final shot = await _picture(tester, 800, 500);
    final fake = FakeDaemon([_chat])
      ..answer = ((input) => input is GetChatRequest
          ? GetChatResponse(
              chat: _chat,
              items: [
                for (var i = 0; i < 40; i++)
                  Item(
                    id: 'a$i',
                    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
                    text: 'Step $i:',
                    images: [_ref(sha(i))],
                  ),
              ],
            )
          : null);
    int fetched() => fake.calls.whereType<GetChatImageRequest>().length;
    for (var i = 0; i < 40; i++) {
      fake.chatImages[sha(i)] = ImageData(mimeType: 'image/png', data: shot);
    }
    final d = await fake.connect(tester)
      ..select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await _frames(tester);
    await _decode(tester);
    final last = find.byType(ImageRef).last;
    final shown = find.descendant(of: last, matching: find.byType(Image));
    expect(shown, findsOneWidget);
    final size = tester.getSize(last);
    expect(size.height, greaterThan(200)); // decoded, at its size
    final list = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(Transcript),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final end = list.maxScrollExtent;
    list.jumpTo(0);
    await _frames(tester);
    await _decode(tester);
    expect(shown, findsNothing);
    expect(tester.getSize(last), size);
    expect(list.maxScrollExtent, end);
    expect(find.byType(ClickableImage).evaluate().length, lessThan(fetched()));
    final before = fetched();
    list.jumpTo(end);
    await _frames(tester);
    expect(shown, findsOneWidget);
    expect(fetched(), before); // kept, not fetched again
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('an image that failed while the daemon was away is asked '
      'again once it is back', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
    viewport(tester, const Size(1700, 900));
    var away = true;
    var fetched = 0;
    final fake = FakeDaemon([_chat])
      ..answer = ((input) {
        if (input is GetChatRequest) {
          return GetChatResponse(chat: _chat, items: _items([_ref()]));
        }
        if (input is! GetChatImageRequest) return null;
        fetched++;
        if (away) {
          // A restart into an update, as the row asked.
          throw connect.ConnectException(
            connect.Code.unavailable,
            'daemon unavailable: dial failed',
          );
        }
        return GetChatImageResponse(mimeType: 'image/png', data: _png);
      });
    final d = await fake.connect(tester)
      ..select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await _frames(tester);
    expect(_failed, findsOneWidget);
    expect(fetched, 1);
    // The pings see it gone, then back.
    away = false;
    fake.down = true;
    await tester.pump(const Duration(seconds: 2));
    expect(fetched, 1);
    fake.down = false;
    await tester.pump(const Duration(seconds: 2));
    await _frames(tester);
    expect(_failed, findsNothing);
    expect(fetched, 2);
    expect(find.byType(ClickableImage), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // "Reconnected" goes
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a row keeps its place until its image decodes, fetched or '
      'taken back, and lets go at that size', (tester) async {
    viewport(tester, const Size(1000, 800));
    final shot = await _picture(tester, 1600, 1000);
    final images = ChatImages((_, _) async => shot, local: true);
    final list = ScrollController();
    addTearDown(list.dispose);
    await tester.pumpWidget(
      themed(
        SingleChildScrollView(
          controller: list,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageRef(images, 'c', _ref(), size: 240),
              const SizedBox(height: 20000),
            ],
          ),
        ),
      ),
    );
    final row = find.byType(ImageRef);
    final heights = <double>[];
    Future<void> pumps() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump();
        heights.add(tester.getSize(row).height);
      }
    }

    // Fetched, not decoded yet: an image has no size until it is.
    await pumps();
    expect(find.byType(ClickableImage), findsOneWidget);
    // Far off before it decoded: it lets go at the size it holds.
    list.jumpTo(10000);
    await pumps();
    expect(find.byType(ClickableImage), findsNothing);
    list.jumpTo(0);
    await pumps();
    expect(find.byType(ClickableImage), findsOneWidget);
    await _decode(tester);
    heights.add(tester.getSize(row).height);
    expect(heights, everyElement(240));
  });

  for (final width in [1700.0, 720.0]) {
    testWidgets('on the Mac at $width wide, an image coming, one failed and '
        'one shown', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('nushi/fonts'),
            (_) async => <String>[],
          );
      viewport(tester, Size(width, 900), ratio: 2);
      final shot = await _picture(tester, 800, 500);
      final waits = Completer<GetChatImageResponse>();
      final fake = FakeDaemon([_chat])
        ..answer = ((input) => switch (input) {
          GetChatRequest() => GetChatResponse(
            chat: _chat,
            items: _items([_ref('a' * 64), _ref('b' * 64), _ref('c' * 64)]),
          ),
          GetChatImageRequest(sha256: final s) when s == 'a' * 64 =>
            waits.future,
          GetChatImageRequest(sha256: final s) when s == 'b' * 64 =>
            throw connect.ConnectException(connect.Code.notFound, 'gone'),
          GetChatImageRequest() => GetChatImageResponse(
            mimeType: 'image/png',
            data: shot,
          ),
          _ => null,
        });
      final d = await fake.connect(tester)
        ..select('c');
      await tester.pumpWidget(NushiApp(daemon: d));
      await _frames(tester);
      await _decode(tester);
      expect(_loading, findsOneWidget);
      expect(_failed, findsOneWidget);
      expect(find.byType(ClickableImage), findsOneWidget);
      await render(tester, find.byType(NushiApp), 'mac_images_${width ~/ 1}');
      await closeView(tester, d);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

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
