import 'dart:math';

import 'package:flutter/foundation.dart' show immutable;

/// The part of a tile's own animated image it plays (ADR 0112): its frames
/// from [start] up to [end], not [end] itself, counted from 0. At rest a
/// trimmed tile shows frame [start]; under the pointer it plays to [end]
/// and loops back to [start]. Kept beside the image's name in
/// `projectTiles`, never by changing the file, so trimming it again starts
/// from the whole picture. Null for a tile is every frame.
///
/// Frames rather than times: a frame is what's decoded and shown, a
/// number that means the same frame whatever the decoder makes of a
/// file's durations (a GIF that says none plays each for a tenth of a
/// second), and there's nothing to round.
@immutable
class TileTrim {
  const new(this.start, this.end);

  /// [saved] as `app.json` has it; null when it isn't one.
  static TileTrim? read(Object? saved) {
    if (saved is! Map) return null;
    final (start, end) = (saved['start'], saved['end']);
    if (start is! int || end is! int) return null;
    if (start < 0 || end - start < minFrames) return null;
    return TileTrim(start, end);
  }

  /// The fewest frames kept: the handles can't meet, and a tile that
  /// plays shows more than one picture.
  static const minFrames = 2;

  final int start;
  final int end;

  /// It in an image of [count] frames: [end] no further than the last;
  /// null when that keeps every frame, or fewer than [minFrames] (one not
  /// of this image: a hand-edited one): it plays whole.
  TileTrim? of(int count) {
    final last = min(end, count);
    if (last - start < minFrames) return null;
    if (start == 0 && last == count) return null;
    return TileTrim(start, last);
  }

  /// As `app.json` keeps it.
  Map<String, Object> toJson() => {'start': start, 'end': end};

  @override
  bool operator ==(Object other) =>
      other is TileTrim && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TileTrim($start, $end)';
}

/// [time] as the trimmer writes it: minutes, seconds and tenths, "0:05.2".
String trimClock(Duration time) {
  final tenths = (time.inMilliseconds / 100).round();
  final seconds = (tenths % 600) ~/ 10;
  return '${tenths ~/ 600}:${seconds.toString().padLeft(2, '0')}'
      '.${tenths % 10}';
}
