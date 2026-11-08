#include "channels.h"

// nushi/window: "present" ({token}: an activation token, when a
// notification's click gave one) raises the window, as Wayland lets an app
// do only with the token. The Mac's "arm" and "zoom" have no counterpart:
// the system's title bar moves and zooms the window here (ADR 0102). Not
// built yet: every call answers not implemented.
static void window_call(FlMethodChannel* channel, FlMethodCall* call,
                        gpointer user_data) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_not_implemented(call, &error)) {
    g_warning("nushi/window: %s", error->message);
  }
}

void window_register(FlView* view) {
  channel_register(view, "nushi/window", window_call);
}
