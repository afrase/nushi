#include <gio/gio.h>
#include <gtk/gtk.h>

#include <cstring>

#include "channels.h"

// nushi/browser: "open" (a url) opens an http, https or file address with
// the app that opens https, so a file is never run by the app its type has
// (ADR 0068, 0094), "browserName" answers that app's name or null, and
// "openMail" (a url) opens a mailto: address with the default app for
// mailto:.
// nushi/desktop: "openAsText" (an absolute path) opens a file with the
// default app for plain text, whatever its type, and "openFolder" (an
// absolute path) a folder with the default app for folders. All go through
// GIO's default apps, never xdg-open, whose script may be missing and, in a
// VM, may open it on another machine (ADR 0104). A call that opens nothing
// answers an error: "refused" (not an address or a path), "no-browser",
// "no-mail-app", "no-editor" or "no-file-manager" (no default app for
// it), "failed" (the app didn't start), as the Mac's "refused" and
// "failed".

// Answers [call] with [response], or says why it couldn't.
static void gio_respond(FlMethodCall* call, FlMethodResponse* response) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(call, response, &error)) {
    g_warning("%s: %s", fl_method_call_get_name(call), error->message);
  }
}

// Answers [call] with an error of [code], saying [message].
static void gio_refuse(FlMethodCall* call, const gchar* code,
                       const gchar* message) {
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_error_response_new(code, message, nullptr));
  gio_respond(call, response);
}

// Answers [call] with [result].
static void gio_answer(FlMethodCall* call, FlValue* result) {
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  gio_respond(call, response);
}

// The string [call] carries, or null.
static const gchar* gio_string_arg(FlMethodCall* call) {
  FlValue* args = fl_method_call_get_args(call);
  return args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_STRING
             ? fl_value_get_string(args)
             : nullptr;
}

// The default browser: the app that opens https, or null when none is set.
static GAppInfo* gio_browser() {
  return g_app_info_get_default_for_uri_scheme("https");
}

// A launch ended: answers the call [user_data] (a reference, given up here)
// with nothing, or the launch's error.
static void gio_launched(GObject* source, GAsyncResult* result,
                         gpointer user_data) {
  g_autoptr(FlMethodCall) call = FL_METHOD_CALL(user_data);
  g_autoptr(GError) error = nullptr;
  if (!g_app_info_launch_uris_finish(G_APP_INFO(source), result, &error)) {
    gio_refuse(call, "failed", error->message);
    return;
  }
  g_autoptr(FlValue) none = fl_value_new_null();
  gio_answer(call, none);
}

// Whether [pair], an environment's NAME=value, is one of Nushi's own
// variables (NUSHI_*, NUSHID_*).
static gboolean gio_nushi_variable(const gchar* pair) {
  return g_str_has_prefix(pair, "NUSHI_") || g_str_has_prefix(pair, "NUSHID_");
}

// Opens [uri] with [app], answering [call] once it has started. The
// display's launch context gives the app the display and a startup id, so
// the desktop brings its window to the front, and the app's environment,
// without Nushi's own variables: an app started on the Mac gets none of
// them either, and a terminal it opens later must not take a development
// run's data folder (security.md).
static void gio_launch(GAppInfo* app, const gchar* uri, FlMethodCall* call) {
  g_autoptr(GdkAppLaunchContext) context =
      gdk_display_get_app_launch_context(gdk_display_get_default());
  g_auto(GStrv) environment = g_get_environ();
  for (gchar** pair = environment; *pair != nullptr; pair++) {
    if (gio_nushi_variable(*pair)) {
      g_autofree gchar* name = g_strndup(*pair, strcspn(*pair, "="));
      g_app_launch_context_unsetenv(G_APP_LAUNCH_CONTEXT(context), name);
    }
  }
  GList uris = {const_cast<gchar*>(uri), nullptr, nullptr};
  g_app_info_launch_uris_async(app, &uris, G_APP_LAUNCH_CONTEXT(context),
                               nullptr, gio_launched, g_object_ref(call));
}

