import 'dart:io' show Directory, File;

/// No files on the web: never called there.
void setMode(String path, int mode) =>
    throw UnsupportedError('no files on the web');

/// No files on the web: never called there.
void writeWhole(File file, List<int> bytes, {int mode = 0x180}) =>
    throw UnsupportedError('no files on the web');

/// No files on the web: never called there.
void privateDir(Directory dir) => throw UnsupportedError('no files on the web');
