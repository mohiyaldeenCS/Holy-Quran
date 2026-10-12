import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/go_to_target.dart';
import 'package:holyquran/domain/models/quran_address.dart';

QuranAddress _at(int surah, int ayah) => QuranAddress('synthetic', surah, ayah);

void main() {
  test('each target starts at its first ayah', () {
    expect(GoToSurah(_at(2, 1)).start, _at(2, 1));
    expect(GoToSurah(_at(2, 1)).surah, 2);
    expect(GoToAyah(_at(2, 9)).start, _at(2, 9));
    expect(GoToDivision(Division.page, 4, _at(3, 2)).start, _at(3, 2));
  });

  test('targets are equal by value', () {
    final equal = <(GoToTarget, GoToTarget)>[
      (GoToSurah(_at(2, 1)), GoToSurah(_at(2, 1))),
      (GoToAyah(_at(2, 9)), GoToAyah(_at(2, 9))),
      (
        GoToDivision(Division.juz, 2, _at(2, 1)),
        GoToDivision(Division.juz, 2, _at(2, 1)),
      ),
    ];
    for (final (a, b) in equal) {
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    }
    final different = <GoToTarget>[
      GoToSurah(_at(2, 1)),
      GoToSurah(_at(3, 1)),
      GoToAyah(_at(2, 1)),
      GoToDivision(Division.juz, 2, _at(2, 1)),
      GoToDivision(Division.hizb, 2, _at(2, 1)),
      GoToDivision(Division.juz, 3, _at(2, 1)),
      GoToDivision(Division.juz, 2, _at(2, 2)),
    ];
    for (final (i, a) in different.indexed) {
      for (final (j, b) in different.indexed) {
        if (i != j) expect(a, isNot(b), reason: '$a and $b');
      }
    }
  });

  test('every kind but surah goes to its division', () {
    expect(
      {for (final kind in GoToKind.values) kind: kind.division},
      {
        GoToKind.surah: null,
        GoToKind.page: Division.page,
        GoToKind.juz: Division.juz,
        GoToKind.hizb: Division.hizb,
        GoToKind.rub: Division.rub,
      },
    );
  });

  test('a surah starts at its first ayah and an ayah is no word', () {
    expect(() => GoToSurah(_at(2, 2)), throwsArgumentError);
    expect(
      () => GoToSurah(QuranAddress('synthetic', 2, 1, 1)),
      throwsArgumentError,
    );
    expect(
      () => GoToAyah(QuranAddress('synthetic', 2, 3, 1)),
      throwsArgumentError,
    );
  });

  test('a target says where it leads', () {
    expect(GoToSurah(_at(2, 1)).toString(), 'GoToSurah(2)');
    expect(GoToAyah(_at(2, 9)).toString(), 'GoToAyah(synthetic:2:9)');
    expect(
      GoToDivision(Division.rub, 4, _at(3, 2)).toString(),
      'GoToDivision(rub 4, synthetic:3:2)',
    );
  });
}
