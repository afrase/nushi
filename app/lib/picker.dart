import 'package:flutter/widgets.dart';

/// The pickers: a box over the window that lists what to go to or open
/// and runs what's picked, asking nothing (docs/design.md's Dialogs). Each
/// is shown as a route of its [settings], which is how the app's keys and
/// menu bar tell one from a dialog that asks something: one picker shows
/// at a time, another's key puts its picker in the open one's place, and
/// its own key closes it.
enum Picker {
  /// ⌘K's command palette.
  palette,

  /// Artifacts…, as a palette where the details panel has no room.
  artifacts,

  /// ⌘P's file opener.
  openFile;

  /// The route settings it's shown with.
  RouteSettings get settings => RouteSettings(name: 'picker', arguments: this);
}

/// The picker [route] shows, or null for any other route.
Picker? pickerOf(Route<Object?>? route) => switch (route?.settings.arguments) {
  final Picker p => p,
  _ => null,
};
