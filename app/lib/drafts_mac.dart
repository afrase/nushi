import 'dart:convert';
import 'dart:io';

import 'package:nushi/drafts.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ImageData;

/// The Mac's drafts: `drafts.json` in [dir] (the data folder), written
/// whole or not at all, and each draft's images as files in `drafts/`
/// beside it, removed once no draft has them; all only the user's (0600,
/// the folder 0700). A `drafts.json` that doesn't parse is set aside
/// ([readKept]), and while one set aside is beside it no image older than
/// it is removed, since nothing reads which it names; one made since
/// (its name starts with when) can't be among them, and goes as before.
final class DraftFiles implements DraftStore {
  new(this.dir);

  final String dir;

  File get _json => File('$dir/drafts.json');
  Directory get _images => Directory('$dir/drafts');

  /// The name each image is kept under.
  final _names = Expando<String>();
  int _made = 0;

  /// When the newest `drafts.json` set aside beside it was last written,
  /// in microseconds, as the load saw; null when there's none. No image
  /// made before then is removed.
  int? _heldUntil;

  @override
  bool get textOnly => false;

  @override
  Future<Map<String, Map<String, Object?>>> load() async {
    final j = readKept(_json).json;
    _heldUntil = null;
    for (final f in Directory(dir).listSync().whereType<File>()) {
      if (!f.uri.pathSegments.last.startsWith('drafts.json.unreadable-')) {
        continue;
      }
      final at = f.lastModifiedSync().microsecondsSinceEpoch;
      if (_heldUntil == null || at > _heldUntil!) _heldUntil = at;
    }
    return {
      for (final MapEntry(:key, :value) in j.entries)
        if (value is Map<String, Object?>) key: value,
    };
  }

  @override
  Future<void> save(Map<String, Map<String, Object?>> drafts) async {
    if (drafts.isEmpty) {
      if (_json.existsSync()) _json.deleteSync();
    } else {
      writeWhole(_json, utf8.encode(jsonEncode(drafts)));
    }
    // The images no draft has any more (sent, removed, or the chat gone).
    if (!_images.existsSync()) return;
    final kept = {
      for (final d in drafts.values)
        if (d['images'] case final List<Object?> names)
          ...names.whereType<String>(),
    };
    for (final f in _images.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!kept.contains(name) && !_held(name)) f.deleteSync();
    }
    if (_images.listSync().isEmpty) _images.deleteSync();
  }

  @override
  String? keepImage(ImageData image) {
    // Its file is checked: a save may have swept it meanwhile (the draft
    // emptied by a send that then failed, and put back).
    if (_names[image] case final name?
        when File('${_images.path}/$name').existsSync()) {
      return name;
    }
    try {
      privateDir(_images);
      final ext = image.mimeType.split('/').last;
      final name = '${DateTime.now().microsecondsSinceEpoch}-${_made++}.$ext';
      writeWhole(File('${_images.path}/$name'), image.data);
      return _names[image] = name;
    } on Object {
      return null; // the draft goes without it
    }
  }

  /// Whether the image file [name] is kept for a set-aside `drafts.json`
  /// ([_heldUntil]): made before it was, or of a name [keepImage] doesn't
  /// make, so when is unknown.
  bool _held(String name) {
    final until = _heldUntil;
    if (until == null) return false;
    if (!_name.hasMatch(name)) return true;
    return int.parse(name.substring(0, name.indexOf('-'))) <= until;
  }

  /// A name [keepImage] makes: never a path out of the folder.
  static final _name = RegExp(r'^[0-9]+-[0-9]+\.[a-z]+$');

  @override
  ImageData? image(String name) {
    if (!_name.hasMatch(name)) return null;
    try {
      final f = File('${_images.path}/$name');
      final image = ImageData(
        mimeType: 'image/${name.split('.').last}',
        data: f.readAsBytesSync(),
      );
      _names[image] = name;
      return image;
    } on Object {
      return null;
    }
  }
}
