import 'dart:async';

import 'package:nushi/agents.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// What [folder] would have the agent run, shown before a chat starts or
/// moves there; [answer] is true for "Start anyway".
class TrustAsk {
  new(this.folder, this.action, this.runs, this.agent);

  final String folder;
  final String action;
  final List<FolderRun> runs;
  final String agent; // the agent that runs them (Agent.name)
  final answer = Completer<bool>();

  void decide({required bool start}) {
    if (!answer.isCompleted) answer.complete(start);
  }

  /// What didn't happen, said when the user leaves the card unanswered:
  /// "Didn't start Claude in site: its code wasn't approved."
  String get left {
    final where = folder.substring(folder.lastIndexOf('/') + 1);
    final what = switch (action) {
      'Move the chat' => "Didn't move the chat to $where",
      'Open the session' => "Didn't open the session in $where",
      _ => "Didn't start ${agentTitle(agent)} in $where",
    };
    return "$what: its code wasn't approved.";
  }
}
