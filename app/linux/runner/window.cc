#include <gtk/gtk.h>

#include "channels.h"

// nushi/window: "present" ({token}: an activation token, when a
// notification's click gave one) raises the window. Wayland lets an app
// take the focus only with such a token (xdg-activation), and X11 reads a
// startup id's time from it; without one the desktop may only mark the
// window as wanting attention. The Mac's "arm" and "zoom" have no
// counterpart: the system's title bar moves and zooms the window here
// (ADR 0104).

// Answers [call] with [response], or says why it couldn't.
static void window_respond(FlMethodCall* call, FlMethodResponse* response) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(call, response, &error)) {
    g_warning("nushi/window: %s", error->message);
  }
}

// The token [call]'s map carries, or null.
static const gchar* window_token(FlMethodCall* call) {
  FlValue* args = fl_method_call_get_args(call);
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  FlValue* token = fl_value_lookup_string(args, "token");
  return token != nullptr && fl_value_get_type(token) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(token)
             : nullptr;
}

// Presents the app's one window (my_application.cc never makes a second),
// with the token first when there's one.
static void window_present(FlMethodCall* call) {
  GList* windows =
      gtk_application_get_windows(GTK_APPLICATION(g_application_get_default()));
  if (windows != nullptr) {
    GtkWindow* window = GTK_WINDOW(windows->data);
    const gchar* token = window_token(call);
    if (token != nullptr) {
      gtk_window_set_startup_id(window, token);
    }
    gtk_window_present(window);
  }
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  window_respond(call, response);
}

static void window_call(FlMethodChannel* channel, FlMethodCall* call,
                        gpointer user_data) {
  if (g_strcmp0(fl_method_call_get_name(call), "present") == 0) {
    window_present(call);
    return;
  }
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  window_respond(call, response);
}

void window_register(FlView* view) {
  channel_register(view, "nushi/window", window_call);
}
