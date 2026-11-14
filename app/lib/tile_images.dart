import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/tile_crop.dart';
import 'package:nushi/tile_look.dart';

// A project's tile's own image (ADR 0112): a file the user picked, checked
// and copied into Nushi's data folder. A tile names its copy, never a
// path into the user's folders, so nothing of theirs is read again once
// it's picked, and nothing but Nushi's copy is ever deleted.

/// The largest file taken as a tile's image: a large photo or a long GIF
/// fits; it's only ever kept at a tile's size.
const int maxTileImageBytes = 16 << 20;

/// The most pixels a frame of an animated image taken for a tile has: 4K's.
/// The engine decodes an animated image's frames whole, each then drawn
/// again at the tile's size ([tileFrame]), so one whole frame is in memory
/// while it's decoded; a flat GIF of 16 MB could be 10000 square, 400 MB a
/// frame. A still has no such limit: it's decoded at the tile's size.
const int maxAnimatedPixels = 3840 * 2160;

/// Picks the image Choose image… takes. A test puts its own in its place:
/// the system's panel can't be shown in one.
Future<XFile?> Function() pickTileImage = () => openFile(
  acceptedTypeGroups: const [
    XTypeGroup(
      label: 'Images',
      extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      uniformTypeIdentifiers: ['public.image'],
    ),
  ],
  confirmButtonText: 'Choose',
);

/// The kind of image [bytes] start as, by its stored name's ending: PNG,
/// JPEG, GIF or WebP, from the bytes and never a file's name; null for
/// anything else.
String? tileImageKind(List<int> bytes) {
  bool starts(List<int> magic, [int at = 0]) {
    if (bytes.length < at + magic.length) return false;
    for (final (i, b) in magic.indexed) {
      if (bytes[at + i] != b) return false;
    }
    return true;
  }

  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'png';
  }
  if (starts(const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (starts('GIF87a'.codeUnits) || starts('GIF89a'.codeUnits)) return 'gif';
  if (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8)) return 'webp';
  return null;
}

/// An image picked for a tile and found good: its bytes and their kind.
typedef PickedImage = ({Uint8List bytes, String kind});

/// Why a file picked can't be a tile's image, in the dialog's words.
class TileImageRefused implements Exception {
  const new(this.why);

  final String why;

  @override
  String toString() => why;
}

/// Reads the file at [path] as a tile's image, or says why it can't be
/// one ([TileImageRefused]): only a regular file, [maxTileImageBytes] at
/// most (asked before it's read), one of the four kinds by its first
/// bytes, an animated one of [maxAnimatedPixels] at most by its header, and
/// one the engine decodes (its first frame, at a tile's size).
Future<PickedImage> readTileImage(String path) async {
  final file = File(path);
  final FileStat stat;
  try {
    stat = file.statSync();
  } on FileSystemException {
    throw const TileImageRefused('That file can’t be read.');
  }
  if (stat.type != FileSystemEntityType.file) {
    throw const TileImageRefused('That file can’t be read.');
  }
  if (stat.size > maxTileImageBytes) {
    throw const TileImageRefused('That image is larger than 16 MB.');
  }
  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } on FileSystemException {
    throw const TileImageRefused('That file can’t be read.');
  }
  // It may have grown since it was asked.
  if (bytes.length > maxTileImageBytes) {
    throw const TileImageRefused('That image is larger than 16 MB.');
  }
  final kind = tileImageKind(bytes);
  if (kind == null) {
    throw const TileImageRefused('Not a PNG, JPEG, GIF or WebP image.');
  }
  final ui.Codec codec;
  final int pixels;
  try {
    codec = await tileImageCodec(bytes, 64);
    pixels = await _pixels(bytes);
  } on Object {
    throw const TileImageRefused('That image can’t be shown.');
  }
  try {
    // Asked before a frame is decoded: an animated one's comes whole.
    if (codec.frameCount > 1 && pixels > maxAnimatedPixels) {
      throw const TileImageRefused(
        'That animated image has more pixels than 4K (3840 × 2160).',
      );
    }
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } on TileImageRefused {
    rethrow;
  } on Object {
    throw const TileImageRefused('That image can’t be shown.');
  } finally {
    codec.dispose();
  }
  return (bytes: bytes, kind: kind);
}

