import 'dart:js_interop';

import 'package:file_selector/file_selector.dart';
import 'package:web/web.dart' as web;

/// Calls [f] with the files a paste into the page carries (a copied photo,
/// a file from Files), each as the file picker gives one; its text pastes
/// as usual. Heard as the event goes down, before Flutter's text field.
void watchPastes(void Function(List<XFile> files) f) =>
    web.document.addEventListener(
      'paste',
      ((web.ClipboardEvent e) {
        final files = e.clipboardData?.files;
        if (files == null || files.length == 0) return;
        f([
          for (var i = 0; i < files.length; i++)
            if (files.item(i) case final file?)
              XFile(
                web.URL.createObjectURL(file),
                name: file.name,
                length: file.size,
                mimeType: file.type,
              ),
        ]);
      }).toJS,
      true.toJS,
    );
