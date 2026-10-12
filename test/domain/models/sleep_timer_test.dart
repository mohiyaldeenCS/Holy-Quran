import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/sleep_timer.dart';

void main() {
  test('minutes run from 5 to 120', () {
    expect(SleepAfter(5).duration, const Duration(minutes: 5));
    expect(SleepAfter(120).duration, const Duration(hours: 2));
    expect(() => SleepAfter(4), throwsRangeError);
    expect(() => SleepAfter(121), throwsRangeError);
  });

  test('equal minutes make equal timers', () {
    expect(SleepAfter(30), SleepAfter(30));
    expect(SleepAfter(30), isNot(SleepAfter(31)));
  });
}