/// The pixels of [bytes]' image, from its header: nothing is decoded.
Future<int> _pixels(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final image = await ui.ImageDescriptor.encoded(buffer);
    final pixels = image.width * image.height;
    image.dispose();
    return pixels;
  } finally {
    buffer.dispose();
  }
}

/// A codec for [bytes] that decodes at a tile's size, never the image's
/// own: scaled so its shorter side is [side] pixels (the tile's, in the
/// screen's pixels), the longer one cropped away as it's drawn; with a
/// [crop], so the square it frames is [side] pixels, then cut out by
/// [tileFrame]. A smaller image is left as it is. Only a still's: the
/// engine decodes each frame of an animated one whole, so each goes
/// through [tileFrame].
Future<ui.Codec> tileImageCodec(
  Uint8List bytes,
  int side, {
  TileCrop? crop,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final wanted = side * (crop?.zoom.clamp(1, TileCrop.maxZoom) ?? 1);
  return await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final shorter = min(width, height);
      if (shorter <= wanted) return const ui.TargetImageSize();
      return ui.TargetImageSize(
        width: max(1, (width * wanted / shorter).round()),
        height: max(1, (height * wanted / shorter).round()),
      );
    },
  );
}

/// [frame] scaled as [tileImageCodec] scales a still, its shorter side
/// [side] pixels, and the whole one let go: a frame of an animated image
/// comes whole, and only the tile's size of it is kept. A smaller one is
/// given back as it is. With a [crop], only the square it frames is kept,
/// [side] pixels at most: the rest of the frame is let go too.
Future<ui.Image> tileFrame(ui.Image frame, int side, {TileCrop? crop}) async {
  final ui.Rect source;
  final int width;
  final int height;
  if (crop == null) {
    final shorter = min(frame.width, frame.height);
    if (shorter <= side) return frame;
    source = ui.Rect.fromLTWH(
      0,
      0,
      frame.width.toDouble(),
      frame.height.toDouble(),
    );
    width = max(1, (frame.width * side / shorter).round());
    height = max(1, (frame.height * side / shorter).round());
  } else {
    source = crop.within(frame.width, frame.height);
    width = height = max(1, min(side, source.width.round()));
  }
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    frame,
    source,
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
    frame.dispose();
  }
}

/// How long a frame of an animated image shows: its own [duration], but
/// a file that says none, or next to none, means a tenth of a second, as
/// browsers take it.
Duration frameWait(Duration duration) =>
    duration < _leastFrame ? _tenth : duration;

// design: an animated image's frames, as browsers time them
const _leastFrame = Duration(milliseconds: 20);
// design: an animated image's frames, as browsers time them
const _tenth = Duration(milliseconds: 100);

/// Decodes [count] frames of [codec] and lets each go at once: a GIF
/// decodes only in order, so a trimmed one's first frame is reached this
/// way, never holding more than the frame being decoded.
Future<void> skipFrames(ui.Codec codec, int count) async {
  for (var i = 0; i < count; i++) {
    (await codec.getNextFrame()).image.dispose();
  }
}

/// Where the tiles' images are kept: `tiles` in Nushi's data folder.
Directory get tileImagesDir => Directory('$dataDir/tiles');

/// The stored image called [name], if it's a name Nushi gave one.
File? tileImageFile(String name) =>
    storedTileImage.hasMatch(name) ? File('${tileImagesDir.path}/$name') : null;

/// Keeps a copy of [image] in [tileImagesDir] and gives its name: random,
/// with its kind's ending; the folder and the file only the user's.
String keepTileImage(PickedImage image) {
  final random = Random.secure();
  final id = [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  final name = '$id.${image.kind}';
  privateDir(tileImagesDir);
  writeWhole(File('${tileImagesDir.path}/$name'), image.bytes);
  return name;
}

/// Deletes the stored image called [name], if there is one: replaced,
/// removed, or its project gone.
void dropTileImage(String name) {
  try {
    final file = tileImageFile(name);
    if (file != null && file.existsSync()) file.deleteSync();
  } on FileSystemException {
    // Left behind; nothing names it any more.
  }
}
