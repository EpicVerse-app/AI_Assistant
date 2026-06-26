import 'package:flutter_test/flutter_test.dart';

import 'package:ai_assistant/utils/date_time_utils.dart';

void main() {
  test('parseApi treats naive ISO strings as UTC', () {
    final naive = DateTimeUtils.parseApi('2026-06-23T05:17:04.061788');
    final explicit = DateTime.parse('2026-06-23T05:17:04.061788Z').toLocal();
    expect(naive, explicit);
  });

  test('parseApi uses epoch milliseconds when provided', () {
    final utc = DateTime.utc(2026, 6, 23, 5, 17, 4);
    final fromEpoch = DateTimeUtils.parseApi(null, epochMs: utc.millisecondsSinceEpoch);
    final fromIso = DateTime.parse('2026-06-23T05:17:04Z').toLocal();
    expect(fromEpoch, fromIso);
  });
}
