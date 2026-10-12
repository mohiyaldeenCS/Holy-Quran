import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_position.dart';

void main() {
  QuranPosition position({int page = 4}) => QuranPosition(
    address: QuranAddress('hafs', 2, 5),
    surah: 2,
    juz: 1,
    hizb: 2,
    rub: 3,
    page: page,
  );

  test('positions with the same fields are equal', () {
    expect(position(), position());
    expect(position().hashCode, position().hashCode);
    expect(position(), isNot(position(page: 5)));
  });

  test('names every number', () {
    expect(
      '${position()}',
      'QuranPosition(hafs:2:5: surah 2, juz 1, hizb 2, rub 3, page 4)',
    );
  });
}
