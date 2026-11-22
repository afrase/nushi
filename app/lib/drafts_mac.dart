import 'dart:convert';
import 'dart:io';

import 'package:nushi/drafts.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ImageData;

/// The Mac's drafts: `drafts.json` in [dir] (the data folder), written
/// whole or not at all, and each draft's images as files in `drafts/`
/// beside it, removed once no draft has them; all only the user's (0600,
/// the folder 0700). A `drafts.json` that doesn't parse is set aside
/// ([readKept]), and while one set aside is beside it no image is removed,
/// since nothing reads which it names.
final class DraftFiles implements DraftStore {
  new(this.dir);

  final String dir;

  File get _json => File('$dir/drafts.json');
  Directory get _images => Directory('$dir/drafts');

  /// The name each image is kept under.
  final _names = Expando<String>();
  int _made = 0;

  /// Whether a `drafts.json` set aside is beside it, as the load saw.
  bool _asideThere = false;

  @override
  bool get textOnly => false;

  @override
  Future<Map<String, Map<String, Object?>>> load() async {
    final (json: j, :setAside) = readKept(_json);
    _asideThere =
        setAside ||
        Directory(dir).listSync().any(
          (f) => f.uri.pathSegments.last.startsWith('drafts.json.unreadable-'),
        );
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
    if (_asideThere || !_images.existsSync()) return;
    final kept = {
      for (final d in drafts.values)
        if (d['images'] case final List<Object?> names)
          ...names.whereType<String>(),
    };
    for (final f in _images.listSync().whereType<File>()) {
      if (!kept.contains(f.uri.pathSegments.last)) f.deleteSync();
    }
    if (_images.listSync().isEmpty) _images.deleteSync();
  }

  @override
  String? keepImage(ImageData image) {
    if (_names[image] case final name?) return name;
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
