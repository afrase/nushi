import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:nushi/drafts.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show ImageData;

/// The Mac's drafts: `drafts.json` in [dir] (the data folder), written
/// whole or not at all, and each draft's images as files in `drafts/`
/// beside it, removed once no draft has them; all only the user's (0600,
/// the folder 0700).
final class DraftFiles implements DraftStore {
  new(this.dir);

  final String dir;

  File get _json => File('$dir/drafts.json');
  Directory get _images => Directory('$dir/drafts');

  /// The name each image is kept under.
  final _names = Expando<String>();
  int _made = 0;

  @override
  bool get textOnly => false;

  @override
  Future<Map<String, Map<String, Object?>>> load() async {
    if (!_json.existsSync()) return {};
    final j = jsonDecode(_json.readAsStringSync()) as Map<String, Object?>;
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
      final tmp = File('${_json.path}.tmp')
        ..writeAsStringSync(jsonEncode(drafts), flush: true);
      _private(tmp.path, 0x180); // 0600
      tmp.renameSync(_json.path);
    }
    // The images no draft has any more (sent, removed, or the chat gone).
    if (!_images.existsSync()) return;
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
      if (!_images.existsSync()) {
        _images.createSync();
        _private(_images.path, 0x1c0); // 0700
      }
      final ext = image.mimeType.split('/').last;
      final name = '${DateTime.now().microsecondsSinceEpoch}-${_made++}.$ext';
      final f = File('${_images.path}/$name.tmp')
        ..writeAsBytesSync(image.data, flush: true);
      _private(f.path, 0x180);
      f.renameSync('${_images.path}/$name');
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

/// libc's chmod (Dart's files have none).
@Native<Int32 Function(Pointer<Uint8>, Uint16)>(symbol: 'chmod', isLeaf: true)
external int _chmod(Pointer<Uint8> path, int mode);

/// Sets [path]'s permissions to [mode].
void _private(String path, int mode) {
  final c = Uint8List.fromList([...utf8.encode(path), 0]);
  if (_chmod(c.address, mode) != 0) {
    throw FileSystemException("can't make it private", path);
  }
}
