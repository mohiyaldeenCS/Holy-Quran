import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/go_to_error.dart';
import 'package:holyquran/domain/models/go_to_target.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/domain/use_cases/parse_go_to.dart';
import 'package:holyquran/utils/result.dart';

// A synthetic edition: three surahs of 7, 20 and 5 ayat, with made-up
// divisions. None of its numbers are those of a real edition.

QuranAddress _at(int surah, int ayah) => QuranAddress('synthetic', surah, ayah);

final class _Structure implements QuranStructure {
  static const _ayahCounts = [7, 20, 5];

  final _map = EditionMap(
    edition: 'synthetic',
    starts: {
      Division.juz: [_at(1, 1), _at(2, 1)],
      Division.hizb: [_at(1, 1), _at(1, 5), _at(2, 1), _at(3, 1)],
      Division.rub: [
        for (final (surah, ayah) in [
          (1, 1), (1, 3), (1, 5), (2, 1), //
          (2, 6), (2, 11), (2, 16), (3, 1),
        ])
          _at(surah, ayah),
      ],
      Division.page: [_at(1, 1), _at(1, 6), _at(2, 4), _at(2, 15), _at(3, 2)],
    },
    sajdas: const {},
  );

  @override
  String get riwaya => 'synthetic';

  @override
  int get surahCount => _ayahCounts.length;

  @override
  int ayahCount(int surah) => _ayahCounts[surah - 1];

  @override
  int? nextSurah(int surah) => surah < surahCount ? surah + 1 : null;

  @override
  int count(Division division) => _map.count(division);

  @override
  QuranAddress firstAyah(Division division, int number) =>
      _map.startOf(division, number);

  @override
  int numberAt(Division division, QuranAddress address) =>
      _map.numberAt(division, address);
}

/// The zero of each digit system the input accepts.
const _digitSystems = {
  'Western': 0x0030,
  'Arabic-Indic': 0x0660,
  'extended Arabic-Indic': 0x06F0,
};

/// [western] with its ASCII digits written from [zero].
String _digits(String western, int zero) => String.fromCharCodes(
  western.codeUnits.map(
    (unit) => unit >= 0x30 && unit <= 0x39 ? unit - 0x30 + zero : unit,
  ),
);

Object? _value(Result<GoToTarget> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => error,
};

