#include <gtk/gtk.h>
#include <string.h>

#include "channels.h"

// nushi/clipboard: what Ctrl+V attaches beside the clipboard's text (ADR
// 0091), the Mac's Clipboard.swift on GTK's clipboard. "files" answers the
// copied files' paths, "image" the clipboard's picture as PNG bytes when
// it holds one and no text, else null. Each asks the clipboard's owner
// and answers when it replies, never blocking the window on an owner
// that's slow to.

// Answers [call] with [response], or says why it couldn't.
static void clipboard_respond(FlMethodCall* call, FlMethodResponse* response) {
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(call, response, &error)) {
    g_warning("nushi/clipboard: %s", error->message);
  }
}

// Answers the call [user_data] (a reference, given up here) with [result].
static void clipboard_answer(gpointer user_data, FlValue* result) {
  g_autoptr(FlMethodCall) call = FL_METHOD_CALL(user_data);
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  clipboard_respond(call, response);
}

// The copied files (a file manager's copy): only the URIs that name a file
// of this machine's. A web link, or a file:// URI of another host, is none,
// and neither is a name that isn't UTF-8, which the channel can't carry.
static void files_received(GtkClipboard* clipboard, gchar** uris,
                           gpointer user_data) {
  g_autoptr(FlValue) paths = fl_value_new_list();
  for (gchar** uri = uris; uri != nullptr && *uri != nullptr; uri++) {
    g_autofree gchar* host = nullptr;
    g_autofree gchar* path = g_filename_from_uri(*uri, &host, nullptr);
    if (path != nullptr &&
        (host == nullptr || g_strcmp0(host, "localhost") == 0) &&
        g_utf8_validate(path, -1, nullptr)) {
      fl_value_append_take(paths, fl_value_new_string(path));
    }
  }
  clipboard_answer(user_data, paths);
}

// The clipboard's PNG as its owner gave it: no decoding and encoding again
// on the window's thread, and no loss. Bytes that don't start as a PNG
// does are none.
static void png_received(GtkClipboard* clipboard, GtkSelectionData* data,
                         gpointer user_data) {
  static const guchar signature[] = {0x89, 'P',  'N',  'G',
                                     '\r', '\n', 0x1a, '\n'};
  gint length = 0;
  const guchar* bytes = gtk_selection_data_get_data_with_length(data, &length);
  g_autoptr(FlValue) result =
      bytes != nullptr && length > static_cast<gint>(sizeof signature) &&
              memcmp(bytes, signature, sizeof signature) == 0
          ? fl_value_new_uint8_list(bytes, length)
          : fl_value_new_null();
  clipboard_answer(user_data, result);
}

// The clipboard's picture of another kind (JPEG, GIF or BMP, which
// gtk_clipboard_request_image asks for in turn), as PNG.
static void image_received(GtkClipboard* clipboard, GdkPixbuf* pixbuf,
                           gpointer user_data) {
  g_autoptr(FlValue) result = nullptr;
  g_autofree gchar* png = nullptr;
  gsize size = 0;
  g_autoptr(GError) error = nullptr;
  if (pixbuf != nullptr &&
      gdk_pixbuf_save_to_buffer(pixbuf, &png, &size, "png", &error, nullptr)) {
    result = fl_value_new_uint8_list(reinterpret_cast<uint8_t*>(png), size);
  } else {
    if (error != nullptr) {
      g_warning("nushi/clipboard: %s", error->message);
    }
    result = fl_value_new_null();
  }
  clipboard_answer(user_data, result);
}

// What the clipboard holds decides whether its picture is read: none when
// it holds text too, since then what was copied is text and the picture
// beside it that text drawn (a spreadsheet's cells), which Ctrl+V pastes
// as text.
static void targets_received(GtkClipboard* clipboard, GdkAtom* targets,
                             gint n_targets, gpointer user_data) {
  if (targets != nullptr && !gtk_targets_include_text(targets, n_targets)) {
    GdkAtom png = gdk_atom_intern_static_string("image/png");
    for (gint i = 0; i < n_targets; i++) {
      if (targets[i] == png) {
        gtk_clipboard_request_contents(clipboard, png, png_received, user_data);
        return;
      }
    }
    if (gtk_targets_include_image(targets, n_targets, FALSE)) {
      gtk_clipboard_request_image(clipboard, image_received, user_data);
      return;
    }
  }
  g_autoptr(FlValue) none = fl_value_new_null();
  clipboard_answer(user_data, none);
}

static void clipboard_call(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer user_data) {
  const gchar* method = fl_method_call_get_name(call);
  GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  if (g_strcmp0(method, "files") == 0) {
    gtk_clipboard_request_uris(clipboard, files_received, g_object_ref(call));
  } else if (g_strcmp0(method, "image") == 0) {
    gtk_clipboard_request_targets(clipboard, targets_received,
                                  g_object_ref(call));
  } else {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    clipboard_respond(call, response);
  }
}

void clipboard_register(FlView* view) {
  channel_register(view, "nushi/clipboard", clipboard_call);
}
