#ifndef RUNNER_CHANNELS_H_
#define RUNNER_CHANNELS_H_

#include <flutter_linux/flutter_linux.h>

// The runner's own platform channels, the Linux side of the app's native
// capabilities (ADR 0097, 0102): each answers on [view]'s engine for as long
// as the view lives. Their names and methods are the Mac's where the Mac has
// the same call (macos/Runner).

// nushi/clipboard (clipboard.cc), lib/clipboard_files_linux.dart.
void clipboard_register(FlView* view);

// nushi/browser and nushi/desktop (gio.cc), lib/web_views_linux.dart and
// lib/desktop_linux.dart.
void gio_register(FlView* view);

// nushi/window (window.cc), lib/window_drag_linux.dart.
void window_register(FlView* view);

// Answers [name]'s calls on [view] with [handler] while the view lives;
// the handler's user data is [name], a string that outlives the view.
void channel_register(FlView* view, const gchar* name,
                      FlMethodChannelMethodCallHandler handler);

#endif  // RUNNER_CHANNELS_H_