// Whether [url] is a whole address of a scheme the browser may open: the
// Mac's rule (web_views.dart).
static gboolean gio_browsable(const gchar* url) {
  if (url == nullptr || !g_uri_is_valid(url, G_URI_FLAGS_NONE, nullptr)) {
    return FALSE;
  }
  const gchar* scheme = g_uri_peek_scheme(url);
  return g_strcmp0(scheme, "http") == 0 || g_strcmp0(scheme, "https") == 0 ||
         g_strcmp0(scheme, "file") == 0;
}

static void browser_open(FlMethodCall* call) {
  const gchar* url = gio_string_arg(call);
  if (!gio_browsable(url)) {
    gio_refuse(call, "refused", "Not an address to open");
    return;
  }
  g_autoptr(GAppInfo) browser = gio_browser();
  if (browser == nullptr) {
    gio_refuse(call, "no-browser", "No default browser is set");
    return;
  }
  gio_launch(browser, url, call);
}

static void browser_open_mail(FlMethodCall* call) {
  const gchar* url = gio_string_arg(call);
  if (url == nullptr || !g_uri_is_valid(url, G_URI_FLAGS_NONE, nullptr) ||
      g_strcmp0(g_uri_peek_scheme(url), "mailto") != 0) {
    gio_refuse(call, "refused", "Not a mail address to open");
    return;
  }
  g_autoptr(GAppInfo) mail = g_app_info_get_default_for_uri_scheme("mailto");
  if (mail == nullptr) {
    gio_refuse(call, "no-mail-app", "No default mail app is set");
    return;
  }
  gio_launch(mail, url, call);
}

static void browser_name(FlMethodCall* call) {
  g_autoptr(GAppInfo) browser = gio_browser();
  g_autoptr(FlValue) name =
      browser != nullptr
          ? fl_value_new_string(g_app_info_get_display_name(browser))
          : fl_value_new_null();
  gio_answer(call, name);
}

// Opens the absolute path [call] carries with the default app for
// [content_type], whatever the path is; [missing] is the error's code when
// there's no such app, [message] its words.
static void desktop_open_with(FlMethodCall* call, const gchar* content_type,
                              const gchar* missing, const gchar* message) {
  const gchar* path = gio_string_arg(call);
  g_autofree gchar* uri = path != nullptr && g_path_is_absolute(path)
                              ? g_filename_to_uri(path, nullptr, nullptr)
                              : nullptr;
  if (uri == nullptr) {
    gio_refuse(call, "refused", "Not a file to open");
    return;
  }
  g_autoptr(GAppInfo) app =
      g_app_info_get_default_for_type(content_type, FALSE);
  if (app == nullptr) {
    gio_refuse(call, missing, message);
    return;
  }
  gio_launch(app, uri, call);
}

static void gio_call(FlMethodChannel* channel, FlMethodCall* call,
                     gpointer user_data) {
  const gchar* name = static_cast<const gchar*>(user_data);
  const gchar* method = fl_method_call_get_name(call);
  if (g_strcmp0(name, "nushi/browser") == 0 && g_strcmp0(method, "open") == 0) {
    browser_open(call);
  } else if (g_strcmp0(name, "nushi/browser") == 0 &&
             g_strcmp0(method, "browserName") == 0) {
    browser_name(call);
  } else if (g_strcmp0(name, "nushi/browser") == 0 &&
             g_strcmp0(method, "openMail") == 0) {
    browser_open_mail(call);
  } else if (g_strcmp0(name, "nushi/desktop") == 0 &&
             g_strcmp0(method, "openAsText") == 0) {
    desktop_open_with(call, "text/plain", "no-editor",
                      "No default app for text is set");
  } else if (g_strcmp0(name, "nushi/desktop") == 0 &&
             g_strcmp0(method, "openFolder") == 0) {
    desktop_open_with(call, "inode/directory", "no-file-manager",
                      "No default app for folders is set");
  } else {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    gio_respond(call, response);
  }
}

void gio_register(FlView* view) {
  channel_register(view, "nushi/browser", gio_call);
  channel_register(view, "nushi/desktop", gio_call);
}