void main() {
  final structure = _Structure();

  group('readNumber', () {
    for (final MapEntry(key: system, value: zero) in _digitSystems.entries) {
      test('reads $system digits', () {
        expect(readNumber(_digits('0', zero)), 0);
        expect(readNumber(_digits('42', zero)), 42);
        expect(readNumber(_digits('007', zero)), 7);
        expect(readNumber(_digits('123456789', zero)), 123456789);
      });
    }

    test('reads digits of the three systems mixed', () {
      expect(
        readNumber('1${_digits('2', 0x0660)}${_digits('3', 0x06F0)}'),
        123,
      );
    });

    test('refuses anything but a run of at most nine digits', () {
      for (final text in [
        '',
        ' ',
        ' 1',
        '1 ',
        '1234567890',
        '-1',
        '+1',
        '1.5',
        '1,5',
        'a',
        '1a',
        '\u0661\u066B\u0662', // Arabic decimal separator
        '\u0966', // Devanagari zero
        '\uFF11', // full-width one
      ]) {
        expect(readNumber(text), isNull, reason: text);
      }
    });
  });

  group('isDigitRun', () {
    test('holds for digits of the three systems, however many', () {
      expect(isDigitRun('1234567890123'), isTrue);
      expect(isDigitRun(_digits('99', 0x0660)), isTrue);
      expect(isDigitRun(_digits('99', 0x06F0)), isTrue);
    });

    test('fails for an empty text or one with anything else', () {
      for (final text in ['', '1 2', '1:2', 'x', '\u0966']) {
        expect(isDigitRun(text), isFalse, reason: text);
      }
    });
  });

  group('parseGoTo', () {
    for (final MapEntry(key: system, value: zero) in _digitSystems.entries) {
      String d(String western) => _digits(western, zero);

      test('reads every target in $system digits', () {
        final cases = <(GoToKind, String, String), GoToTarget>{
          (GoToKind.surah, d('2'), ''): GoToSurah(_at(2, 1)),
          (GoToKind.surah, d('03'), ''): GoToSurah(_at(3, 1)),
          (GoToKind.surah, d('2'), d('20')): GoToAyah(_at(2, 20)),
          (GoToKind.surah, d('1'), d('1')): GoToAyah(_at(1, 1)),
          (GoToKind.page, d('3'), ''): GoToDivision(
            Division.page,
            3,
            _at(2, 4),
          ),
          (GoToKind.juz, d('2'), ''): GoToDivision(Division.juz, 2, _at(2, 1)),
          (GoToKind.hizb, d('2'), ''): GoToDivision(
            Division.hizb,
            2,
            _at(1, 5),
          ),
          (GoToKind.rub, d('8'), ''): GoToDivision(Division.rub, 8, _at(3, 1)),
        };
        for (final MapEntry(key: (kind, number, ayah), value: target)
            in cases.entries) {
          expect(
            _value(parseGoTo(structure, kind, number, ayah: ayah)),
            target,
            reason: '$kind $number $ayah',
          );
        }
      });

      test('names the reason for every refusal in $system digits', () {
        final cases = <(GoToKind, String, String), GoToError>{
          (GoToKind.surah, d('2'), d('21')): const NoSuchAyah(
            surah: 2,
            ayah: 21,
            ayahCount: 20,
          ),
          (GoToKind.surah, d('3'), d('300')): const NoSuchAyah(
            surah: 3,
            ayah: 300,
            ayahCount: 5,
          ),
          (GoToKind.surah, d('1'), d('0')): const NoSuchAyah(
            surah: 1,
            ayah: 0,
            ayahCount: 7,
          ),
          (GoToKind.surah, d('4'), ''): const NoSuchSurah(
            surah: 4,
            surahCount: 3,
          ),
          (GoToKind.surah, d('0'), d('1')): const NoSuchSurah(
            surah: 0,
            surahCount: 3,
          ),
          (GoToKind.page, d('6'), ''): const DivisionOutOfRange(
            division: Division.page,
            number: 6,
            count: 5,
          ),
          (GoToKind.page, d('0'), ''): const DivisionOutOfRange(
            division: Division.page,
            number: 0,
            count: 5,
          ),
          (GoToKind.juz, d('3'), ''): const DivisionOutOfRange(
            division: Division.juz,
            number: 3,
            count: 2,
          ),
          (GoToKind.hizb, d('5'), ''): const DivisionOutOfRange(
            division: Division.hizb,
            number: 5,
            count: 4,
          ),
          (GoToKind.rub, d('9'), ''): const DivisionOutOfRange(
            division: Division.rub,
            number: 9,
            count: 8,
          ),
        };
        for (final MapEntry(key: (kind, number, ayah), value: error)
            in cases.entries) {
          expect(
            _value(parseGoTo(structure, kind, number, ayah: ayah)),
            error,
            reason: '$kind $number $ayah',
          );
        }
      });
    }

    test('ignores spaces around the numbers', () {
      expect(
        _value(parseGoTo(structure, GoToKind.surah, ' 2 ', ayah: '  5\t')),
        GoToAyah(_at(2, 5)),
      );
      expect(
        _value(parseGoTo(structure, GoToKind.surah, '2', ayah: '   ')),
        GoToSurah(_at(2, 1)),
      );
    });

    test('throws when an ayah is given for a division', () {
      for (final kind in GoToKind.values.where((k) => k != GoToKind.surah)) {
        expect(
          () => parseGoTo(structure, kind, '1', ayah: '1'),
          throwsArgumentError,
          reason: '$kind',
        );
      }
    });

    test('refuses input that is not a number as unreadable', () {
      for (final (kind, number, ayah) in [
        (GoToKind.surah, '', ''),
        (GoToKind.surah, 'two', ''),
        (GoToKind.surah, '2', 'five'),
        (GoToKind.surah, '2:5', ''),
        (GoToKind.surah, '1 2', ''),
        (GoToKind.surah, '1234567890', ''),
        (GoToKind.surah, '2', '1234567890'),
        (GoToKind.page, '-1', ''),
        (GoToKind.page, '1.5', ''),
        (GoToKind.juz, '', ''),
      ]) {
        expect(
          _value(parseGoTo(structure, kind, number, ayah: ayah)),
          const UnreadableGoTo(),
          reason: '$kind "$number" "$ayah"',
        );
      }
    });
  });

  group('goToSurah and goToDivision', () {
    test('check numbers against the edition', () {
      expect(_value(goToSurah(structure, 3)), GoToSurah(_at(3, 1)));
      expect(_value(goToSurah(structure, 3, ayah: 5)), GoToAyah(_at(3, 5)));
      expect(
        _value(goToSurah(structure, 3, ayah: 6)),
        const NoSuchAyah(surah: 3, ayah: 6, ayahCount: 5),
      );
      expect(
        _value(goToSurah(structure, -1)),
        const NoSuchSurah(surah: -1, surahCount: 3),
      );
      expect(
        _value(goToDivision(structure, Division.page, 5)),
        GoToDivision(Division.page, 5, _at(3, 2)),
      );
      expect(
        _value(goToDivision(structure, Division.juz, -1)),
        const DivisionOutOfRange(division: Division.juz, number: -1, count: 2),
      );
    });
  });
}
