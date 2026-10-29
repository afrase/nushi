import 'dart:async';

import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ImageData;

/// Where [Drafts] keeps them: `drafts.json` on the Mac (drafts_mac.dart),
/// the browser's IndexedDB on the phone.
abstract interface class DraftStore {
  /// Every chat's draft as [save] kept it, by chat id.
  Future<Map<String, Map<String, Object?>>> load();

  /// Keeps [drafts], all of them, in place of what was kept.
  Future<void> save(Map<String, Map<String, Object?>> drafts);

  /// Only the boxes' text and the reply cards are kept (the phone).
  bool get textOnly;

  /// The name [image] is kept under, written now if it's new; null when it
  /// can't be kept.
  String? keepImage(ImageData image);

  /// The image kept as [name], if it's there.
  ImageData? image(String name);
}

/// Each chat's draft kept across a crash or restart: saved [delay] after
/// it stops changing, at once when it empties (sent or cleared) and on
/// [flush] (the app going to the background or quitting); put back when
/// the chat is [attach]ed, and dropped with the chat ([forget]).
final class Drafts {
  new(this.store, {this.delay = const Duration(milliseconds: 500)}) {
    unawaited(_load());
  }

  final DraftStore store;
  final Duration delay;

  /// What's kept, by chat id: the last save's, or loaded and not yet put
  /// back.
  final _kept = <String, Map<String, Object?>>{};
  final _attached = <String, (ChatState, void Function())>{};
  final _dirty = <String>{};
  final _touched = <String>{}; // written to or forgotten before the load
  bool _loaded = false;
  bool _stale = false; // what's on disk has a draft gone since
  bool _restoring = false;
  Timer? _timer;

  /// The saves, one after another, the first after the load (so it can't
  /// write over drafts not loaded yet).
  late Future<void> _saving = loaded;

  /// Done once what was kept is loaded (and put back in chats attached
  /// meanwhile).
  Future<void> get loaded => _loadDone.future;
  final _loadDone = Completer<void>();

  Future<void> _load() async {
    try {
      final kept = await store.load();
      // A chat written to or forgotten meanwhile wins.
      for (final MapEntry(:key, :value) in kept.entries) {
        if (_touched.contains(key)) {
          _stale = true; // its kept draft is out of date
        } else {
          _kept[key] = value;
        }
      }
    } on Object {
      // Nothing kept, or it can't be read: drafts start empty.
    }
    _loaded = true;
    for (final (chat, _) in _attached.values) {
      _restore(chat);
    }
    _loadDone.complete();
  }

  /// The chats with a draft kept.
  Iterable<String> get ids => _kept.keys;

  /// Follows [chat]'s draft, after putting back what was kept for it.
  void attach(ChatState chat) {
    final was = _attached[chat.id];
    if (identical(was?.$1, chat)) return;
    // The same chat on a new link (the phone paired again): this one now.
    if (was case (final old, final changed)?) {
      old.draft.removeListener(changed);
    }
    void changed() => _changed(chat);
    _attached[chat.id] = (chat, changed);
    chat.draft.addListener(changed);
    if (_loaded) _restore(chat);
  }

  void _restore(ChatState chat) {
    final kept = _kept[chat.id];
    // Something written already (before the load) isn't overwritten.
    if (kept == null || !chat.draft.isEmpty) return;
    _restoring = true;
    try {
      chat.draft.restore(kept, image: store.image);
    } finally {
      _restoring = false;
    }
  }

  void _changed(ChatState chat) {
    if (_restoring) return;
    _dirty.add(chat.id);
    if (!_loaded) _touched.add(chat.id);
    _timer?.cancel();
    // Sent or cleared: off the disk now, not after a crash.
    if (chat.draft.isEmpty && _kept.containsKey(chat.id)) {
      unawaited(flush());
    } else {
      _timer = Timer(delay, () => unawaited(flush()));
    }
  }

  /// Stops following chat [id] and drops its draft (deleted or archived).
  void forget(String id) {
    if (_attached.remove(id) case (final chat, final changed)?) {
      chat.draft.removeListener(changed);
    }
    _dirty.remove(id);
    if (_kept.remove(id) != null) {
      _stale = true;
      unawaited(flush());
    } else if (!_loaded) {
      _touched.add(id);
      unawaited(flush()); // after the load, should it have one
    }
  }

  /// Saves the drafts changed since the last save, now (once loaded).
  Future<void> flush() {
    _timer?.cancel();
    return _saving = _saving.then((_) async {
      var changed = _stale;
      _stale = false;
      for (final id in _dirty) {
        final draft = _attached[id]?.$1.draft;
        final j = draft == null || draft.isEmpty
            ? null
            : draft.toJson(image: store.keepImage, textOnly: store.textOnly);
        if (j == null || j.isEmpty) {
          changed |= _kept.remove(id) != null;
        } else {
          _kept[id] = j;
          changed = true;
        }
      }
      _dirty.clear();
      if (!changed) return; // an empty draft isn't written
      try {
        await store.save({..._kept});
      } on Object {
        _stale = true; // kept in memory; the next save tries again
      }
    });
  }
}
