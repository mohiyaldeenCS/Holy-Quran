import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/go_to_error.dart';

/// [value] as a value not known at compile time, so that an object built
/// from it is not the canonical const one and equality is not identity.
int _new(int value) => value;

void main() {
  test('errors are exceptions, equal by value', () {
    final equal = <(GoToError, GoToError)>[
      (
        const NoSuchAyah(surah: 2, ayah: 300, ayahCount: 20),
        NoSuchAyah(surah: _new(2), ayah: 300, ayahCount: 20),
      ),
      (
        const NoSuchSurah(surah: 9, surahCount: 3),
        NoSuchSurah(surah: _new(9), surahCount: 3),
      ),
      (
        const DivisionOutOfRange(division: Division.page, number: 6, count: 5),
        DivisionOutOfRange(division: Division.page, number: _new(6), count: 5),
      ),
      // A second instance, so that equality is not identity.
      // ignore: prefer_const_constructors
      (const UnreadableGoTo(), UnreadableGoTo()),
    ];
    for (final (a, b) in equal) {
      expect(a, isA<Exception>());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    }
  });

  test('errors with other data differ', () {
    final different = <GoToError>[
      const NoSuchAyah(surah: 2, ayah: 300, ayahCount: 20),
      const NoSuchAyah(surah: 3, ayah: 300, ayahCount: 20),
      const NoSuchAyah(surah: 2, ayah: 301, ayahCount: 20),
      const NoSuchAyah(surah: 2, ayah: 300, ayahCount: 21),
      const NoSuchSurah(surah: 9, surahCount: 3),
      const NoSuchSurah(surah: 8, surahCount: 3),
      const NoSuchSurah(surah: 9, surahCount: 4),
      const DivisionOutOfRange(division: Division.page, number: 6, count: 5),
      const DivisionOutOfRange(division: Division.juz, number: 6, count: 5),
      const DivisionOutOfRange(division: Division.page, number: 7, count: 5),
      const DivisionOutOfRange(division: Division.page, number: 6, count: 4),
      const UnreadableGoTo(),
    ];
    for (final (i, a) in different.indexed) {
      for (final (j, b) in different.indexed) {
        if (i != j) expect(a, isNot(b), reason: '$a and $b');
      }
    }
  });

  test('an error names its data', () {
    expect(
      const NoSuchAyah(surah: 2, ayah: 300, ayahCount: 20).toString(),
      'NoSuchAyah(2:300 of 20)',
    );
    expect(
      const NoSuchSurah(surah: 9, surahCount: 3).toString(),
      'NoSuchSurah(9 of 3)',
    );
    expect(
      const DivisionOutOfRange(
        division: Division.hizb,
        number: 6,
        count: 5,
      ).toString(),
      'DivisionOutOfRange(hizb 6 of 5)',
    );
    expect(const UnreadableGoTo().toString(), 'UnreadableGoTo()');
  });
}
