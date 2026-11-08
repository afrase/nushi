#include "channels.h"

// nushi/browser: "open" (a url) opens an http, https or file address with
// the app that opens https, so a file is never run by the app its type has
// (ADR 0068, 0094), and "browserName" answers that app's name or null.
// nushi/desktop: "openAsText" (a path) opens a file in the default text
// editor. Both go through GIO's default apps, never xdg-open. Not built
// yet: every call answers not implemented.
static void gio_call(FlMethodChannel* channel, FlMethodCall* call,
                     gpointer user_data) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_not_implemented(call, &error)) {
    g_warning("%s: %s", static_cast<const gchar*>(user_data), error->message);
  }
}

void gio_register(FlView* view) {
  channel_register(view, "nushi/browser", gio_call);
  channel_register(view, "nushi/desktop", gio_call);
}
