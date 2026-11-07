import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nushi/chat_images.dart' show isImageRef;
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// A chat's messages on their way (`ChatState.outbox`): those this app
/// sent that the daemon hasn't shown back yet. [_changed] is the chat's
/// own notice that what the transcript shows changed.
class Outbox {
  new(this._changed);

  final VoidCallback _changed;

  /// Messages this app sent to the idle chat that the daemon hasn't shown
  /// back yet: the transcript shows each at once, faint, after the items.
  /// Each goes when its echo (the daemon's user message of the same text)
  /// comes, which takes its place in the transcript ([echoes]); when its
  /// send fails ([unsend]); when the daemon ran it as a command ([ran]); or,
  /// sent, when the chat's status or queue says the daemon has it without
  /// an echo. In the app's memory only.
  final List<Item> sending = [];

  /// The [sending] message (its id) each echo took the place of: the
  /// transcript keeps its entry for the echo, so it doesn't rise in again.
  final Map<String, String> echoes = {};

  /// [sending] messages whose send failed, fading out of the transcript.
  final Set<String> unsent = {};

  /// Where an echo's images that came as references (ADR 0099) go with
  /// the bytes this app sent, by their hash: the phone's `ChatImages`, so
  /// it shows them without fetching back what it just sent. Set by the
  /// sender.
  void Function(String sha256, Uint8List bytes)? keepImage;

  final _sent = <String>{}; // sent, the echo still to come
  int _sends = 0;

  /// A message on its way: shown in the transcript until its echo.
  Item send(
    String text,
    List<ImageData> images, {
    List<String> files = const [],
  }) {
    final it = Item(
      id: 'sending ${++_sends}',
      kind: ItemKind.ITEM_KIND_USER_MESSAGE,
      text: text,
      images: images,
      files: files,
    );
    sending.add(it);
    _changed();
    return it;
  }

  /// [it]'s send went through: the daemon has it, and its echo comes
  /// before the chat's next status.
  void sent(Item it) {
    if (sending.contains(it)) _sent.add(it.id);
  }

  /// [it] was a command the daemon ran in the agent's place
  /// (SendPromptResponse.ranCommand): no echo comes, so it goes now.
  void ran(Item it) => _drop(it.id);

  /// [it]'s send failed: it fades out over [fade], then goes.
  void unsend(Item it, {required Duration fade}) {
    if (!sending.contains(it)) return;
    if (fade == Duration.zero) {
      _drop(it.id);
    } else {
      unsent.add(it.id);
      Timer(fade, () => _drop(it.id));
    }
    _changed();
  }

  void _drop(String id) {
    final had = sending.length;
    sending.removeWhere((it) => it.id == id);
    unsent.remove(id);
    _sent.remove(id);
    if (sending.length != had) _changed();
  }

  /// [echo], a user message the daemon shows, takes the place of the
  /// message on its way with its text, if there is one.
  void adopt(Item echo) {
    if (echo.kind != ItemKind.ITEM_KIND_USER_MESSAGE) return;
    final it = sending
        .where((s) => s.text == echo.text && !unsent.contains(s.id))
        .firstOrNull;
    if (it == null) return;
    echoes[echo.id] = it.id;
    sending.remove(it);
    _sent.remove(it.id);
    _keepImages(it.images, echo.images);
  }

  /// Hands [keepImage] the bytes of each of [sent] whose echo in [shown]
  /// came as a reference: the same image in the same place, of its length.
  void _keepImages(List<ImageData> sent, List<ImageData> shown) {
    final keep = keepImage;
    if (keep == null || sent.length != shown.length) return;
    for (final (i, ref) in shown.indexed) {
      final data = sent[i].data;
      if (isImageRef(ref) && data.length == ref.size.toInt()) {
        keep(ref.sha256, data is Uint8List ? data : Uint8List.fromList(data));
      }
    }
  }

  /// Sent messages the daemon has without an echo (they went into the
  /// queue, say) go.
  void settle() {
    if (_sent.isEmpty) return;
    sending.removeWhere((it) => _sent.contains(it.id));
    _sent.clear();
  }

  /// Forgets the messages on their way, as the chat lets its items go
  /// (`ChatState.letGo`); [echoes] stay.
  void clear() {
    sending.clear();
    unsent.clear();
    _sent.clear();
  }
}
