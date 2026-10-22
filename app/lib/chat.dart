import 'package:flutter/foundation.dart';

import 'gen/nushi/v1/nushi.pb.dart';

/// One chat's transcript and status, kept current from daemon events.
class Chat extends ChangeNotifier {
  Chat(this.id, this.folder, this.config);

  final String id;
  final String folder;
  final List<Item> items = [];
  List<ConfigOption> config;
  bool busy = false;
  String error = '';

  void apply(EventsResponse e) {
    switch (e.whichKind()) {
      case EventsResponse_Kind.item:
        _applyItem(e.item);
      case EventsResponse_Kind.config:
        config = e.config.options;
      case EventsResponse_Kind.status:
        busy = e.status.busy;
        error = e.status.error;
      case EventsResponse_Kind.notSet:
        return;
    }
    notifyListeners();
  }

  void _applyItem(ItemEvent e) {
    final i = items.indexWhere((it) => it.id == e.item.id);
    if (i < 0) {
      items.add(e.item);
    } else if (e.append) {
      items[i] = items[i].deepCopy()..text = items[i].text + e.item.text;
    } else {
      items[i] = e.item;
    }
  }
}
