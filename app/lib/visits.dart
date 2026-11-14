import 'package:flutter/foundation.dart' show immutable;

import 'package:nushi/place.dart';

/// One place visited: a chat, by id, or a view that takes the chat's
/// place (Jira, GitHub).
@immutable
class Visit {
  const new(this.place, {this.chat});

  final Place place;

  /// The chat shown, for a [ChatPlace].
  final String? chat;

  @override
  bool operator ==(Object other) =>
      other is Visit && other.place == place && other.chat == chat;

  @override
  int get hashCode => Object.hash(place, chat);
}

/// The places visited, in order, as a browser's history (ADR 0119): Back
/// and Forward step through them. A new place is noted after the one
/// they're at, those after it dropped; stepping only moves along. It keeps
/// the last [most]. A visit may no longer be live (its chat deleted or
/// archived): a step passes over it, and over one that's the place shown.
class Visits {
  final _list = <Visit>[];
  int _at = -1;

  /// How many visits it keeps.
  static const most = 100;

  /// Notes [now], what shows, unless it's the visit it's at. Null (no chat
  /// open) is no place.
  void see(Visit? now) {
    if (now == null || (_at >= 0 && _list[_at] == now)) return;
    _list
      ..removeRange(_at + 1, _list.length)
      ..add(now);
    if (_list.length > most) _list.removeAt(0);
    _at = _list.length - 1;
  }

  /// Where a step of [step] (-1 back, 1 forward) lands, passing over the
  /// visits that aren't [live] and those that are the place it's at.
  int? _target(int step, bool Function(Visit) live) {
    if (_at < 0) return null;
    final here = _list[_at];
    for (var i = _at + step; i >= 0 && i < _list.length; i += step) {
      if (_list[i] != here && live(_list[i])) return i;
    }
    return null;
  }

  /// Whether a step of [step] has somewhere to go.
  bool can(int step, bool Function(Visit) live) => _target(step, live) != null;

  /// Steps [step] along, and says where to: null when there's nowhere.
  Visit? step(int step, bool Function(Visit) live) {
    final i = _target(step, live);
    if (i == null) return null;
    _at = i;
    return _list[i];
  }
}
