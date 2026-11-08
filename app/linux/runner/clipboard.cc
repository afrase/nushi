#include "channels.h"

// nushi/clipboard: what Ctrl+V attaches beside the clipboard's text (ADR
// 0091), the Mac's Clipboard.swift on GTK's clipboard. "files" answers the
// copied files' paths (file:// URIs only, never a web link), "image" the
// clipboard's picture as PNG bytes when it holds one and no text, else null.
// Not built yet: every call answers not implemented, which the Dart side
// takes as nothing to attach.
static void clipboard_call(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer user_data) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_not_implemented(call, &error)) {
    g_warning("nushi/clipboard: %s", error->message);
  }
}

void clipboard_register(FlView* view) {
  channel_register(view, "nushi/clipboard", clipboard_call);
}
