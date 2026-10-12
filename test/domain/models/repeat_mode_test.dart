import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/repeat_mode.dart';

void main() {
  test('counts run from 1 to 99, or without end', () {
    expect(RepeatMode(RepeatUnit.ayah, 1).count, 1);
    expect(RepeatMode(RepeatUnit.ayah, 99).isUnlimited, isFalse);
    expect(const RepeatMode.unlimited(RepeatUnit.page).isUnlimited, isTrue);
    expect(() => RepeatMode(RepeatUnit.ayah, 0), throwsRangeError);
    expect(() => RepeatMode(RepeatUnit.ayah, 100), throwsRangeError);
  });

  test('once hears everything one time', () {
    expect(RepeatMode.once.count, 1);
    expect(RepeatMode.once, RepeatMode(RepeatUnit.range, 1));
  });
}
