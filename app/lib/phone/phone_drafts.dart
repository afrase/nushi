import 'dart:convert';

import 'package:nushi/drafts.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ImageData;
import 'package:nushi/phone/platform.dart';

/// The phone's drafts: one JSON record in the browser's IndexedDB, beside
/// the pairing. Only the boxes' text and the reply cards: no images.
final class PhoneDrafts implements DraftStore {
  new(this.platform);

  final PhonePlatform platform;

  @override
  bool get textOnly => true;

  @override
  Future<Map<String, Map<String, Object?>>> load() async {
    final json = await platform.loadDrafts();
    if (json == null) return {};
    return {
      for (final MapEntry(:key, :value)
          in (jsonDecode(json) as Map<String, Object?>).entries)
        if (value is Map<String, Object?>) key: value,
    };
  }

  @override
  Future<void> save(Map<String, Map<String, Object?>> drafts) =>
      platform.saveDrafts(drafts.isEmpty ? null : jsonEncode(drafts));

  @override
  String? keepImage(ImageData image) => null;

  @override
  ImageData? image(String name) => null;
}
