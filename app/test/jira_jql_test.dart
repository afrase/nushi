import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/jira_jql.dart';

void main() {
  test('what the word being typed is', () {
    void expectWord(String before, JqlSlot slot, String field, String prefix) {
      final w = jqlWord(before);
      expect(
        (w.slot, w.field, w.prefix),
        (slot, field, prefix),
        reason: before,
      );
      expect(before.substring(w.start), prefix, reason: before);
    }

    expectWord('', JqlSlot.field, '', '');
    expectWord('pro', JqlSlot.field, '', 'pro');
    expectWord('project ', JqlSlot.operator, 'project', '');
    expectWord('project =', JqlSlot.value, 'project', '');
    expectWord('project = SC', JqlSlot.value, 'project', 'SC');
    expectWord('project = SCRUM ', JqlSlot.keyword, '', '');
    expectWord('project = SCRUM AN', JqlSlot.keyword, '', 'AN');
    expectWord('project = SCRUM AND st', JqlSlot.field, '', 'st');
    expectWord('project = SCRUM AND status ', JqlSlot.operator, 'status', '');
    expectWord('status != "In', JqlSlot.value, 'status', '"In');
    expectWord('status not in (', JqlSlot.value, 'status', '');
    expectWord('status in ("To Do", In', JqlSlot.value, 'status', 'In');
    expectWord('status in ("To Do") ', JqlSlot.keyword, '', '');
    expectWord('assignee = currentUser() ORDER ', JqlSlot.keyword, '', '');
    expectWord('x = 1 ORDER BY up', JqlSlot.field, '', 'up');
    expectWord('(status = Done OR labels', JqlSlot.field, '', 'labels');
    expectWord('labels is ', JqlSlot.value, 'labels', '');
  });
}
