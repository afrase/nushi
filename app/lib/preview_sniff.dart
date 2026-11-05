import 'dart:convert';

/// How much of a file [isText] looks at.
const _sniffed = 8192;

/// Extensions of files that are surely not text, whatever they hold:
/// archives and disk images, executables, libraries and object files,
/// fonts, audio and video, databases, office documents, and the images a
/// preview doesn't draw. The Files pane dims these and ⌘P leaves them
/// out; any other file opens, and the preview reads its bytes to tell
/// ([isText]).
const _binary = {
  // Archives and disk images.
  'zip', 'tar', 'gz', 'tgz', 'bz2', 'xz', 'zst', 'lz4', '7z', 'rar', //
  'dmg', 'pkg', 'iso', 'jar', 'war', 'whl', 'deb', 'rpm', 'apk', 'ipa', //
  'xip', 'aar', //
  // Executables, libraries and object files.
  'exe', 'dll', 'so', 'dylib', 'a', 'lib', 'o', 'obj', 'ko', 'class', //
  'pyc', 'pyo', 'wasm', 'node', 'bin', 'msi', //
  // Fonts.
  'ttf', 'otf', 'ttc', 'woff', 'woff2', 'eot', //
  // Audio and video.
  'mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg', 'opus', 'aif', 'aiff', //
  'caf', 'mp4', 'm4v', 'mov', 'avi', 'mkv', 'webm', 'wmv', 'flv', //
  // Databases.
  'db', 'sqlite', 'sqlite3', 'mdb', 'realm', //
  // Office documents (not `.key`: a PEM key is text too), and images a
  // preview doesn't draw.
  'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'pages', 'numbers', //
  'ico', 'icns', 'bmp', 'tif', 'tiff', 'heic', 'psd', //
};

/// Files named so that are surely not text.
const _binaryNames = {'.DS_Store'};

/// Whether a file named [name] (its last part) is surely not text, by its
/// name alone.
bool surelyBinary(String name) {
  if (_binaryNames.contains(name)) return true;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return false; // no extension, or a dotfile's name
  final ext = name.substring(dot + 1);
  return _binary.contains(ext.toLowerCase());
}

/// Whether [data] reads as text: its first 8 KB hold no NUL and are valid
/// UTF-8 (plain ASCII is), a character cut at the 8 KB's end aside.
bool isText(List<int> data) {
  final n = data.length < _sniffed ? data.length : _sniffed;
  for (var i = 0; i < n; i++) {
    if (data[i] == 0) return false;
  }
  // A character's bytes cut at the end: up to three of them dropped.
  final cut = data.length > n ? 3 : 0;
  for (var drop = 0; drop <= cut; drop++) {
    try {
      utf8.decode(data.sublist(0, n - drop));
      return true;
    } on FormatException {
      continue;
    }
  }
  return false;
}
